import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/infra/db/database.dart';
import 'package:obscura_pro/infra/preview/thumb_cache.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late ThumbCache cache;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('obscura_thumbs');
    cache = ThumbCache(directory: root, dao: db.thumbCacheDao);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> knowPhoto(String key) => db.catalogDao.insertPhoto(
        PhotosCompanion.insert(cleStable: key, radicalDcf: '100LEICA/$key'),
      );

  group('round trip', () {
    test('returns exactly the bytes it stored, with the placeholder colour',
        () async {
      await knowPhoto('aa11');
      final jpeg = Uint8List.fromList(List.generate(512, (i) => i % 256));

      await cache.store(
        'aa11',
        ThumbVariant.small,
        jpeg: jpeg,
        width: 320,
        height: 213,
        averageColor: 0xFF3C4A5B,
      );
      final hit = await cache.read('aa11', ThumbVariant.small);

      expect(hit, isNotNull);
      expect(hit!.bytes, jpeg);
      expect(hit.width, 320);
      expect(hit.height, 213);
      expect(hit.averageColor, 0xFF3C4A5B);
    });

    test('keeps the two variants of one photograph apart', () async {
      await knowPhoto('bb22');
      await cache.store('bb22', ThumbVariant.small,
          jpeg: Uint8List.fromList([1, 2, 3]));
      await cache.store('bb22', ThumbVariant.full,
          jpeg: Uint8List.fromList([4, 5, 6, 7]));

      expect((await cache.read('bb22', ThumbVariant.small))!.bytes, [1, 2, 3]);
      expect((await cache.read('bb22', ThumbVariant.full))!.bytes, [4, 5, 6, 7]);
    });

    test('reports a miss for a photograph it has never seen', () async {
      expect(await cache.read('nothing', ThumbVariant.small), isNull);
    });

    test('leaves no partial file behind after a write', () async {
      await knowPhoto('cc33');
      await cache.store('cc33', ThumbVariant.small,
          jpeg: Uint8List.fromList([9, 9, 9]));

      final leftovers = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.part'));
      expect(leftovers, isEmpty);
    });
  });

  group('when disk and index disagree', () {
    test('treats a row whose file has vanished as a miss and forgets it',
        () async {
      await knowPhoto('dd44');
      await cache.store('dd44', ThumbVariant.small,
          jpeg: Uint8List.fromList([1, 2, 3]));
      await cache.fileFor('dd44', ThumbVariant.small).delete();

      expect(await cache.read('dd44', ThumbVariant.small), isNull);
      // An index row promising a file that is not there would keep answering
      // "miss" forever while still counting against the eviction budget.
      expect(await db.thumbCacheDao.entryFor('dd44', ThumbVariant.small), isNull);
    });
  });

  group('the budget', () {
    test('does nothing while the cache fits', () async {
      await knowPhoto('ee55');
      await cache.store('ee55', ThumbVariant.small, jpeg: Uint8List(100));

      expect(await cache.evictToBudget(), 0);
      expect(await cache.read('ee55', ThumbVariant.small), isNotNull);
    });

    test('deletes oldest first, files as well as rows, until it fits', () async {
      final small = ThumbCache(directory: root, dao: db.thumbCacheDao, budgetBytes: 250);

      final keys = ['a1', 'b2', 'c3', 'd4'];
      for (var i = 0; i < keys.length; i++) {
        await knowPhoto(keys[i]);
        await small.store(keys[i], ThumbVariant.small, jpeg: Uint8List(100));
        // `createdAt` defaults to the wall clock, which has one-second
        // resolution here — four rows written in the same millisecond would tie,
        // and "oldest first" would mean nothing. Stamping them by hand is the
        // only way the ordering under test is the one being asserted.
        await db.customStatement(
          'UPDATE thumb_cache SET created_at = ? WHERE cle_stable = ?',
          [1700000000 + i, keys[i]],
        );
      }

      final removed = await small.evictToBudget();

      expect(removed, 2);
      expect(await small.read('a1', ThumbVariant.small), isNull);
      expect(await small.read('b2', ThumbVariant.small), isNull);
      expect(await small.read('c3', ThumbVariant.small), isNotNull);
      expect(await small.read('d4', ThumbVariant.small), isNotNull);
      expect(small.fileFor('a1', ThumbVariant.small).existsSync(), isFalse);
    });
  });

  group('forgetting a photograph', () {
    test('removes every variant, on disk and in the index', () async {
      await knowPhoto('ff66');
      await cache.store('ff66', ThumbVariant.small, jpeg: Uint8List(10));
      await cache.store('ff66', ThumbVariant.full, jpeg: Uint8List(20));

      await cache.forget('ff66');

      expect(await db.thumbCacheDao.entriesFor('ff66'), isEmpty);
      expect(cache.fileFor('ff66', ThumbVariant.small).existsSync(), isFalse);
      expect(cache.fileFor('ff66', ThumbVariant.full).existsSync(), isFalse);
    });

    test('the cascade drops the index when the photograph is purged', () async {
      await knowPhoto('gg77');
      final photo = await db.catalogDao.photoByStableKey('gg77');
      await cache.store('gg77', ThumbVariant.small, jpeg: Uint8List(10));

      await db.catalogDao.purgePhoto(photo!.id);

      expect(await db.thumbCacheDao.entriesFor('gg77'), isEmpty);
    });
  });

  test('collects the placeholder colours in one pass', () async {
    for (final (key, color) in [('h1', 0xFF102030), ('h2', 0xFF405060)]) {
      await knowPhoto(key);
      await cache.store(key, ThumbVariant.small,
          jpeg: Uint8List(4), averageColor: color);
    }
    await knowPhoto('h3');
    await cache.store('h3', ThumbVariant.small, jpeg: Uint8List(4));

    final colors = await cache.placeholderColors();

    expect(colors, {'h1': 0xFF102030, 'h2': 0xFF405060});
  });
}
