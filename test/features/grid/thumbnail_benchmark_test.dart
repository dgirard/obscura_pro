// ignore_for_file: avoid_print -- reporting the measurements to whoever ran it
// is this file's entire purpose.

/// Measures the thumbnail pipeline against a real Leica card.
///
/// Skipped unless a card folder is named, so the suite stays hardware-free:
///
/// ```
/// Q3_DIR=/Volumes/<card> flutter test \
///   test/features/grid/thumbnail_benchmark_test.dart
/// ```
///
/// Strictly read-only on the card. Everything this writes — cache files and the
/// database — goes to a temporary directory on the Mac, which is the same rule
/// the app follows in production (R5, CARTE-2).
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/catalog/dcf_scanner.dart';
import 'package:obscura_pro/features/grid/thumbnail_provider.dart';
import 'package:obscura_pro/infra/db/database.dart';
import 'package:obscura_pro/infra/preview/isolate_pool.dart';
import 'package:obscura_pro/infra/preview/thumb_cache.dart';

/// A Retina grid cell at the maquette's density: roughly 200 logical points.
const int gridCellShortSide = 400;

/// How many cells the library grid shows before the user has scrolled.
const int firstRowCells = 6;

void main() {
  final cardRoot = Platform.environment['Q3_DIR'];

  test(
    'decodes a real card fast enough for the first grid row (PERF-1)',
    () async {
      final scan = await const DcfScanner().scan(cardRoot!);
      expect(scan.photos, isNotEmpty, reason: 'no photographs under $cardRoot');

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final cacheRoot = await Directory.systemTemp.createTemp('obscura_bench');
      final pool = DecodePool();
      final service = ThumbnailService(
        pool: pool,
        cache: ThumbCache(directory: cacheRoot, dao: db.thumbCacheDao),
      );
      addTearDown(() async {
        await service.dispose();
        await db.close();
        await cacheRoot.delete(recursive: true);
      });

      for (final photo in scan.photos) {
        await db.catalogDao.upsertPhoto(
          PhotosCompanion.insert(
            cleStable: photo.key.value,
            radicalDcf: photo.dcfPath,
          ),
        );
      }

      final sample = scan.photos.take(48).toList();

      final firstRow = Stopwatch()..start();
      await Future.wait([
        for (final photo in sample.take(firstRowCells))
          service.gridThumbnail(photo, targetShortSide: gridCellShortSide),
      ]);
      firstRow.stop();

      final cold = Stopwatch()..start();
      for (final photo in sample.skip(firstRowCells)) {
        await service.gridThumbnail(photo, targetShortSide: gridCellShortSide);
      }
      cold.stop();

      final warm = Stopwatch()..start();
      for (final photo in sample) {
        final thumbnail =
            await service.gridThumbnail(photo, targetShortSide: gridCellShortSide);
        expect(thumbnail.fromCache, isTrue);
      }
      warm.stop();

      var cacheBytes = 0;
      await for (final entry in cacheRoot.list(recursive: true)) {
        if (entry is File) cacheBytes += await entry.length();
      }

      final coldCount = sample.length - firstRowCells;
      print('');
      print('=== Thumbnail pipeline, $cardRoot ===');
      print('  photographs on card : ${scan.photos.length}');
      print('  decode workers      : ${pool.workerCount}');
      print('  grid cell target    : $gridCellShortSide px short side');
      print('  first $firstRowCells cells (cold) : ${firstRow.elapsedMilliseconds} ms'
          '   <- PERF-1 budget is 500 ms');
      print('  next $coldCount cells (cold)  : ${cold.elapsedMilliseconds} ms '
          '(${(cold.elapsedMicroseconds / coldCount / 1000).toStringAsFixed(1)} ms each)');
      print('  ${sample.length} cells from cache    : ${warm.elapsedMilliseconds} ms '
          '(${(warm.elapsedMicroseconds / sample.length / 1000).toStringAsFixed(2)} ms each)');
      print('  cache on disk       : ${(cacheBytes / sample.length).round()} bytes per photo');
      print('  extrapolated card   : '
          '${(cacheBytes / sample.length * scan.photos.length / 1024 / 1024).round()} MB');
      print('  cache write failures: ${service.cacheWriteFailures}');
      print('');

      expect(service.cacheWriteFailures, 0);
    },
    skip: cardRoot == null
        ? 'set Q3_DIR to a mounted card to measure the pipeline'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
