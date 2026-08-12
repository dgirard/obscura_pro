import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/layers/layer_placement.dart';
import 'package:obscura_pro/features/layers/layer_repository.dart';
import 'package:obscura_pro/features/layers/patterns/pattern_library.dart';
import 'package:obscura_pro/infra/db/database.dart';

/// U14. The composition on disk.
void main() {
  late AppDatabase db;
  late LayerRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LayerRepository(db);
  });

  tearDown(() => db.close());

  group('the seeded library', () {
    test('is the document\'s thirty, addressable by code', () async {
      final ids = await repository.patternIds();

      expect(ids, hasLength(30));
      expect(ids['golden-spiral'], isNotNull);
      final row = await db.catalogDao.patternByCode('golden-spiral');
      expect(row!.nom, 'Spirale d\'or (Fibonacci)');
      expect(row.categorie, 'grilles');
      expect(row.kind, 'guide');
    });

    test('says which of the thirty can be laid over a photograph', () async {
      await repository.patternIds();
      final rows = await db.catalogDao.allPatterns();

      expect(rows.where((r) => r.kind == 'guide'), hasLength(15));
      expect(rows.where((r) => r.kind == 'reference'), hasLength(15));
      expect(
        rows.where((r) => r.kind == 'guide').map((r) => r.code).toSet(),
        placeableGuides.map((p) => p.code).toSet(),
      );
    });

    test('re-seeding keeps the ids a saved layer points at', () async {
      final first = await repository.patternIds();
      final again = await LayerRepository(db).patternIds();

      expect(again, first);
      expect(await db.catalogDao.allPatterns(), hasLength(30));
    });
  });

  group('saving', () {
    test('writes normalized geometry, not pixels', () async {
      final photo = _photo();
      await repository.save(photo, [
        LayerPlacement(
          localId: 1,
          patternCode: 'golden-spiral',
          position: const Offset(0.382, 0.618),
          scaleX: 0.5,
          scaleY: 0.25,
          rotation: math.pi / 6,
          opacity: 0.42,
          color: 0xFFE11B22,
          locked: true,
          obscura: true,
        ),
      ]);

      final photoRow = await db.catalogDao.photoByStableKey(photo.key.value);
      final row = (await db.compositionDao.layersOfPhoto(photoRow!.id)).single;

      expect(row.posX, closeTo(0.382, 1e-9));
      expect(row.posY, closeTo(0.618, 1e-9));
      expect(row.scaleX, closeTo(0.5, 1e-9));
      expect(row.scaleY, closeTo(0.25, 1e-9));
      expect(row.rotation, closeTo(math.pi / 6, 1e-9));
      expect(row.opacity, closeTo(0.42, 1e-9));
      expect(row.color, 0xFFE11B22);
      expect(row.locked, isTrue);
      expect(row.obscura, isTrue);
    });

    test('gives a new placement its row id and updates it afterwards', () async {
      final photo = _photo();
      final saved = await repository.save(photo, [
        const LayerPlacement(localId: 1, patternCode: 'rule-of-thirds'),
      ]);
      expect(saved.single.rowId, isNotNull);

      final again = await repository.save(photo, [
        saved.single.movedTo(const Offset(0.2, 0.2)),
      ]);

      // The same row moved, not a second one: a drag must not fill the table.
      expect(again.single.rowId, saved.single.rowId);
      final photoRow = await db.catalogDao.photoByStableKey(photo.key.value);
      final rows = await db.compositionDao.layersOfPhoto(photoRow!.id);
      expect(rows, hasLength(1));
      expect(rows.single.posX, closeTo(0.2, 1e-9));
    });

    test('deleting one leaves the others where they were', () async {
      final photo = _photo();
      final saved = await repository.save(photo, [
        const LayerPlacement(localId: 1, patternCode: 'rule-of-thirds'),
        const LayerPlacement(localId: 2, patternCode: 'symmetry', zIndex: 1),
        const LayerPlacement(localId: 3, patternCode: 'golden-spiral', zIndex: 2),
      ]);

      await repository.save(photo, [saved.first, saved.last]);

      final left = await repository.layersOf(photo);
      expect(left.map((l) => l.patternCode), ['rule-of-thirds', 'golden-spiral']);
      expect(left.map((l) => l.rowId), [saved.first.rowId, saved.last.rowId]);
    });

    test('a code this build does not know is kept but not written', () async {
      final photo = _photo();
      final saved = await repository.save(photo, [
        const LayerPlacement(localId: 1, patternCode: 'from-a-later-grammar'),
      ]);

      // Returned unchanged and with no row id, which is how the caller can tell
      // that this one is not on disk.
      expect(saved.single.rowId, isNull);
      expect(await repository.layersOf(photo), isEmpty);
    });
  });

  group('reading back', () {
    test('finds the composition through the stable key, not the path', () async {
      final onOneReader = _photo(mountedAt: '/Volumes/Q3');
      await repository.save(onOneReader, [
        const LayerPlacement(
          localId: 1,
          patternCode: 'golden-spiral',
          position: Offset(0.7, 0.3),
        ),
      ]);

      // Ejected and put back somewhere else -- AE3 at the unit level.
      final onAnother = _photo(mountedAt: '/Volumes/NO NAME 1');
      final layers = await LayerRepository(db).layersOf(onAnother);

      expect(layers.single.patternCode, 'golden-spiral');
      expect(layers.single.position, const Offset(0.7, 0.3));
    });

    test('comes back in paint order', () async {
      final photo = _photo();
      await repository.save(photo, [
        const LayerPlacement(localId: 1, patternCode: 'symmetry', zIndex: 5),
        const LayerPlacement(localId: 2, patternCode: 'rule-of-thirds', zIndex: 1),
      ]);

      expect(
        (await repository.layersOf(photo)).map((l) => l.patternCode),
        ['rule-of-thirds', 'symmetry'],
      );
    });

    test('a photograph nobody has composed on has no layers', () async {
      expect(await repository.layersOf(_photo(radical: 'L1009999')), isEmpty);
    });

    test('forgetting a photograph takes its composition with it', () async {
      final photo = _photo();
      await repository.save(photo, [
        const LayerPlacement(localId: 1, patternCode: 'rule-of-thirds'),
      ]);
      final row = await db.catalogDao.photoByStableKey(photo.key.value);

      await db.catalogDao.purgePhoto(row!.id);

      expect(await db.compositionDao.layersOfPhoto(row.id), isEmpty);
      // And the library it pointed at is untouched: patterns are reference
      // data, not the user's work.
      expect(await db.catalogDao.allPatterns(), hasLength(30));
    });
  });
}

PhotoEntity _photo({
  String radical = 'L1000001',
  String mountedAt = '/Volumes/Q3',
}) =>
    PhotoEntity(
      radical: radical,
      folder: '100LEICA',
      key: StableKey.fromExif(
        dcfRadical: '100LEICA/$radical',
        captureTime: DateTime.utc(2026, 3, 14, 9, 26, 53),
        bodySerial: '5301234',
      ),
      files: [
        PhotoFile(
          name: '$radical.DNG',
          path: '$mountedAt/DCIM/100LEICA/$radical.DNG',
          kind: PhotoFileKind.raw,
          sizeBytes: 84000000,
          modified: DateTime.utc(2026, 3, 14),
        ),
      ],
    );
