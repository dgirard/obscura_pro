import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/catalog/dcf_scanner.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/grid/thumbnail_provider.dart';
import 'package:obscura_pro/infra/db/database.dart';
import 'package:obscura_pro/infra/preview/isolate_pool.dart';
import 'package:obscura_pro/infra/preview/thumb_cache.dart';

import '../../fixtures/fake_card.dart';
import '../../infra/preview/tiff_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('serving grid thumbnails', () {
    late FakeCard card;
    late AppDatabase db;
    late Directory cacheRoot;
    late DecodePool pool;
    late ThumbCache cache;
    late ThumbnailService service;

    setUp(() async {
      card = await FakeCard.create();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      cacheRoot = await Directory.systemTemp.createTemp('obscura_service');
      pool = DecodePool(workers: 2);
      cache = ThumbCache(directory: cacheRoot, dao: db.thumbCacheDao);
      service = ThumbnailService(pool: pool, cache: cache);
    });

    tearDown(() async {
      await service.dispose();
      await db.close();
      await card.dispose();
      if (await cacheRoot.exists()) await cacheRoot.delete(recursive: true);
    });

    /// Scans the fake card and registers its photographs, which is what a real
    /// session does before any cell asks for an image.
    Future<List<PhotoEntity>> catalogue() async {
      final photos = (await const DcfScanner().scan(card.path)).photos;
      for (final photo in photos) {
        await db.catalogDao.upsertPhoto(
          PhotosCompanion.insert(
            cleStable: photo.key.value,
            radicalDcf: photo.dcfPath,
          ),
        );
      }
      return photos;
    }

    test('decodes on a miss, then serves the identical bytes from cache',
        () async {
      await card.addPhoto('L1000863', decodable: true);
      final photo = (await catalogue()).single;

      final cold = await service.gridThumbnail(photo, targetShortSide: 64);
      final warm = await service.gridThumbnail(photo, targetShortSide: 64);

      expect(cold.fromCache, isFalse);
      expect(warm.fromCache, isTrue);
      expect(warm.jpeg, cold.jpeg);
      expect(warm.averageColor, cold.averageColor);
      expect(cold.height, 64);
      expect(service.cacheWriteFailures, 0);
    });

    test('survives a session: a second service reads the first one\'s cache',
        () async {
      await card.addPhoto('L1000863', decodable: true);
      final photo = (await catalogue()).single;
      final first = await service.gridThumbnail(photo, targetShortSide: 64);

      // Same cache directory and same database, new pool and new service —
      // which is what relaunching the app amounts to (R5).
      final second = ThumbnailService(pool: DecodePool(workers: 1), cache: cache);
      addTearDown(second.dispose);
      final reopened = await second.gridThumbnail(photo, targetShortSide: 64);

      expect(reopened.fromCache, isTrue);
      expect(reopened.jpeg, first.jpeg);
    });

    test('serves concurrent requests for one photograph from a single decode',
        () async {
      await card.addPhoto('L1000863', decodable: true);
      final photo = (await catalogue()).single;

      final results = await Future.wait([
        for (var i = 0; i < 6; i++)
          service.gridThumbnail(photo, targetShortSide: 64)
      ]);

      // A grid that scrolls back over a cell must not queue a second copy of
      // work already in flight: one decode, one result object, six callers.
      expect(results.every((r) => identical(r, results.first)), isTrue);
      expect(results.first.fromCache, isFalse);
    });

    test('falls back to the small preview when the larger one is damaged',
        () async {
      await card.addPhoto('L1000863',
          decodable: true, fullPreviewTruncated: true);
      final photo = (await catalogue()).single;

      // A 128-pixel source against a 400-pixel cell is coarse enough that the
      // service reaches for the full-size preview first — which here is the
      // damaged one.
      final thumbnail = await service.gridThumbnail(photo, targetShortSide: 400);

      expect(thumbnail.height, 85);
      expect(thumbnail.width, 128);
    });

    test('fails, leaving an error tile, when nothing in the file decodes',
        () async {
      await card.addCorruptPhoto('L1000999');
      final photo = (await catalogue()).single;

      // The photograph is still catalogued and still deletable; only its image
      // is missing (spec §9).
      expect(photo.isUnreadable, isTrue);
      await expectLater(
        service.gridThumbnail(photo, targetShortSide: 64),
        throwsA(isA<ThumbnailDecodeException>()),
      );
    });

    test('still returns the image when the cache cannot record it', () async {
      await card.addPhoto('L1000863', decodable: true);
      // Deliberately *not* catalogued: the index row references `photo`, so the
      // write fails. The user must still see their photograph.
      final photo = (await const DcfScanner().scan(card.path)).photos.single;

      final thumbnail = await service.gridThumbnail(photo, targetShortSide: 64);

      expect(thumbnail.jpeg, isNotEmpty);
      expect(service.cacheWriteFailures, 1);
    });

    test('decodes the full-size preview through the engine codec', () async {
      await card.addPhoto('L1000863',
          decodable: true, fullPreviewTruncated: false);
      final photo = (await catalogue()).single;

      final image = await service.fullPreview(photo, targetWidth: 320);
      addTearDown(image.dispose);

      // The source preview is 640 wide; the viewer asked for half of it and got
      // exactly that, never the full frame.
      expect(image.width, 320);
      expect(service.memory.byteSize, 320 * 213 * 4);
    });

    test('withdrawing a cell\'s request drops it', () async {
      await card.addPhoto('L1000863', decodable: true);
      final photo = (await catalogue()).single;

      final request = service.gridThumbnail(photo, targetShortSide: 64);
      service.cancel(photo);

      await expectLater(request, throwsA(isA<DecodeCancelled>()));
    });
  });

  group('the full-size preview budget (MEM-1)', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('obscura_mem');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    /// 200x200 decoded is 160 000 bytes, so a budget counted in those is easy
    /// to reason about.
    Future<Uint8List> Function() frame(int seed) {
      final bytes = realJpeg(width: 200, height: 200, redOffset: seed);
      return () async => bytes;
    }

    test('decodes to the requested width rather than the source size', () async {
      final cache = FullPreviewCache();
      addTearDown(cache.clear);

      final image = await cache.load(
        key: 'a',
        targetWidth: 50,
        readBytes: frame(0),
      );

      expect(image.width, 50);
      // A Q3 preview is 9520 pixels wide and 240 MB of pixels; decoding to what
      // the screen can show is what makes a preload window fit in memory at all.
      expect(cache.byteSize, 50 * 50 * 4);
      image.dispose();
    });

    test('serves a repeat request without decoding again', () async {
      final cache = FullPreviewCache();
      addTearDown(cache.clear);

      final first = await cache.load(key: 'a', targetWidth: 50, readBytes: frame(0));
      final second = await cache.load(key: 'a', targetWidth: 50, readBytes: frame(0));

      expect(cache.length, 1);
      expect(second.width, first.width);
      first.dispose();
      second.dispose();
    });

    test('holds the budget across a sweep of fifty photographs', () async {
      // Room for four frames of 200x200.
      final cache = FullPreviewCache(budgetBytes: 200 * 200 * 4 * 4);
      addTearDown(cache.clear);

      for (var i = 0; i < 50; i++) {
        (await cache.load(key: 'photo-$i', targetWidth: 200, readBytes: frame(i)))
            .dispose();
        expect(cache.byteSize, lessThanOrEqualTo(cache.budgetBytes));
      }

      expect(cache.length, 4);
    });

    test('evicts the least recently used, not the oldest', () async {
      final cache = FullPreviewCache(budgetBytes: 200 * 200 * 4 * 2);
      addTearDown(cache.clear);

      (await cache.load(key: 'a', targetWidth: 200, readBytes: frame(1))).dispose();
      (await cache.load(key: 'b', targetWidth: 200, readBytes: frame(2))).dispose();
      // Touching 'a' makes 'b' the stale one.
      (await cache.load(key: 'a', targetWidth: 200, readBytes: frame(1))).dispose();
      (await cache.load(key: 'c', targetWidth: 200, readBytes: frame(3))).dispose();

      expect(cache.length, 2);
      var decodes = 0;
      Future<Uint8List> Function() counted(int seed) {
        final read = frame(seed);
        return () {
          decodes++;
          return read();
        };
      }

      (await cache.load(key: 'a', targetWidth: 200, readBytes: counted(1))).dispose();
      expect(decodes, 0, reason: 'a was touched and should have survived');
      (await cache.load(key: 'b', targetWidth: 200, readBytes: counted(2))).dispose();
      expect(decodes, 1, reason: 'b was the least recently used and should be gone');
    });

    test('keeps only the viewer\'s preload window', () async {
      final cache = FullPreviewCache();
      addTearDown(cache.clear);

      for (final key in ['a', 'b', 'c', 'd']) {
        (await cache.load(key: key, targetWidth: 100, readBytes: frame(1)))
            .dispose();
      }

      cache.retain({'b', 'c'});

      expect(cache.length, 2);
      expect(cache.byteSize, 2 * 100 * 100 * 4);
    });

    test('keeps a single frame that alone exceeds the budget', () async {
      // A viewer that cannot hold the frame it is displaying is worse than one
      // a little over budget.
      final cache = FullPreviewCache(budgetBytes: 1024);
      addTearDown(cache.clear);

      (await cache.load(key: 'a', targetWidth: 200, readBytes: frame(0)))
          .dispose();

      expect(cache.length, 1);
      expect(cache.byteSize, greaterThan(cache.budgetBytes));
    });
  });
}
