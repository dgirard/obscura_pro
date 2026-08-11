/// A persistent pool of isolates that turn embedded JPEG previews into small,
/// cacheable JPEGs.
///
/// The pool exists because decoding is the one genuinely CPU-bound step in the
/// pipeline. Reading a card header is not — that was measured at ~2 ms per file,
/// almost all of it waiting on the reader, which is why the catalog scan (U5)
/// uses plain async concurrency and only this stage spends isolates.
///
/// What crosses the isolate boundary is encoded bytes, never bitmaps: a decoded
/// Q3 full-size preview is 9520x6336x4 bytes, and copying a quarter of a gigabyte
/// per thumbnail would cost more than the decode it was meant to move off the UI
/// thread. Workers therefore return JPEG bytes through [TransferableTypedData],
/// which hands over the buffer instead of copying it, and the main isolate keeps
/// sole ownership of every cache-file and database write.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// One decode, described by the byte range the catalog scan already recorded.
///
/// No IFD walking happens here: [offset] and [length] come from the `photo` row,
/// so a worker seeks straight to the preview.
final class ThumbnailRequest {
  const ThumbnailRequest({
    required this.filePath,
    required this.offset,
    required this.length,
    required this.targetShortSide,
    this.quality = 85,
  });

  final String filePath;
  final int offset;
  final int length;

  /// Desired short side in *device* pixels. The result is never upscaled past
  /// the source: asking for more pixels than the camera embedded would only
  /// grow the cache file without adding detail.
  final int targetShortSide;

  final int quality;

  @override
  String toString() =>
      'ThumbnailRequest(${filePath.split('/').last} @$offset+$length -> $targetShortSide)';
}

/// A decoded, downscaled, re-encoded thumbnail on its way back to the main
/// isolate.
final class ThumbnailBytes {
  const ThumbnailBytes({
    required this.jpeg,
    required this.width,
    required this.height,
    required this.averageColor,
  });

  /// The JPEG payload. Transferable buffers may be materialized exactly once —
  /// call [takeBytes] and hold onto the result.
  final TransferableTypedData jpeg;

  final int width;
  final int height;

  /// Mean colour of the thumbnail, ARGB. Painted while a cell waits for its
  /// image, and cheap to compute here since the pixels are already decoded.
  final int averageColor;

  Uint8List takeBytes() => jpeg.materialize().asUint8List();
}

/// The request was dropped before a worker picked it up.
///
/// Normal traffic in a scrolling grid, not a failure: the cell that asked for it
/// has left the viewport.
final class DecodeCancelled implements Exception {
  const DecodeCancelled(this.reason);

  final String reason;

  @override
  String toString() => 'DecodeCancelled: $reason';
}

/// The bytes could not be turned into an image.
///
/// The caller shows an error tile. The photograph stays selectable and
/// deletable — a frame the app cannot render is exactly one the user may want
/// gone (spec §9).
final class ThumbnailDecodeException implements Exception {
  const ThumbnailDecodeException(this.message);

  final String message;

  @override
  String toString() => 'ThumbnailDecodeException: $message';
}

/// Runs [ThumbnailRequest]s across a fixed set of worker isolates.
class DecodePool {
  DecodePool({int? workers, this.queueLimit = 256})
      : workerCount = workers ?? defaultWorkerCount();

  /// How many isolates decode at once.
  ///
  /// Leaves a core for the UI thread and caps the total, because past a handful
  /// of workers the extra parallelism buys little while every additional worker
  /// holds another decoded frame in memory at peak.
  static int defaultWorkerCount() {
    final cores = Platform.numberOfProcessors;
    if (cores <= 2) return 1;
    return (cores - 1).clamp(1, 6);
  }

  final int workerCount;

  /// How many requests may wait for a worker.
  ///
  /// A fast scroll can queue a request per cell it flies past. When the queue is
  /// full the *oldest* waiting request is dropped rather than the newest,
  /// because in a grid the oldest is the one furthest behind the viewport — the
  /// cell the user has already scrolled away from.
  final int queueLimit;

  final _queue = Queue<_PendingJob>();
  final _workers = <_Worker>[];

  var _nextJobId = 0;
  Future<void>? _starting;
  var _disposed = false;

  /// Requests waiting for a worker. Exposed for tests and diagnostics.
  int get queueDepth => _queue.length;

  int get liveWorkers => _workers.where((w) => w.alive).length;

  Future<void> start() {
    if (_disposed) throw StateError('DecodePool was disposed');
    return _starting ??= _spawnAll();
  }

  Future<void> _spawnAll() async {
    for (var i = 0; i < workerCount; i++) {
      _workers.add(await _spawnWorker(i));
    }
  }

  Future<_Worker> _spawnWorker(int index) async {
    final events = ReceivePort();
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(
      _workerMain,
      ready.sendPort,
      debugName: 'obscura-decode-$index',
      onError: events.sendPort,
      onExit: events.sendPort,
      errorsAreFatal: true,
    );
    final inbox = await ready.first as SendPort;
    ready.close();

    final worker = _Worker(index: index, isolate: isolate, inbox: inbox, events: events);
    events.listen((message) => _onWorkerEvent(worker, message));
    return worker;
  }

  /// Decodes [request], queueing when every worker is busy.
  ///
  /// [tag] groups requests so [cancel] can drop them together; the grid passes
  /// the photograph's stable key.
  Future<ThumbnailBytes> decode(ThumbnailRequest request, {Object? tag}) {
    if (_disposed) {
      return Future.error(const DecodeCancelled('the pool was disposed'));
    }

    final job = _PendingJob(id: _nextJobId++, request: request, tag: tag);

    if (_queue.length >= queueLimit) {
      final evicted = _queue.removeFirst();
      evicted.completer.completeError(
        const DecodeCancelled('the decode queue was full and this was the oldest request'),
      );
    }
    _queue.add(job);

    // Starting is idempotent, so a caller may decode without awaiting start().
    unawaited(start().then((_) => _pump()).catchError((Object e, StackTrace s) {
      _failEverything(e, s);
    }));

    return job.completer.future;
  }

  /// Drops every *queued* request carrying [tag].
  ///
  /// A request already running is left to finish. Interrupting it would mean
  /// killing the worker isolate mid-decode, which throws away the pool the
  /// whole design exists to keep warm; the result is simply discarded by the
  /// caller instead.
  void cancel(Object tag) {
    if (_queue.isEmpty) return;
    final dropped = _queue.where((job) => job.tag == tag).toList(growable: false);
    if (dropped.isEmpty) return;
    _queue.removeWhere((job) => job.tag == tag);
    for (final job in dropped) {
      job.completer.completeError(const DecodeCancelled('the request was invalidated'));
    }
  }

  /// Drops every queued request, whatever its tag.
  void cancelAll() {
    final dropped = _queue.toList(growable: false);
    _queue.clear();
    for (final job in dropped) {
      job.completer.completeError(const DecodeCancelled('the queue was cleared'));
    }
  }

  void _pump() {
    if (_disposed) return;
    for (final worker in _workers) {
      if (_queue.isEmpty) return;
      if (!worker.alive || worker.current != null) continue;
      final job = _queue.removeFirst();
      worker.current = job;
      worker.inbox.send(_WorkerJob(job.id, job.request, worker.events.sendPort));
    }
  }

  void _onWorkerEvent(_Worker worker, Object? message) {
    switch (message) {
      case _WorkerDone(:final id, :final bytes):
        _finish(worker, id, (job) => job.completer.complete(bytes));
      case _WorkerFailed(:final id, :final message):
        _finish(
          worker,
          id,
          (job) => job.completer.completeError(ThumbnailDecodeException(message)),
        );
      default:
        // Anything else on this port is the isolate itself dying: a two-element
        // list from `onError`, or null from `onExit`. Either way the worker is
        // gone and whatever it was holding will never come back.
        _retire(worker, message);
    }
  }

  void _finish(_Worker worker, int id, void Function(_PendingJob) settle) {
    final job = worker.current;
    worker.current = null;
    // A stale id can only arrive from a worker that was already retired; its
    // job has been failed and must not be settled twice.
    if (job != null && job.id == id) settle(job);
    _pump();
  }

  /// Fails the dead worker's in-flight job and replaces it.
  ///
  /// Without this a worker killed by the operating system — an out-of-memory
  /// kill on a large frame is the realistic case — would leave its caller
  /// waiting on a future that can never complete, and shrink the pool by one
  /// every time it happened.
  void _retire(_Worker worker, Object? cause) {
    if (!worker.alive) return;
    worker.alive = false;
    worker.events.close();

    final job = worker.current;
    worker.current = null;
    job?.completer.completeError(
      ThumbnailDecodeException('decode worker ${worker.index} died: ${_describe(cause)}'),
    );

    if (_disposed) return;
    unawaited(_spawnWorker(worker.index).then((replacement) {
      if (_disposed) {
        replacement.shutdown();
        return;
      }
      final slot = _workers.indexOf(worker);
      if (slot >= 0) {
        _workers[slot] = replacement;
      } else {
        _workers.add(replacement);
      }
      _pump();
    }).catchError((Object _) {
      // Respawning failed too. The pool keeps serving with the workers it has;
      // if none are left, queued jobs fail rather than hang.
      if (liveWorkers == 0) {
        _failEverything(
          const ThumbnailDecodeException('every decode worker died'),
          StackTrace.current,
        );
      }
    }));
  }

  static String _describe(Object? cause) {
    if (cause == null) return 'exited';
    if (cause is List && cause.isNotEmpty) return '${cause.first}';
    return '$cause';
  }

  void _failEverything(Object error, StackTrace stack) {
    final dropped = _queue.toList(growable: false);
    _queue.clear();
    for (final job in dropped) {
      job.completer.completeError(error, stack);
    }
    for (final worker in _workers) {
      final job = worker.current;
      worker.current = null;
      job?.completer.completeError(error, stack);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _failEverything(const DecodeCancelled('the pool was disposed'), StackTrace.current);
    for (final worker in _workers) {
      worker.shutdown();
    }
    _workers.clear();
  }
}

class _PendingJob {
  _PendingJob({required this.id, required this.request, required this.tag});

  final int id;
  final ThumbnailRequest request;
  final Object? tag;
  final completer = Completer<ThumbnailBytes>();
}

class _Worker {
  _Worker({
    required this.index,
    required this.isolate,
    required this.inbox,
    required this.events,
  });

  final int index;
  final Isolate isolate;

  /// The worker's own receive port, seen from here.
  final SendPort inbox;

  /// Responses, uncaught errors and the exit signal all arrive here, which is
  /// what makes it unambiguous *which* worker an event belongs to.
  final ReceivePort events;

  _PendingJob? current;
  bool alive = true;

  void shutdown() {
    if (!alive) return;
    alive = false;
    inbox.send(const _Shutdown());
    events.close();
  }
}

// --- Isolate protocol -------------------------------------------------------

final class _WorkerJob {
  const _WorkerJob(this.id, this.request, this.reply);

  final int id;
  final ThumbnailRequest request;
  final SendPort reply;
}

final class _Shutdown {
  const _Shutdown();
}

final class _WorkerDone {
  const _WorkerDone(this.id, this.bytes);

  final int id;
  final ThumbnailBytes bytes;
}

final class _WorkerFailed {
  const _WorkerFailed(this.id, this.message);

  final int id;
  final String message;
}

Future<void> _workerMain(SendPort registration) async {
  final inbox = ReceivePort();
  registration.send(inbox.sendPort);

  // `await for` runs one job at a time, which is the point: the pool decides how
  // much work is in flight, and a worker that took two jobs at once would double
  // its peak memory for no extra throughput.
  await for (final message in inbox) {
    if (message is _Shutdown) break;
    final job = message as _WorkerJob;
    try {
      job.reply.send(_WorkerDone(job.id, await renderThumbnail(job.request)));
    } on Object catch (error) {
      // Errors are reported as text rather than as the exception object: a
      // decode failure must not depend on an arbitrary type surviving the trip
      // between isolates.
      job.reply.send(_WorkerFailed(job.id, '$error'));
    }
  }
  inbox.close();
}

// --- The work itself --------------------------------------------------------

/// Reads a preview's byte range, downscales it and re-encodes it.
///
/// Top-level and side-effect-free so it can run in a worker; also called
/// directly by tests, which is how the decode is verified without a pool.
Future<ThumbnailBytes> renderThumbnail(ThumbnailRequest request) async {
  final source = await _readRange(request);

  // The decoder signals a malformed stream two different ways — a null result
  // and a thrown ImageException — and neither may reach a caller as anything
  // but this library's own failure: a forged or damaged file has to arrive at
  // the UI as an error tile, not as a foreign exception type.
  final img.Image decoded;
  try {
    final candidate = img.decodeJpg(source);
    if (candidate == null) {
      throw ThumbnailDecodeException('not a decodable JPEG: ${request.filePath}');
    }
    decoded = candidate;
  } on ThumbnailDecodeException {
    rethrow;
  } on Object catch (error) {
    throw ThumbnailDecodeException('${request.filePath} did not decode: $error');
  }

  final scaled = _downscale(decoded, request.targetShortSide);

  // When nothing was scaled, the source bytes are already the answer, and
  // re-encoding them would spend a JPEG generation to produce a slightly worse
  // copy of a file we are holding.
  final jpeg = identical(scaled, decoded)
      ? source
      : img.encodeJpg(scaled, quality: request.quality);

  return ThumbnailBytes(
    jpeg: TransferableTypedData.fromList([jpeg]),
    width: scaled.width,
    height: scaled.height,
    averageColor: averageColorOf(scaled),
  );
}

Future<Uint8List> _readRange(ThumbnailRequest request) async {
  final handle = await File(request.filePath).open();
  try {
    if (request.offset != 0) await handle.setPosition(request.offset);
    final bytes = await handle.read(request.length);
    if (bytes.length < request.length) {
      throw ThumbnailDecodeException(
        'preview range ${request.offset}+${request.length} runs past the end of '
        '${request.filePath}',
      );
    }
    return bytes;
  } finally {
    await handle.close();
  }
}

/// Returns [source] itself when it is already at or below [targetShortSide].
img.Image _downscale(img.Image source, int targetShortSide) {
  final shortSide = source.width < source.height ? source.width : source.height;
  if (targetShortSide <= 0 || shortSide <= targetShortSide) return source;

  final ratio = targetShortSide / shortSide;
  return img.copyResize(
    source,
    width: (source.width * ratio).round().clamp(1, source.width),
    height: (source.height * ratio).round().clamp(1, source.height),
    interpolation: img.Interpolation.average,
  );
}

/// Mean colour of [image], ARGB with full alpha.
int averageColorOf(img.Image image) {
  var red = 0;
  var green = 0;
  var blue = 0;
  var count = 0;
  for (final pixel in image) {
    red += pixel.r.toInt();
    green += pixel.g.toInt();
    blue += pixel.b.toInt();
    count++;
  }
  if (count == 0) return 0xFF000000;
  return 0xFF000000 |
      ((red ~/ count) & 0xFF) << 16 |
      ((green ~/ count) & 0xFF) << 8 |
      ((blue ~/ count) & 0xFF);
}
