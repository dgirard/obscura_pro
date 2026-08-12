import 'dart:io';

// `show Value`: drift also exports `isNull`/`isNotNull` as SQL expression
// builders, which would shadow the matchers of the same name.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/infra/db/database.dart';

/// The Mac-side schema. Everything here runs against an in-memory database:
/// the card is never involved, in tests no more than in production.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<int> insertPhoto({
    String cleStable = 'key-1',
    String radical = '100LEICA/L1000001',
  }) {
    return db.catalogDao.insertPhoto(
      PhotosCompanion.insert(
        cleStable: cleStable,
        radicalDcf: radical,
        dateOrigin: Value(DateTime.utc(2026, 3, 14, 9, 26, 53)),
        serialBoitier: const Value('5301234'),
        dngPresent: const Value(true),
        jpgPresent: const Value(true),
      ),
    );
  }

  Future<int> insertPattern({String code = 'golden_spiral'}) {
    return db.into(db.patterns).insert(
          PatternsCompanion.insert(
            code: code,
            nom: 'Spirale dorée',
            categorie: 'grilles',
            kind: const Value('guide'),
          ),
        );
  }

  Future<int> insertTrashItem(
    int photoId, {
    TrashFileKind kind = TrashFileKind.dng,
    TrashState state = TrashState.marked,
    int bytes = 84000000,
  }) {
    return db.trashDao.upsertItem(
      TrashItemsCompanion.insert(
        photoId: photoId,
        fileKind: kind,
        cardRelativePath: 'DCIM/100LEICA/L1000001.${kind == TrashFileKind.dng ? 'DNG' : 'JPG'}',
        state: state,
        byteSize: Value(bytes),
      ),
    );
  }

  group('migration', () {
    test('upgrades a v1 database in place, keeping the rows it already held',
        () async {
      final dir = await Directory.systemTemp.createTemp('obscura_migration');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/v1.sqlite');

      // The v1 schema, written by hand: the thumbnail index before it carried a
      // placeholder colour or a pixel size, and the pattern library while it
      // still claimed to hold SVG. Both of the steps this database has to climb
      // are in here, because a migration chain is only ever exercised from the
      // oldest schema anybody still has.
      final upgraded = AppDatabase.forTesting(NativeDatabase(file, setup: (raw) {
        if (raw.userVersion != 0) return;
        raw
          ..execute('CREATE TABLE photo (id INTEGER NOT NULL PRIMARY KEY '
              'AUTOINCREMENT, cle_stable TEXT NOT NULL UNIQUE, '
              'radical_dcf TEXT NOT NULL)')
          ..execute('CREATE TABLE thumb_cache (id INTEGER NOT NULL PRIMARY KEY '
              'AUTOINCREMENT, cle_stable TEXT NOT NULL REFERENCES photo '
              '(cle_stable) ON DELETE CASCADE, variant TEXT NOT NULL, '
              'cache_path TEXT NOT NULL, byte_size INTEGER NOT NULL, '
              "created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')), "
              'UNIQUE (cle_stable, variant))')
          ..execute('CREATE TABLE pattern (id INTEGER NOT NULL PRIMARY KEY '
              'AUTOINCREMENT, code TEXT NOT NULL UNIQUE, nom TEXT NOT NULL, '
              'categorie TEXT NOT NULL, svg TEXT NOT NULL, aspect_ratio REAL)')
          ..execute("INSERT INTO pattern (code, nom, categorie, svg) "
              "VALUES ('rule-of-thirds', 'Règle des tiers', 'grilles', 'M0,0')")
          ..execute("INSERT INTO photo (cle_stable, radical_dcf) "
              "VALUES ('legacy-key', '100LEICA/L1000001')")
          ..execute('INSERT INTO thumb_cache (cle_stable, variant, cache_path, '
              "byte_size) VALUES ('legacy-key', 'small', '/tmp/legacy.jpg', 42)")
          ..userVersion = 1;
      }));
      addTearDown(upgraded.close);

      final row =
          await upgraded.thumbCacheDao.entryFor('legacy-key', ThumbVariant.small);

      expect(row, isNotNull);
      expect(row!.byteSize, 42);
      // The new columns exist and are empty rather than defaulted to a wrong
      // colour: a cache row predating the placeholder simply has none, and the
      // grid falls back to the neutral cell it uses for an unknown photograph.
      expect(row.averageColor, isNull);
      expect(row.pixelWidth, isNull);

      // And the pattern it also held came across the v3 step, which rebuilds
      // that table.
      final pattern = await upgraded.catalogDao.patternByCode('rule-of-thirds');
      expect(pattern, isNotNull);
      expect(pattern!.kind, 'guide');
    });
  });

  group('schema', () {
    test('creates every table cleanly at schemaVersion 3', () async {
      expect(db.schemaVersion, 3);

      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")
          .map((row) => row.read<String>('name'))
          .get();

      expect(
        tables,
        containsAll(<String>[
          'crop_export',
          'layer_instance',
          'pattern',
          'photo',
          'thumb_cache',
          'trash_item',
        ]),
      );

      // `user_version` is what drift compares against `schemaVersion` on the
      // next open; a fresh create that leaves it at 0 would re-run migrations.
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), db.schemaVersion);
    });

    test('enforces foreign keys on the connection', () async {
      // Off by default in SQLite, and every cascade below depends on it.
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.read<int>('foreign_keys'), 1);
    });

    test('asks SQLite for the durability the deletion machinery assumes', () {
      // Intent rows must be on disk before a card file is unlinked.
      expect(durabilityPragmas, contains('PRAGMA synchronous = FULL'));
      expect(durabilityPragmas, contains('PRAGMA journal_mode = WAL'));
    });
  });

  group('pattern', () {
    test('round-trips and is addressable by code', () async {
      await insertPattern();
      final found = await db.catalogDao.patternByCode('golden_spiral');

      expect(found, isNotNull);
      expect(found!.nom, 'Spirale dorée');
      expect(found.categorie, 'grilles');
      expect(found.kind, 'guide');
    });

    test('re-seeding updates in place instead of duplicating', () async {
      final seededId = await insertPattern();
      await db.catalogDao.upsertPatterns([
        PatternsCompanion.insert(
          code: 'golden_spiral',
          nom: 'Spirale de Fibonacci',
          categorie: 'grilles',
        ),
      ]);

      final all = await db.catalogDao.allPatterns();
      expect(all, hasLength(1));
      expect(all.single.nom, 'Spirale de Fibonacci');
      // The id must survive a re-seed, or every layer instance placed before it
      // would point at a different pattern.
      expect(all.single.id, seededId);
    });
  });

  group('photo', () {
    test('round-trips the identity fields and starts with no preview offsets', () async {
      final id = await insertPhoto();
      final photo = await db.catalogDao.photoById(id);

      expect(photo!.cleStable, 'key-1');
      expect(photo.radicalDcf, '100LEICA/L1000001');
      expect(photo.serialBoitier, '5301234');
      expect(photo.dngPresent, isTrue);
      // The header parser has not run yet; anything but null here would send a
      // decode worker to a byte range nobody measured.
      expect(photo.previewSmallOffset, isNull);
      expect(photo.previewFullLength, isNull);
    });

    test('rejects a second row for the same stable key', () async {
      await insertPhoto(cleStable: 'key-1');

      // Two rows for one file would let one row believe a file is on the card
      // while the other has already had it deleted.
      await expectLater(
        insertPhoto(cleStable: 'key-1', radical: '101LEICA/L1010001'),
        throwsA(isA<SqliteException>()),
      );
    });

    test('records the header-parse result so IFDs are walked once', () async {
      final id = await insertPhoto();
      await db.catalogDao.recordPreviewOffsets(
        id,
        smallOffset: 4096,
        smallLength: 65536,
        fullOffset: 131072,
        fullLength: 2097152,
      );

      final photo = await db.catalogDao.photoById(id);
      expect(photo!.previewSmallOffset, 4096);
      expect(photo.previewSmallLength, 65536);
      expect(photo.previewFullOffset, 131072);
      expect(photo.previewFullLength, 2097152);
    });
  });

  group('layer_instance', () {
    test('round-trips normalized geometry in paint order', () async {
      final photoId = await insertPhoto();
      final patternId = await insertPattern();

      await db.compositionDao.addLayer(
        LayerInstancesCompanion.insert(
          photoId: photoId,
          patternId: patternId,
          color: 0x99D8D8D8,
          posX: const Value(0.25),
          posY: const Value(0.75),
          rotation: const Value(0.7853981633974483),
          zIndex: const Value(2),
        ),
      );
      await db.compositionDao.addLayer(
        LayerInstancesCompanion.insert(
          photoId: photoId,
          patternId: patternId,
          color: 0xFFE11B22,
          zIndex: const Value(1),
          obscura: const Value(true),
        ),
      );

      final layers = await db.compositionDao.layersOfPhoto(photoId);
      expect(layers.map((l) => l.zIndex), [1, 2]);
      expect(layers.first.obscura, isTrue);
      expect(layers.last.posX, closeTo(0.25, 1e-9));
      expect(layers.last.posY, closeTo(0.75, 1e-9));
      expect(layers.last.rotation, closeTo(0.7853981633974483, 1e-12));
      // Defaults must be the identity transform, not zero scale.
      expect(layers.first.scaleX, 1.0);
      expect(layers.first.opacity, 1.0);
    });

    test('refuses to delete a pattern that layers still reference', () async {
      final photoId = await insertPhoto();
      final patternId = await insertPattern();
      await db.compositionDao.addLayer(
        LayerInstancesCompanion.insert(
          photoId: photoId,
          patternId: patternId,
          color: 0xFFFFFFFF,
        ),
      );

      // Cascading here would silently erase the user's composition.
      await expectLater(
        (db.delete(db.patterns)..where((p) => p.id.equals(patternId))).go(),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('crop_export', () {
    test('round-trips a normalized rect and a Mac destination', () async {
      final photoId = await insertPhoto();
      await db.compositionDao.recordCropExport(
        CropExportsCompanion.insert(
          photoId: photoId,
          ratio: '65:24',
          orientation: 'landscape',
          rectX: 0.1,
          rectY: 0.2,
          rectW: 0.8,
          rectH: 0.3,
          exportPath: '/Users/photographe/Exports/L1000001-6524.jpg',
        ),
      );

      final exports = await db.compositionDao.exportsOfPhoto(photoId);
      expect(exports, hasLength(1));
      expect(exports.single.ratio, '65:24');
      expect(exports.single.rectW, closeTo(0.8, 1e-9));
      expect(exports.single.exportPath, startsWith('/Users/'));
      expect(exports.single.createdAt, isNotNull);
    });
  });

  group('thumb_cache', () {
    test('holds one entry per stable key and variant, under application-support', () async {
      await insertPhoto(cleStable: 'key-1');
      await db.thumbCacheDao.upsertEntry(
        ThumbCacheEntriesCompanion.insert(
          cleStable: 'key-1',
          variant: ThumbVariant.small,
          cachePath: '/Users/photographe/Library/Application Support/obscura_pro/thumbs/key-1.s',
          byteSize: 48000,
        ),
      );
      await db.thumbCacheDao.upsertEntry(
        ThumbCacheEntriesCompanion.insert(
          cleStable: 'key-1',
          variant: ThumbVariant.full,
          cachePath: '/Users/photographe/Library/Application Support/obscura_pro/thumbs/key-1.f',
          byteSize: 900000,
        ),
      );
      // Re-decoding the same variant replaces the row rather than adding one.
      await db.thumbCacheDao.upsertEntry(
        ThumbCacheEntriesCompanion.insert(
          cleStable: 'key-1',
          variant: ThumbVariant.small,
          cachePath: '/Users/photographe/Library/Application Support/obscura_pro/thumbs/key-1.s',
          byteSize: 52000,
        ),
      );

      final entries = await db.thumbCacheDao.entriesFor('key-1');
      expect(entries, hasLength(2));
      expect(await db.thumbCacheDao.totalBytes(), 952000);

      final small = await db.thumbCacheDao.entryFor('key-1', ThumbVariant.small);
      expect(small!.byteSize, 52000);
    });
  });

  group('trash_item', () {
    test('round-trips every state of the deletion machine', () async {
      final photoId = await insertPhoto();
      final itemId = await insertTrashItem(photoId, state: TrashState.onCard);

      for (final state in TrashState.values) {
        await db.trashDao.recordIntent(itemId, state);
        final items = await db.trashDao.itemsOfPhoto(photoId);
        expect(items.single.state, state, reason: '$state must survive a round-trip');
        expect(await db.trashDao.itemsInState(state), hasLength(1));
      }

      // Stored as readable text: an interrupted run is diagnosed by hand.
      final raw = await db
          .customSelect('SELECT state FROM trash_item')
          .map((row) => row.read<String>('state'))
          .getSingle();
      expect(raw, TrashState.uncertain.name);
    });

    test('tracks the two files of one entity independently', () async {
      final photoId = await insertPhoto();
      await insertTrashItem(photoId, kind: TrashFileKind.dng, state: TrashState.deleted);
      await insertTrashItem(photoId, kind: TrashFileKind.jpg, state: TrashState.marked);

      final items = await db.trashDao.itemsOfPhoto(photoId);
      expect(items, hasLength(2));
      // A crash between the two unlinks leaves exactly this shape.
      expect(
        items.map((i) => '${i.fileKind.name}:${i.state.name}').toSet(),
        {'dng:deleted', 'jpg:marked'},
      );
    });

    test('starts unverified rather than claiming a check that never happened', () async {
      final photoId = await insertPhoto();
      final itemId = await insertTrashItem(photoId);
      var item = (await db.trashDao.itemsOfPhoto(photoId)).single;

      // Null is the only honest default: no copy has been hashed yet.
      expect(item.sourceHash, isNull);
      expect(item.verifiedAt, isNull);
      expect(item.macTrashPath, isNull);

      // An intent must not fabricate verification either.
      await db.trashDao.recordIntent(itemId, TrashState.movingToMacTrash);
      item = (await db.trashDao.itemsOfPhoto(photoId)).single;
      expect(item.sourceHash, isNull);
      expect(item.verifiedAt, isNull);

      final verifiedAt = DateTime.utc(2026, 8, 11, 12);
      await db.trashDao.commitOutcome(
        itemId,
        TrashState.movedToMacTrash,
        sourceHash: 'sha256:abc',
        verifiedAt: verifiedAt,
        macTrashPath: '/Users/photographe/Library/Application Support/obscura_pro/Trash/key-1',
      );
      item = (await db.trashDao.itemsOfPhoto(photoId)).single;
      expect(item.sourceHash, 'sha256:abc');
      // Drift stores instants as unix seconds and hands them back in local
      // time, so compare the instant rather than the wall clock.
      expect(item.verifiedAt!.toUtc(), verifiedAt);
    });

    test('surfaces rows an interrupted run left mid-flight', () async {
      final photoId = await insertPhoto();
      final dngId = await insertTrashItem(photoId, kind: TrashFileKind.dng);
      await insertTrashItem(photoId, kind: TrashFileKind.jpg, state: TrashState.marked);
      await db.trashDao.recordIntent(dngId, TrashState.deleting);

      final inFlight = await db.trashDao.inFlightItems();
      expect(inFlight, hasLength(1));
      expect(inFlight.single.id, dngId);
    });
  });

  group('reactive queries', () {
    test('marked photo ids re-emit when a photo is marked and unmarked', () async {
      final photoA = await insertPhoto(cleStable: 'key-a', radical: '100LEICA/L1000001');
      final photoB = await insertPhoto(cleStable: 'key-b', radical: '100LEICA/L1000002');

      final emissions = <Set<int>>[];
      final sub = db.trashDao.watchMarkedPhotoIds().listen(emissions.add);
      await pumpEventQueue();

      final itemA = await insertTrashItem(photoA);
      await pumpEventQueue();

      await insertTrashItem(photoB);
      await pumpEventQueue();

      await db.trashDao.recordIntent(itemA, TrashState.onCard);
      await pumpEventQueue();

      await sub.cancel();

      // The grid badge is bound to this stream; a stream that emits once would
      // leave a deleted photo badged forever.
      // `equals` because Dart sets compare by identity, and `contains` would
      // otherwise never match a freshly built set.
      expect(emissions.first, isEmpty);
      expect(emissions.last, {photoB});
      expect(emissions, contains(equals({photoA})));
      expect(emissions, contains(equals({photoA, photoB})));
    });

    test('trash summary re-emits counts and pending bytes as states move', () async {
      final photoId = await insertPhoto();

      final emissions = <TrashSummary>[];
      final sub = db.trashDao.watchTrashSummary().listen(emissions.add);
      await pumpEventQueue();

      await insertTrashItem(photoId, kind: TrashFileKind.dng, bytes: 84000000);
      await pumpEventQueue();

      final jpgId = await insertTrashItem(photoId, kind: TrashFileKind.jpg, bytes: 6000000);
      await pumpEventQueue();

      // Finishing a deletion removes the bytes from "pending": they are gone.
      await db.trashDao.commitOutcome(jpgId, TrashState.deleted);
      await pumpEventQueue();

      await sub.cancel();

      expect(emissions.first, TrashSummary.empty);
      expect(
        emissions,
        contains(
          const TrashSummary(fileCount: 2, photoCount: 1, pendingBytes: 90000000),
        ),
      );
      expect(
        emissions.last,
        const TrashSummary(fileCount: 1, photoCount: 1, pendingBytes: 84000000),
      );
    });
  });

  group('purging a photo', () {
    test('leaves nothing derived from it behind', () async {
      final photoId = await insertPhoto(cleStable: 'key-1');
      final patternId = await insertPattern();
      await db.compositionDao.addLayer(
        LayerInstancesCompanion.insert(
          photoId: photoId,
          patternId: patternId,
          color: 0xFFFFFFFF,
        ),
      );
      await db.compositionDao.recordCropExport(
        CropExportsCompanion.insert(
          photoId: photoId,
          ratio: '3:2',
          orientation: 'landscape',
          rectX: 0,
          rectY: 0,
          rectW: 1,
          rectH: 1,
          exportPath: '/Users/photographe/Exports/a.jpg',
        ),
      );
      await insertTrashItem(photoId);
      await db.thumbCacheDao.upsertEntry(
        ThumbCacheEntriesCompanion.insert(
          cleStable: 'key-1',
          variant: ThumbVariant.small,
          cachePath: '/tmp/thumbs/key-1.s',
          byteSize: 1000,
        ),
      );

      await db.catalogDao.purgePhoto(photoId);

      // Orphans here would badge, count, and bill bytes for a photo the app no
      // longer knows about.
      expect(await db.compositionDao.layersOfPhoto(photoId), isEmpty);
      expect(await db.compositionDao.exportsOfPhoto(photoId), isEmpty);
      expect(await db.trashDao.itemsOfPhoto(photoId), isEmpty);
      expect(await db.thumbCacheDao.entriesFor('key-1'), isEmpty);

      // The pattern library is reference data and survives.
      expect(await db.catalogDao.allPatterns(), hasLength(1));
    });
  });
}
