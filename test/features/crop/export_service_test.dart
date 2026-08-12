import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obscura_pro/features/catalog/dcf_scanner.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/crop/export_service.dart';
import 'package:obscura_pro/features/crop/ratio.dart';
import 'package:obscura_pro/infra/preview/preview_extractor.dart';
import 'package:obscura_pro/infra/safety/atomic_ops.dart';
import 'package:path/path.dart' as p;

import '../../fixtures/fake_card.dart';

void main() {
  late FakeCard card;
  late Directory exports;
  const service = ExportService();

  setUp(() async {
    card = await FakeCard.create();
    exports = await Directory.systemTemp.createTemp('obscura_exports');
  });

  tearDown(() async {
    await card.dispose();
    if (await exports.exists()) await exports.delete(recursive: true);
  });

  /// The fixture's full-size preview is 640 x 427.
  Future<PhotoEntity> photo({int? orientation}) async {
    await card.addPhoto('L1000001',
        decodable: true, exposure: true, orientation: orientation);
    return (await const DcfScanner().scan(card.path)).photos.single;
  }

  CropRect cropOf(CropRatio ratio, {double frameAspect = 640 / 427}) =>
      CropRect.largestIn(frameAspect: frameAspect, ratio: ratio);

  group('what the export writes', () {
    test('reports each step as it begins', () async {
      final subject = await photo();
      final stages = <ExportStage>[];

      await service.export(
        photo: subject,
        crop: cropOf(CropRatio.square),
        folder: exports,
        onStage: stages.add,
      );

      // In order, and each one before the work it names: the screen shows them
      // while they run, and a step announced after it finished would be a
      // progress line that is always one behind.
      expect(stages, [
        ExportStage.reading,
        ExportStage.rendering,
        ExportStage.writing,
      ]);
    });

    test('stops reporting where it stops working', () async {
      final subject = await photo();
      final stages = <ExportStage>[];

      // No readable stream: nothing is read, nothing is cut, nothing is
      // written, and the progress line must not claim otherwise.
      final outcome = await service.export(
        photo: PhotoEntity(
          radical: subject.radical,
          folder: subject.folder,
          key: subject.key,
          files: subject.files,
        ),
        crop: cropOf(CropRatio.square),
        folder: exports,
        onStage: stages.add,
      );

      expect(outcome, isA<ExportFailed>());
      expect(stages, isEmpty);
    });

    test('produces a decodable JPEG of the cropped dimensions', () async {
      final subject = await photo();

      final outcome = await service.export(
        photo: subject,
        crop: cropOf(CropRatio.square),
        folder: exports,
      );

      expect(outcome, isA<ExportWritten>());
      final written = outcome as ExportWritten;
      final decoded = img.decodeJpg(File(written.path).readAsBytesSync())!;
      expect(decoded.width, written.pixelWidth);
      expect(decoded.height, written.pixelHeight);
      // A square crop of a 640 x 427 frame is 427 on both sides.
      expect(decoded.width, 427);
      expect(decoded.height, 427);
    });

    test('exports at the source resolution, not the screen\'s', () async {
      final subject = await photo();

      final outcome = await service.export(
        photo: subject,
        crop: const CropRect(
          rect: Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
          ratio: CropRatio.square,
          orientation: CropOrientation.landscape,
        ),
        folder: exports,
      ) as ExportWritten;

      // The resolution-loss guard. Half of a 640-wide preview is 320; half of
      // whatever bitmap the crop widget was fed would be a fraction of that,
      // and the two paths look identical in code.
      expect(outcome.pixelWidth, 320);
      expect(outcome.pixelHeight, closeTo(213, 2));
    });

    test('carries the date, camera and exposure over', () async {
      final subject = await photo();

      final outcome = await service.export(
        photo: subject,
        crop: cropOf(CropRatio.threeTwo),
        folder: exports,
      ) as ExportWritten;

      final decoded = img.decodeJpg(File(outcome.path).readAsBytesSync())!;
      expect(
        decoded.exif.exifIfd['DateTimeOriginal'].toString(),
        '2026:03:14 09:26:53',
      );
      expect(decoded.exif.imageIfd['Model'].toString(), 'LEICA Q3');
      expect(decoded.exif.exifIfd[0x8827]?.toInt(), 400);
    });

    test('marks the export upright whatever the source said', () async {
      final subject = await photo(orientation: ExifOrientation.rotate90);

      final outcome = await service.export(
        photo: subject,
        crop: cropOf(CropRatio.square, frameAspect: 427 / 640),
        folder: exports,
      ) as ExportWritten;

      final decoded = img.decodeJpg(File(outcome.path).readAsBytesSync())!;
      // The property that matters: nothing in the file tells a viewer to turn
      // this picture again. Either the tag is absent or it says upright —
      // `image`'s own decoder consumes an identity orientation, so both are the
      // same statement.
      final orientation = decoded.exif.imageIfd.orientation;
      expect(orientation == null || orientation == ExifOrientation.normal, isTrue);
      // And the pixels are already the upright ones.
      expect(outcome.pixelHeight, greaterThanOrEqualTo(outcome.pixelWidth - 1));
    });

    test('crops a portrait frame along the axis the photographer sees',
        () async {
      final subject = await photo(orientation: ExifOrientation.rotate90);

      // Upright, the frame is 427 x 640. An XPan band across it is as wide as
      // the frame and a slice tall.
      final outcome = await service.export(
        photo: subject,
        crop: cropOf(CropRatio.xpan, frameAspect: 427 / 640),
        folder: exports,
      ) as ExportWritten;

      expect(outcome.pixelWidth, 427);
      expect(outcome.pixelHeight, closeTo(427 * 24 / 65, 2));
    });

    test('leaves nothing half-written in the export folder', () async {
      final subject = await photo();

      await service.export(
        photo: subject,
        crop: cropOf(CropRatio.threeTwo),
        folder: exports,
      );

      expect(
        exports.listSync().where((e) => e.path.endsWith('.part')),
        isEmpty,
      );
    });
  });

  group('the source file', () {
    test('is byte-for-byte unchanged by an export', () async {
      final subject = await photo();
      final dng = File(subject.files.firstWhere((f) => f.kind == PhotoFileKind.raw).path);
      final before = await hashOf(dng);

      await service.export(
        photo: subject,
        crop: cropOf(CropRatio.fiveFour),
        folder: exports,
      );

      // Cropping is a decision recorded on the Mac and a new file written on
      // the Mac. The camera's file is opened read-only and closed.
      expect(await hashOf(dng), before);
    });

    test('an unreadable photograph fails without writing anything', () async {
      await card.addCorruptPhoto('L1000999');
      final subject = (await const DcfScanner().scan(card.path)).photos.single;

      final outcome = await service.export(
        photo: subject,
        crop: cropOf(CropRatio.threeTwo),
        folder: exports,
      );

      expect(outcome, isA<ExportFailed>());
      expect(exports.listSync(), isEmpty);
    });
  });

  group('naming', () {
    test('numbers the first export _01 and the second _02', () async {
      final subject = await photo();

      final first = await service.export(
        photo: subject, crop: cropOf(CropRatio.threeTwo), folder: exports,
      ) as ExportWritten;
      final second = await service.export(
        photo: subject, crop: cropOf(CropRatio.threeTwo), folder: exports,
      ) as ExportWritten;

      expect(p.basename(first.path), 'L1000001_3x2_01.jpg');
      expect(p.basename(second.path), 'L1000001_3x2_02.jpg');
      // Two files, not one overwritten: an export is a deliverable, and
      // replacing one silently is how work disappears.
      expect(File(first.path).existsSync(), isTrue);
    });

    test('numbers each ratio separately', () async {
      final subject = await photo();

      await service.export(
        photo: subject, crop: cropOf(CropRatio.threeTwo), folder: exports,
      );
      final square = await service.export(
        photo: subject, crop: cropOf(CropRatio.square), folder: exports,
      ) as ExportWritten;

      // Trying the same frame as a square is a different picture, not a second
      // attempt at the same one.
      expect(p.basename(square.path), 'L1000001_1x1_01.jpg');
    });

    test('uses the camera\'s own name for the photograph', () async {
      final subject = await photo();

      final name = await ExportService.nextFileName(
        folder: exports,
        photo: subject,
        ratio: CropRatio.xpan,
      );

      // The radical is how a photographer finds the original again, so it is
      // what the export is called — never a generated id.
      expect(name, startsWith('L1000001_'));
      expect(name, contains('65x24'));
      expect(name, isNot(contains(':')));
    });
  });

  group('straightening', () {
    test('exports the turned pixels, not the stored ones', () async {
      final subject = await photo();

      final level = await service.export(
        photo: subject,
        crop: CropRect.largestIn(
          frameAspect: 640 / 427,
          ratio: CropRatio.threeTwo,
        ),
        folder: exports,
      ) as ExportWritten;

      final straightened = await service.export(
        photo: subject,
        crop: CropRect.largestIn(
          frameAspect: 640 / 427,
          ratio: CropRatio.threeTwo,
          angleDegrees: 8,
        ),
        folder: exports,
      ) as ExportWritten;

      // Straightening costs pixels — the usable rectangle inside a turned frame
      // is smaller — and an export that came out the same size would mean the
      // angle had been recorded and then ignored.
      expect(straightened.pixelWidth, lessThan(level.pixelWidth));
      expect(straightened.pixelWidth, greaterThan(level.pixelWidth ~/ 2));
    });

    test('a straightened export keeps the ratio it was asked for', () async {
      final subject = await photo();

      final outcome = await service.export(
        photo: subject,
        crop: CropRect.largestIn(
          frameAspect: 640 / 427,
          ratio: CropRatio.square,
          angleDegrees: 6,
        ),
        folder: exports,
      ) as ExportWritten;

      expect(
        outcome.pixelWidth / outcome.pixelHeight,
        closeTo(1, 0.01),
      );
    });

    test('leaves no black corner in the exported picture', () async {
      final subject = await photo();

      final outcome = await service.export(
        photo: subject,
        crop: CropRect.largestIn(
          frameAspect: 640 / 427,
          ratio: CropRatio.threeTwo,
          angleDegrees: 10,
        ),
        folder: exports,
      ) as ExportWritten;

      final decoded = img.decodeJpg(File(outcome.path).readAsBytesSync())!;
      // The fixture is a colour ramp with no black anywhere, so any very dark
      // corner would be the empty wedge a turn leaves behind — the one failure
      // that makes straightening look broken rather than approximate.
      for (final corner in [
        (2, 2),
        (decoded.width - 3, 2),
        (2, decoded.height - 3),
        (decoded.width - 3, decoded.height - 3),
      ]) {
        final pixel = decoded.getPixel(corner.$1, corner.$2);
        expect(
          pixel.r + pixel.g + pixel.b,
          greaterThan(20),
          reason: 'corner ${corner.$1},${corner.$2} is empty',
        );
      }
    });

    /// Which way the picture turns, which no other test here could see.
    ///
    /// Every assertion above holds just as well for a rotation the wrong way
    /// round: the crop still shrinks, still keeps its ratio, still has no black
    /// corner. So an export that straightened *against* the preview — leaving a
    /// photograph twice as crooked as the one the user started with — passed
    /// the whole suite.
    ///
    /// The fixture's green channel rises with y, so on a frame turned clockwise
    /// — the direction `Transform.rotate` turns the preview for a positive
    /// angle — green falls from left to right along any row.
    for (final (angle, description) in [
      (10.0, 'clockwise'),
      (-10.0, 'anticlockwise'),
    ]) {
      test('a $description straightening turns the picture $description',
          () async {
        final subject = await photo();

        final outcome = await service.export(
          photo: subject,
          crop: CropRect.largestIn(
            frameAspect: 640 / 427,
            ratio: CropRatio.threeTwo,
            angleDegrees: angle,
          ),
          folder: exports,
        ) as ExportWritten;

        final decoded = img.decodeJpg(File(outcome.path).readAsBytesSync())!;
        final row = decoded.height ~/ 2;
        final left = decoded.getPixel(decoded.width ~/ 4, row).g;
        final right = decoded.getPixel(3 * decoded.width ~/ 4, row).g;

        expect(
          left,
          angle > 0 ? greaterThan(right) : lessThan(right),
          reason: 'a $angle° straightening turned the frame the other way, so '
              'the export disagrees with what the crop screen showed',
        );
      });
    }
  });
}
