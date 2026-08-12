import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/infra/db/database.dart';
import 'package:path/path.dart' as p;

/// Schema v2 → v4: the pattern library stops claiming to hold SVG (v3), and an
/// export records the size it came out at (v4).
///
/// The v3 step rebuilds `pattern`, which is the one kind of migration that can
/// quietly break a foreign key — so the test puts a layer instance on a pattern
/// first and checks it still points at it afterwards. The database is taken
/// back to v2 with raw statements rather than restored from a dump, because
/// what changed is a handful of columns and a dump would be a second copy of
/// them to keep in step.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('obscura_migration');
    file = File(p.join(dir.path, 'obscura_pro.sqlite'));
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// A database as v2 left it: a seeded pattern, a photo, a layer on both, and
  /// an export from before exports recorded their pixel size.
  Future<void> writeVersion2() async {
    final db = AppDatabase.forTesting(NativeDatabase(file));
    // Forces the schema to exist before it is taken apart.
    await db.catalogDao.allPatterns();

    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE pattern');
    await db.customStatement(
      'CREATE TABLE pattern ('
      'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      'code TEXT NOT NULL UNIQUE, '
      'nom TEXT NOT NULL, '
      'categorie TEXT NOT NULL, '
      'svg TEXT NOT NULL, '
      'aspect_ratio REAL)',
    );
    await db.customStatement(
      "INSERT INTO pattern (id, code, nom, categorie, svg, aspect_ratio) "
      "VALUES (7, 'golden-spiral', 'Spirale d''or', 'grilles', "
      "'M0,0 C0.5,0 1,0.5 1,1', 1.618)",
    );
    await db.customStatement(
      "INSERT INTO photo (id, cle_stable, radical_dcf, dng_present, jpg_present) "
      "VALUES (1, 'key-1', '100LEICA/L1000001', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO layer_instance (id, photo_id, pattern_id, pos_x, pos_y, '
      'scale_x, scale_y, rotation, opacity, color, z_index, locked, obscura) '
      'VALUES (1, 1, 7, 0.5, 0.5, 1, 1, 0, 0.6, 4292927448, 0, 0, 0)',
    );
    await db.customStatement('DROP TABLE crop_export');
    await db.customStatement(
      'CREATE TABLE crop_export ('
      'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      'photo_id INTEGER NOT NULL REFERENCES photo (id) ON DELETE CASCADE, '
      'ratio TEXT NOT NULL, orientation TEXT NOT NULL, '
      'rect_x REAL NOT NULL, rect_y REAL NOT NULL, '
      'rect_w REAL NOT NULL, rect_h REAL NOT NULL, '
      'export_path TEXT NOT NULL, '
      "created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')))",
    );
    await db.customStatement(
      'INSERT INTO crop_export (id, photo_id, ratio, orientation, rect_x, '
      'rect_y, rect_w, rect_h, export_path) '
      "VALUES (1, 1, '3:2', 'landscape', 0, 0, 1, 1, "
      "'/Users/x/Pictures/Q3Culling/Exports/2026-08-01/L1000001_3x2_01.jpg')",
    );
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();
  }

  test('carries the library across, and the layers that point at it', () async {
    await writeVersion2();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    final patterns = await db.catalogDao.allPatterns();
    expect(patterns, hasLength(1));
    expect(patterns.single.id, 7, reason: 'a renumbered pattern orphans layers');
    expect(patterns.single.code, 'golden-spiral');
    expect(patterns.single.nom, 'Spirale d\'or');
    // The column that could not tell the truth about a construction built from
    // the frame is gone; what is left says which kind of pattern this is.
    expect(patterns.single.kind, 'guide');

    final layers = await db.compositionDao.layersOfPhoto(1);
    expect(layers.single.patternId, 7);

    // And the table added on the way up is there and usable, on a database
    // that predates it by three steps.
    await db.compositionDao.markForExport(1);
    expect(await db.compositionDao.markedForExport(), {'key-1'});
  });

  test('keeps an export written before it could say how large it was', () async {
    await writeVersion2();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    final (export, photo) = (await db.compositionDao.allExports()).single;
    expect(export.ratio, '3:2');
    expect(photo.radicalDcf, '100LEICA/L1000001');
    // Null rather than a guess: the file's size is knowable only by decoding
    // it, and inventing a number here would put it in a column the exports
    // screen presents as recorded fact.
    expect(export.pixelWidth, isNull);
    expect(export.pixelHeight, isNull);
  });

  test('leaves a current database alone', () async {
    var db = AppDatabase.forTesting(NativeDatabase(file));
    await db.catalogDao.allPatterns();
    await db.close();

    db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    expect(await db.catalogDao.allPatterns(), isEmpty);
  });
}
