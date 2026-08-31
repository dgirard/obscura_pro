import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/exports/export_photo.dart';
import 'package:obscura_pro/infra/preview/preview_extractor.dart';
import 'package:path/path.dart' as p;

import '../../infra/preview/tiff_fixture.dart';

/// A file on the Mac, read as a photograph the rest of the app already knows
/// how to show.
void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('obscura_export_photo');
  });

  tearDown(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  Future<File> writeJpeg(
    String name, {
    int width = 640,
    int height = 427,
    int redOffset = 0,
  }) async {
    final file = File(p.join(folder.path, name));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      realJpeg(width: width, height: height, redOffset: redOffset),
    );
    return file;
  }

  group('reading a file as a photograph', () {
    test('its pixels are the whole file', () async {
      final file = await writeJpeg('L1000001_3x2_01.jpg');

      final photo = (await readExportedPhoto(file))!;

      final stream = photo.viewerPreview!;
      expect(stream.kind, PreviewStreamKind.wholeFile);
      expect(stream.offset, 0);
      expect(stream.length, await file.length());
      expect(stream.width, 640);
      expect(stream.height, 427);
    });

    test('it carries its own file, so the decoders have bytes to read',
        () async {
      final file = await writeJpeg('a.jpg');

      final photo = (await readExportedPhoto(file))!;

      // Everything downstream resolves its bytes through `fileForStream`; an
      // entity with no files fails at the point of use rather than here.
      final resolved = photo.fileForStream(photo.viewerPreview!);
      expect(resolved, isNotNull);
      expect(resolved!.path, file.path);
      expect(resolved.kind, PhotoFileKind.jpeg);
    });

    test('its name is the radical, and it claims no card folder', () async {
      final file = await writeJpeg('L1000864_3x2_04.jpg');

      final photo = (await readExportedPhoto(file))!;

      expect(photo.radical, 'L1000864_3x2_04');
      // A photograph on the Mac has no DCF folder, and inventing one would be
      // the first step towards a card path.
      expect(photo.folder, isEmpty);
      expect(photo.dcfPath, 'L1000864_3x2_04');
    });

    test('a file that is not a photograph yields nothing', () async {
      final text = File(p.join(folder.path, 'notes.txt'));
      await text.writeAsString('not a jpeg');

      expect(await readExportedPhoto(text), isNull);
      expect(await readExportedPhoto(File(p.join(folder.path, 'gone.jpg'))),
          isNull);
    });

    test('a truncated file yields nothing rather than an entity that cannot '
        'be decoded', () async {
      final file = File(p.join(folder.path, 'half.jpg'));
      await file.writeAsBytes(realJpeg(width: 64, height: 64).sublist(0, 12));

      expect(await readExportedPhoto(file), isNull);
    });
  });

  group('identity', () {
    test('survives the file being moved', () async {
      final file = await writeJpeg('a.jpg');
      final first = (await readExportedPhoto(file))!;

      final moved = File(p.join(folder.path, 'elsewhere', 'a.jpg'));
      await moved.parent.create(recursive: true);
      await file.rename(moved.path);

      // A path is not an identity — that is why the card side has stable keys
      // at all, and a composition must not be lost to a Finder drag.
      expect((await readExportedPhoto(moved))!.key.value, first.key.value);
    });

    test('two different exports are two different photographs', () async {
      final one = await writeJpeg('one.jpg', width: 640, height: 427);
      final two = await writeJpeg('two.jpg', width: 320, height: 213);

      expect(
        (await readExportedPhoto(one))!.key.value,
        isNot((await readExportedPhoto(two))!.key.value),
      );
    });

    test('two files of the same shape but different pixels differ too',
        () async {
      final one = await writeJpeg('one.jpg', redOffset: 0);
      final two = await writeJpeg('two.jpg', redOffset: 90);

      expect(
        (await readExportedPhoto(one))!.key.value,
        isNot((await readExportedPhoto(two))!.key.value),
      );
    });

    test('records the weaker basis when the file carries no capture time',
        () async {
      // The fixture writes no EXIF date, so this is the fallback path.
      final photo = (await readExportedPhoto(await writeJpeg('a.jpg')))!;

      expect(photo.key.basis, StableKeyBasis.macFile);
    });
  });
}
