import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infra/db/database.dart';
import '../../infra/db/database_provider.dart';
import '../../infra/preview/isolate_pool.dart';
import '../../infra/preview/preview_extractor.dart';
import '../../infra/preview/thumb_cache.dart';
import '../catalog/photo_entity.dart';

/// A grid thumbnail, ready to hand to `Image.memory`.
///
/// Encoded bytes rather than a `ui.Image`: the engine's own codec decodes them
/// off the Dart thread, so passing bytes keeps the last decode off the UI thread
/// too (KTD-13).
class GridThumbnail {
  const GridThumbnail({
    required this.jpeg,
    required this.width,
    required this.height,
    required this.averageColor,
    required this.fromCache,
  });

  final Uint8List jpeg;
  final int? width;
  final int? height;

  /// Placeholder colour, ARGB. Null only for a cache row written before the
  /// index carried one.
  final int? averageColor;

  /// Whether this came off disk rather than out of a fresh decode. Reported so
  /// the performance benchmark can tell a warm run from a cold one.
  final bool fromCache;
}

/// Serves thumbnails and full-size previews to the UI.
///
/// Owns the whole read path: disk cache first, decode pool on a miss, and a
/// memory budget over the decoded full-size previews the viewer holds.
class ThumbnailService {
  ThumbnailService({
    required DecodePool pool,
    required ThumbCache cache,
    FullPreviewCache? memory,
  })  : _pool = pool,
        _cache = cache,
        memory = memory ?? FullPreviewCache();

  final DecodePool _pool;
  final ThumbCache _cache;

  /// The MEM-1 budget. Exposed because the viewer drives its preload window
  /// through [FullPreviewCache.retain].
  final FullPreviewCache memory;

  final _inFlight = <String, Future<GridThumbnail>>{};

  /// Keys withdrawn since their request started. Cleared by whichever comes
  /// first: the request noticing, or a new request for the same photograph.
  final _withdrawn = <String>{};

  /// How many decodes were served but could not be written to the cache.
  ///
  /// Non-zero means the grid is re-decoding on every visit and something
  /// upstream is wrong; it is counted rather than thrown so that the user still
  /// sees their photographs.
  int cacheWriteFailures = 0;

  /// Largest source this will decode when escalating past the small preview.
  ///
  /// The pure-Dart JPEG decoder has no scaled-decode mode, so a source is
  /// decoded at full size before it is downscaled: a Q3 full-size preview is
  /// 9520x6336, which is 240 MB of pixels, and several workers doing that at
  /// once would exhaust memory to produce a 400-pixel tile.
  static const int maxEscalationPixels = 16 * 1000 * 1000;

  /// The grid thumbnail for [photo] at [targetShortSide] device pixels.
  ///
  /// Concurrent callers for the same photograph share one decode — a grid that
  /// scrolls back over a cell must not queue a second copy of work already in
  /// flight.
  Future<GridThumbnail> gridThumbnail(
    PhotoEntity photo, {
    required int targetShortSide,
  }) {
    final key = photo.key.value;
    final pending = _inFlight[key];
    if (pending != null) return pending;

    // A fresh request supersedes any withdrawal that came before it: the cell
    // has scrolled back into view.
    _withdrawn.remove(key);

    late final Future<GridThumbnail> work;
    work = _resolve(photo, targetShortSide).whenComplete(() {
      // Only clears its own entry. A withdrawal followed by a new request
      // leaves a newer future under this key, and it must survive.
      if (identical(_inFlight[key], work)) _inFlight.remove(key);
    });
    _inFlight[key] = work;
    return work;
  }

  Future<GridThumbnail> _resolve(PhotoEntity photo, int targetShortSide) async {
    final key = photo.key.value;

    final cached = await _cache.read(key, ThumbVariant.small);
    // Checked here as well as in the pool: a request withdrawn while it was
    // still looking up the cache had never reached a queue to be dropped from.
    if (_withdrawn.remove(key)) {
      throw const DecodeCancelled('the request was withdrawn');
    }
    if (cached != null) {
      return GridThumbnail(
        jpeg: cached.bytes,
        width: cached.width,
        height: cached.height,
        averageColor: cached.averageColor,
        fromCache: true,
      );
    }

    // Falling back to the second source is what the corrupt-preview case needs:
    // a DNG whose full-size preview is truncated often still carries an intact
    // thumbnail, and a soft tile beats an error tile.
    Object? lastError;
    for (final source in _sourcesFor(photo, targetShortSide)) {
      final file = _fileFor(photo, source);
      if (file == null) continue;
      try {
        final decoded = await _pool.decode(
          ThumbnailRequest(
            filePath: file.path,
            offset: source.offset,
            length: source.length,
            targetShortSide: targetShortSide,
            orientation: photo.orientation,
          ),
          tag: key,
        );
        final bytes = decoded.takeBytes();
        // The cache is an optimisation, not a correctness requirement, and it
        // has one foreseeable way to fail: the index row references `photo`, so
        // a photograph the catalog has not persisted yet cannot be cached. A
        // decoded thumbnail must not be thrown away over bookkeeping.
        try {
          await _cache.store(
            key,
            ThumbVariant.small,
            jpeg: bytes,
            width: decoded.width,
            height: decoded.height,
            averageColor: decoded.averageColor,
          );
        } on Object {
          cacheWriteFailures++;
        }
        return GridThumbnail(
          jpeg: bytes,
          width: decoded.width,
          height: decoded.height,
          averageColor: decoded.averageColor,
          fromCache: false,
        );
      } on DecodeCancelled {
        // Cancellation is the caller's own doing, not a bad source: stop rather
        // than working through the fallbacks it just asked us to abandon.
        rethrow;
      } on ThumbnailDecodeException catch (error) {
        lastError = error;
      }
    }

    throw lastError ??
        ThumbnailDecodeException('no readable preview in ${photo.dcfPath}');
  }

  /// Preview streams to try, best first.
  ///
  /// The small preview is the answer almost always: on a Q3 DNG it is 1620x1080,
  /// comfortably above any grid cell. Escalation exists for a JPG-only card,
  /// where the small preview is the 160x120 EXIF thumbnail — far too coarse to
  /// judge a frame by.
  ///
  /// Known limitation: a Q3 JPEG's only larger source is the 39 Mpx frame
  /// itself, which is over [maxEscalationPixels], so a JPG-only card gets soft
  /// tiles. Fixing it properly needs a scaled JPEG decode (the DCT 1/2, 1/4, 1/8
  /// modes the pure-Dart decoder does not expose), not a bigger budget.
  List<PreviewStream> _sourcesFor(PhotoEntity photo, int targetShortSide) {
    final small = photo.gridPreview;
    final large = photo.viewerPreview;
    if (small == null) return const [];
    if (large == null || identical(large, small)) return [small];

    final shortSide = _shortSideOf(small);
    final tooCoarse = shortSide != null && shortSide * 2 < targetShortSide;
    final affordable = (large.pixelCount ?? maxEscalationPixels + 1) <= maxEscalationPixels;

    return tooCoarse && affordable ? [large, small] : [small, large];
  }

  static int? _shortSideOf(PreviewStream stream) {
    final width = stream.width;
    final height = stream.height;
    if (width == null || height == null) return null;
    return width < height ? width : height;
  }

  /// Which file of the entity holds [source].
  ///
  /// A DNG's previews live in the DNG; a plain JPEG's live in the JPEG. Both
  /// files of a RAW+JPG pair carry a preview, and the offsets recorded by the
  /// scan are the RAW's, so the RAW is the file to open when there is one.
  PhotoFile? _fileFor(PhotoEntity photo, PreviewStream source) {
    final kind = source.kind == PreviewStreamKind.exifThumbnail ||
            source.kind == PreviewStreamKind.wholeFile
        ? PhotoFileKind.jpeg
        : PhotoFileKind.raw;
    for (final file in photo.files) {
      if (file.kind == kind) return file;
    }
    return photo.files.isEmpty ? null : photo.files.first;
  }

  /// Withdraws [photo]'s request. Called when a cell scrolls out of view.
  ///
  /// A decode already running in a worker is left to finish — see
  /// [DecodePool.cancel] — but its result is dropped and the in-flight entry
  /// released, so a cell that scrolls back into view starts a clean request
  /// rather than inheriting a cancellation it never asked for.
  void cancel(PhotoEntity photo) {
    final key = photo.key.value;
    _withdrawn.add(key);
    _inFlight.remove(key);
    _pool.cancel(key);
  }

  /// The full-size preview, decoded to at most [targetWidth] pixels wide.
  ///
  /// Never decoded at native resolution: a Q3 preview is 9520 pixels wide and
  /// 240 MB of RGBA, while no display shows more than a few thousand. The
  /// viewer asks for what it can show and asks again, larger, when the user
  /// zooms in.
  ///
  /// Unlike a grid thumbnail this comes back in the orientation the file stored
  /// it in. The engine codec applies no EXIF rotation, and turning a decoded
  /// full-size frame in memory would cost a second copy of it; the viewer turns
  /// it on the GPU instead, from [PhotoEntity.orientation].
  Future<ui.Image> fullPreview(
    PhotoEntity photo, {
    required int targetWidth,
  }) {
    final source = photo.viewerPreview;
    final file = source == null ? null : _fileFor(photo, source);
    if (source == null || file == null) {
      return Future.error(
        ThumbnailDecodeException('no full-size preview in ${photo.dcfPath}'),
      );
    }
    return memory.load(
      key: photo.key.value,
      targetWidth: targetWidth,
      readBytes: () => _readRange(file.path, source.offset, source.length),
    );
  }

  static Future<Uint8List> _readRange(String path, int offset, int length) async {
    final handle = await File(path).open();
    try {
      if (offset != 0) await handle.setPosition(offset);
      return await handle.read(length);
    } finally {
      await handle.close();
    }
  }

  Future<void> dispose() async {
    memory.clear();
    await _pool.dispose();
  }
}

/// MEM-1: a byte-budgeted, least-recently-used cache of decoded full-size
/// previews.
///
/// The requirement reads "a bounded number of full-size previews in RAM", and
/// counting them is the wrong bound: one Q3 preview at native resolution is
/// 240 MB, so five of them — an ordinary preload window — would be 1.2 GB. The
/// budget is therefore in bytes, and images are decoded to display size rather
/// than native size, which is what makes a window of five fit at all.
class FullPreviewCache {
  FullPreviewCache({this.budgetBytes = defaultBudgetBytes});

  /// Room for roughly fourteen previews at 3200 pixels wide.
  static const int defaultBudgetBytes = 384 * 1024 * 1024;

  final int budgetBytes;

  /// Insertion-ordered, and re-inserted on every hit, which is what makes the
  /// first entry the least recently used one.
  final LinkedHashMap<String, _MemoryEntry> _entries = LinkedHashMap();
  final _loading = <String, Future<ui.Image>>{};

  int _bytes = 0;

  int get byteSize => _bytes;
  int get length => _entries.length;

  /// A clone of the decoded image, decoding it first if need be.
  ///
  /// The returned image is a clone and the caller owns it: eviction disposes the
  /// cache's own handle, and a caller holding that same handle would find its
  /// image pulled out from under it mid-frame.
  Future<ui.Image> load({
    required String key,
    required int targetWidth,
    required Future<Uint8List> Function() readBytes,
  }) async {
    final id = '$key@$targetWidth';

    final hit = _entries.remove(id);
    if (hit != null) {
      _entries[id] = hit;
      return hit.image.clone();
    }

    final pending = _loading[id];
    if (pending != null) return (await pending).clone();

    final work = _decode(readBytes, targetWidth);
    _loading[id] = work;
    try {
      final image = await work;
      _insert(id, image);
      return image.clone();
    } finally {
      _loading.remove(id);
    }
  }

  static Future<ui.Image> _decode(
    Future<Uint8List> Function() readBytes,
    int targetWidth,
  ) async {
    final bytes = await readBytes();
    // The engine codec, not the pure-Dart decoder: it decodes on its own thread
    // and can scale while decoding, so the 240 MB intermediate never exists.
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  void _insert(String id, ui.Image image) {
    final cost = image.width * image.height * 4;
    _entries[id] = _MemoryEntry(image, cost);
    _bytes += cost;

    // Keeps the most recent entry even when it alone exceeds the budget: a
    // viewer that cannot hold the frame it is displaying is worse than one over
    // budget by a single image.
    while (_bytes > budgetBytes && _entries.length > 1) {
      _evict(_entries.keys.first);
    }
  }

  /// Keeps only the entries whose photo key is in [keys] — the viewer's preload
  /// window — and disposes the rest.
  void retain(Set<String> keys) {
    for (final id in _entries.keys.toList(growable: false)) {
      if (!keys.contains(id.substring(0, id.lastIndexOf('@')))) _evict(id);
    }
  }

  void _evict(String id) {
    final entry = _entries.remove(id);
    if (entry == null) return;
    _bytes -= entry.cost;
    entry.image.dispose();
  }

  void clear() {
    for (final id in _entries.keys.toList(growable: false)) {
      _evict(id);
    }
  }
}

class _MemoryEntry {
  _MemoryEntry(this.image, this.cost);

  final ui.Image image;
  final int cost;
}

// --- Providers --------------------------------------------------------------

final decodePoolProvider = Provider<DecodePool>((ref) {
  final pool = DecodePool();
  ref.onDispose(pool.dispose);
  return pool;
});

final thumbCacheProvider = FutureProvider<ThumbCache>(
  (ref) => ThumbCache.open(ref.watch(appDatabaseProvider).thumbCacheDao),
);

final thumbnailServiceProvider = FutureProvider<ThumbnailService>((ref) async {
  final service = ThumbnailService(
    pool: ref.watch(decodePoolProvider),
    cache: await ref.watch(thumbCacheProvider.future),
  );
  ref.onDispose(service.memory.clear);
  return service;
});
