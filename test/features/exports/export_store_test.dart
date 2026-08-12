import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/crop/export_service.dart';
import 'package:obscura_pro/features/crop/ratio.dart';
import 'package:obscura_pro/features/exports/export_store.dart';
import 'package:obscura_pro/infra/db/database.dart';
import 'package:path/path.dart' as p;

/// The traceability of an export, and what the list says about the file.
void main() {
  late AppDatabase db;
  late DriftExportStore store;
  late Directory folder;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = DriftExportStore(db);
    folder = await Directory.systemTemp.createTemp('obscura_exports');
  });

  tearDown(() async {
    await db.close();
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  /// A file where an export would be, with something in it.
  Future<File> writeFile(String name) async {
    final file = File(p.join(folder.path, name));
    await file.writeAsBytes(List<int>.filled(2048, 7));
    return file;
  }

  Future<void> record(
    String name, {
    CropRatio ratio = CropRatio.threeTwo,
    int width = 9520,
    int height = 6336,
    String radical = 'L1000001',
  }) async {
    await store.record(
      photo: _photo(radical: radical),
      crop: CropRect.largestIn(frameAspect: 3 / 2, ratio: ratio),
      written: ExportWritten(
        path: p.join(folder.path, name),
        pixelWidth: width,
        pixelHeight: height,
        bytes: 2048,
      ),
    );
  }

  group('recording', () {
    test('writes the crop, the file and the size it came out at', () async {
      await writeFile('L1000001_3x2_01.jpg');
      await record('L1000001_3x2_01.jpg');

      final entry = (await store.all()).single;
      expect(entry.radical, '100LEICA/L1000001');
      expect(entry.ratio, '3:2');
      expect(entry.pixelWidth, 9520);
      expect(entry.pixelHeight, 6336);
      expect(entry.fileName, 'L1000001_3x2_01.jpg');
      expect(entry.byteSize, 2048);
      expect(entry.missing, isFalse);
    });

    test('attaches the export to the photograph, by stable key', () async {
      await writeFile('a.jpg');
      await writeFile('b.jpg');
      await record('a.jpg');
      await record('b.jpg', ratio: CropRatio.square);

      // One photo row for two exports of the same frame: the export is filed
      // under the photograph, not under the file name it happened to get.
      expect(await db.catalogDao.allPhotos(), hasLength(1));
      expect(await store.all(), hasLength(2));
    });

    test('two frames keep their own names', () async {
      await writeFile('a.jpg');
      await writeFile('b.jpg');
      await record('a.jpg', radical: 'L1000001');
      await record('b.jpg', radical: 'L1000002');

      expect(
        (await store.all()).map((e) => e.radical).toSet(),
        {'100LEICA/L1000001', '100LEICA/L1000002'},
      );
    });
  });

  group('the list', () {
    test('is newest first', () async {
      for (final name in ['first.jpg', 'second.jpg', 'third.jpg']) {
        await writeFile(name);
        await record(name);
      }

      expect(
        (await store.all()).map((e) => e.fileName),
        ['third.jpg', 'second.jpg', 'first.jpg'],
      );
    });

    test('says when the file is not there any more', () async {
      final file = await writeFile('gone.jpg');
      await record('gone.jpg');
      await file.delete();

      final entry = (await store.all()).single;
      // The row is still the record of an export that happened. What changed is
      // what is on disk, and the screen has to be able to say so rather than
      // offering to open a file that is not there.
      expect(entry.missing, isTrue);
      expect(entry.byteSize, isNull);
      expect(entry.pixelWidth, 9520);
    });

    test('names the dated folder each export was written into', () async {
      await writeFile('x.jpg');
      await record('x.jpg');

      expect((await store.all()).single.folder, p.basename(folder.path));
    });

    test('quotes a size only when one was recorded', () async {
      await writeFile('x.jpg');
      await record('x.jpg');
      expect((await store.all()).single.dimensions, '9520 × 6336 px');

      await db.compositionDao.recordCropExport(
        CropExportsCompanion.insert(
          photoId: (await db.catalogDao.allPhotos()).single.id,
          ratio: '3:2',
          orientation: 'landscape',
          rectX: 0,
          rectY: 0,
          rectW: 1,
          rectH: 1,
          exportPath: p.join(folder.path, 'old.jpg'),
        ),
      );
      expect((await store.all()).first.dimensions, '—');
    });
  });

  test('forgetting a row leaves the file alone', () async {
    final file = await writeFile('kept.jpg');
    await record('kept.jpg');

    await store.forget((await store.all()).single.id);

    expect(await store.all(), isEmpty);
    // The row is the app's record; the file is the user's. Dropping one must
    // never take the other with it -- the screen moves the file to the Mac's
    // Trash first and then drops the row, and this is the half that must not
    // do it for it.
    expect(await file.exists(), isTrue);
  });
}

PhotoEntity _photo({String radical = 'L1000001'}) => PhotoEntity(
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
          path: '/Volumes/Q3/DCIM/100LEICA/$radical.DNG',
          kind: PhotoFileKind.raw,
          sizeBytes: 84000000,
          modified: DateTime.utc(2026, 3, 14),
        ),
      ],
    );
