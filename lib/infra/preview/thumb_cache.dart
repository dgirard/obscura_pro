import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/database.dart';

/// Decoded thumbnails kept on the Mac, indexed in the database.
///
/// Nothing here ever touches the card. The card is read, never written: it must
/// come out of the reader exactly as the camera wrote it, so every derived byte
/// of this app — cache files, database, WAL — lives under application-support
/// (R5, CARTE-2).
class ThumbCache {
  ThumbCache({
    required this.directory,
    required ThumbCacheDao dao,
    this.budgetBytes = defaultBudgetBytes,
  }) : _dao = dao;

  /// Ceiling on the cache directory.
  ///
  /// A full 512 GB card of Q3 frames yields on the order of 20 000 photographs;
  /// at ~40 KB per cached grid thumbnail that is under a gigabyte, so this holds
  /// several cards' worth without the user ever meeting the eviction path.
  static const int defaultBudgetBytes = 1024 * 1024 * 1024;

  final Directory directory;
  final ThumbCacheDao _dao;
  final int budgetBytes;

  /// Resolves the cache under application-support and creates it.
  static Future<ThumbCache> open(
    ThumbCacheDao dao, {
    int budgetBytes = defaultBudgetBytes,
  }) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'thumbnails'));
    await directory.create(recursive: true);
    return ThumbCache(directory: directory, dao: dao, budgetBytes: budgetBytes);
  }

  /// Sharded two levels deep on the stable key's leading hex digits.
  ///
  /// A card can hold tens of thousands of photographs and a single directory
  /// with that many entries is slow to enumerate on any filesystem; 256 shards
  /// keeps each one small without making the tree hard to inspect by hand.
  File fileFor(String stableKey, ThumbVariant variant) => File(
        p.join(directory.path, stableKey.substring(0, 2), '$stableKey-${variant.name}.jpg'),
      );

  /// The cached bytes, or null on a miss.
  ///
  /// A row whose file has gone — a user emptying the folder, a failed write —
  /// counts as a miss and the stale row is dropped, because an index entry that
  /// promises a file that is not there would keep returning null forever.
  Future<CachedThumbnail?> read(String stableKey, ThumbVariant variant) async {
    final row = await _dao.entryFor(stableKey, variant);
    if (row == null) return null;

    final file = File(row.cachePath);
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on FileSystemException {
      await _dao.removeEntry(row.id);
      return null;
    }

    return CachedThumbnail(
      bytes: bytes,
      width: row.pixelWidth,
      height: row.pixelHeight,
      averageColor: row.averageColor,
    );
  }

  /// Writes the file first, then the index row.
  ///
  /// That order is deliberate and it is the reverse of what feels natural: a row
  /// without a file is a permanent miss, while a file without a row is a few
  /// kilobytes that eviction will never reclaim. Only one of those two failures
  /// breaks the cache, so the file goes down first.
  ///
  /// The file itself lands through a temporary name and a rename, so a crash
  /// mid-write cannot leave a half-JPEG that the next session reads as valid.
  Future<void> store(
    String stableKey,
    ThumbVariant variant, {
    required Uint8List jpeg,
    int? width,
    int? height,
    int? averageColor,
  }) async {
    final file = fileFor(stableKey, variant);
    await file.parent.create(recursive: true);

    final temp = File('${file.path}.part');
    await temp.writeAsBytes(jpeg, flush: true);
    await temp.rename(file.path);

    await _dao.upsertEntry(
      ThumbCacheEntriesCompanion.insert(
        cleStable: stableKey,
        variant: variant,
        cachePath: file.path,
        byteSize: jpeg.length,
        pixelWidth: Value(width),
        pixelHeight: Value(height),
        averageColor: Value(averageColor),
      ),
    );
  }

  /// Placeholder colours for every photograph the cache knows, keyed by stable
  /// key.
  ///
  /// One query paints every pending cell in the grid, which is the whole reason
  /// the colour lives on the row rather than in the file.
  Future<Map<String, int>> placeholderColors() async {
    final entries = await _dao.entriesByAge();
    return {
      for (final entry in entries)
        if (entry.averageColor != null) entry.cleStable: entry.averageColor!,
    };
  }

  /// Deletes oldest-first until the cache fits [budgetBytes]. Returns the number
  /// of entries removed.
  ///
  /// Oldest-first is insertion order, not least-recently-used: tracking real
  /// access order would mean a database write on every cache *hit*, which is the
  /// one path in this pipeline that has to stay free. Re-decoding a thumbnail
  /// that was evicted early costs a few milliseconds, so the trade is cheap.
  Future<int> evictToBudget() async {
    var total = await _dao.totalBytes();
    if (total <= budgetBytes) return 0;

    var removed = 0;
    for (final entry in await _dao.entriesByAge()) {
      if (total <= budgetBytes) break;
      await _delete(entry);
      total -= entry.byteSize;
      removed++;
    }
    return removed;
  }

  /// Forgets everything derived from one photograph, on disk and in the index.
  Future<void> forget(String stableKey) async {
    for (final entry in await _dao.entriesFor(stableKey)) {
      await _delete(entry);
    }
  }

  Future<void> _delete(ThumbCacheEntry entry) async {
    try {
      await File(entry.cachePath).delete();
    } on FileSystemException {
      // The file was already gone. Dropping the row is still the right move —
      // it is what makes the entry stop counting against the budget.
    }
    await _dao.removeEntry(entry.id);
  }
}

/// A cache hit.
class CachedThumbnail {
  const CachedThumbnail({
    required this.bytes,
    this.width,
    this.height,
    this.averageColor,
  });

  final Uint8List bytes;

  /// Null for rows written before the index carried pixel sizes.
  final int? width;
  final int? height;
  final int? averageColor;
}
