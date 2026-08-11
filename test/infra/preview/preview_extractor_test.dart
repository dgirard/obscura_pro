import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/infra/preview/ifd_parser.dart';
import 'package:obscura_pro/infra/preview/preview_extractor.dart';

import 'tiff_fixture.dart';

/// Extraction is the load-bearing mechanism of the product, and no authentic Q3
/// DNG is available here, so every fixture below is forged byte-for-byte by
/// `tiff_fixture.dart`.
void main() {
  PhotoHeader headerOf(PreviewScanResult result) {
    expect(result, isA<PreviewScanSuccess>(), reason: '$result');
    return (result as PreviewScanSuccess).header;
  }

  void expectJpegFraming(Uint8List file, PreviewStream stream) {
    expect(stream.offset + stream.length, lessThanOrEqualTo(file.length));
    final bytes = file.sublist(stream.offset, stream.offset + stream.length);
    expect([bytes[0], bytes[1]], [0xFF, 0xD8], reason: 'SOI at ${stream.offset}');
    expect(
      [bytes[bytes.length - 2], bytes[bytes.length - 1]],
      [0xFF, 0xD9],
      reason: 'EOI at ${stream.offset + stream.length}',
    );
  }

  group('synthetic DNG', () {
    test('reports both embedded previews, each framed as a JPEG', () {
      final dng = buildSyntheticDng();
      final header = headerOf(scanPhotoHeader(dng.bytes));

      expect(header.previews.length, greaterThanOrEqualTo(2));
      for (final stream in header.previews) {
        expectJpegFraming(dng.bytes, stream);
      }

      final grid = header.gridPreview!;
      final viewer = header.viewerPreview!;
      expect(grid.width, 320);
      expect(grid.height, 213);
      expect(grid.kind, PreviewStreamKind.jpegStrips);
      expect(grid.reducedResolution, isTrue, reason: 'NewSubfileType bit 0');
      expect(dng.bytes.sublist(grid.offset, grid.offset + grid.length), dng.thumbnailJpeg);

      expect(viewer.width, 7808);
      expect(viewer.height, 5202);
      expect(viewer.kind, PreviewStreamKind.jpegInterchange);
      expect(dng.bytes.sublist(viewer.offset, viewer.offset + viewer.length), dng.fullPreviewJpeg);
    });

    test('does not mistake the JPEG-compressed raw image for a preview', () {
      final header = headerOf(scanPhotoHeader(buildSyntheticDng().bytes));

      // The fixture holds three JPEG-compressed directories; the CFA one is not
      // decodable as a JPEG frame and must be left out.
      expect(header.previews.length, 2);
    });

    test('walks IFD1 as well as IFD0 and the SubIFDs', () {
      final dng = buildSyntheticDng(extraPreviewInIfd1: true);
      final header = headerOf(scanPhotoHeader(dng.bytes));

      expect(header.previews.length, 3);
      final middle = header.orderedBySize[1];
      expect(middle.width, 1600);
      expect(dng.bytes.sublist(middle.offset, middle.offset + middle.length), dng.extraPreviewJpeg);
    });

    test('reads the stable-key fields, DateTimeOriginal as a naive value', () {
      final header = headerOf(scanPhotoHeader(buildSyntheticDng().bytes));

      expect(header.dateTimeOriginal, DateTime.utc(2026, 3, 14, 9, 26, 53));
      expect(header.bodySerial, syntheticDngSerial);
    });

    test('falls back to DNG CameraSerialNumber when EXIF carries no serial', () {
      final header = headerOf(
        scanPhotoHeader(buildSyntheticDng(serial: SerialSource.dngCameraSerialNumber).bytes),
      );

      expect(header.bodySerial, syntheticDngSerial);
    });

    test('reports no serial rather than an empty one when neither tag is present', () {
      final header = headerOf(
        scanPhotoHeader(buildSyntheticDng(serial: SerialSource.none).bytes),
      );

      expect(header.bodySerial, isNull);
      expect(header.dateTimeOriginal, isNotNull);
    });

    test('big-endian and little-endian files parse to the same result', () {
      final little = buildSyntheticDng(order: TiffByteOrder.littleEndian);
      final big = buildSyntheticDng(order: TiffByteOrder.bigEndian);
      expect(little.bytes.length, big.bytes.length);

      final fromLittle = headerOf(scanPhotoHeader(little.bytes));
      final fromBig = headerOf(scanPhotoHeader(big.bytes));

      expect(fromBig.previews, fromLittle.previews);
      expect(fromBig.dateTimeOriginal, fromLittle.dateTimeOriginal);
      expect(fromBig.bodySerial, fromLittle.bodySerial);
    });
  });

  group('malformed files', () {
    test('a truncated DNG returns a typed error', () {
      final truncated = buildSyntheticDng().bytes.sublist(0, 40);

      final result = scanPhotoHeader(truncated);

      expect(result, isA<PreviewScanFailure>());
      expect((result as PreviewScanFailure).kind, IfdErrorKind.offsetOutOfRange);
    });

    test('a garbage header returns a typed error', () {
      final result = scanPhotoHeader(Uint8List.fromList(List<int>.filled(512, 0x7B)));

      expect(result, isA<PreviewScanFailure>());
      expect((result as PreviewScanFailure).kind, IfdErrorKind.notTiff);
    });

    test('an IFD chain pointing at itself returns a typed error instead of looping', () {
      final result = scanPhotoHeader(buildSyntheticDng(cyclicIfdChain: true).bytes);

      expect(result, isA<PreviewScanFailure>());
      expect((result as PreviewScanFailure).kind, IfdErrorKind.cyclicIfdChain);
    });

    test('a preview offset past the end of the file is dropped, not read', () {
      final dng = buildSyntheticDng(fullPreviewBeyondEndOfFile: true);

      final header = headerOf(scanPhotoHeader(dng.bytes));

      expect(header.previews.length, 1);
      expectJpegFraming(dng.bytes, header.previews.single);
    });

    test('a file whose only preview is out of range fails rather than looking empty', () {
      final ifd0 = IfdSpec({
        0x0100: const LongField([320]),
        0x0101: const LongField([213]),
        0x0201: const LongField([0x7FFFFF00]),
        0x0202: const LongField([4096]),
      });
      final bytes = buildTiff(ifd0: ifd0, layout: [ifd0]);

      final result = scanPhotoHeader(bytes);

      expect(result, isA<PreviewScanFailure>());
      expect((result as PreviewScanFailure).kind, IfdErrorKind.offsetOutOfRange);
    });

    test('a multi-strip JPEG image is not offered as a single stream', () {
      final strips = BlobSpec(fakeJpeg(payloadBytes: 64));
      final ifd0 = IfdSpec({
        0x0103: const ShortField([7]),
        0x0106: const ShortField([6]),
        0x0111: PointerField([strips, strips]),
        0x0117: const LongField([34, 34]),
      });
      final bytes = buildTiff(ifd0: ifd0, layout: [ifd0, strips]);

      final header = headerOf(scanPhotoHeader(bytes));

      expect(header.previews, isEmpty);
    });

    test('no exception escapes for corrupted or truncated variants', () {
      final sources = [
        buildSyntheticDng().bytes,
        buildExifJpeg(
          tiffBlock: buildJpegExifBlock(thumbnailJpeg: fakeJpeg(payloadBytes: 90)),
        ),
      ];
      final random = Random(7);

      for (final source in sources) {
        for (var i = 0; i < 400; i++) {
          final mutated = Uint8List.fromList(source.sublist(0, 1 + random.nextInt(source.length)));
          for (var k = 0; k < 6; k++) {
            mutated[random.nextInt(mutated.length)] = random.nextInt(256);
          }
          expect(
            () => scanPhotoHeader(mutated, fileLength: source.length),
            returnsNormally,
            reason: 'mutation $i of ${mutated.length} bytes',
          );
        }
      }
    });
  });

  group('bounded prefix', () {
    test('names the byte count to retry with, and converges on the full result', () {
      final dng = buildSyntheticDng();
      final full = headerOf(scanPhotoHeader(dng.bytes));

      var prefixLength = 16;
      var rounds = 0;
      PreviewScanResult result;
      while (true) {
        result = scanPhotoHeader(
          dng.bytes.sublist(0, prefixLength),
          fileLength: dng.bytes.length,
        );
        if (result is! PreviewScanNeedsMoreBytes) break;
        expect(result.requiredBytes, greaterThan(prefixLength));
        prefixLength = result.requiredBytes;
        expect(++rounds, lessThan(12), reason: 'prefix growth should converge quickly');
      }

      expect(rounds, greaterThan(0), reason: 'a 16-byte prefix cannot resolve anything');
      // The full-size preview lives past the prefix and is still reported: only
      // bytes that must be *interpreted* have to be read.
      expect(prefixLength, lessThan(dng.bytes.length));
      expect(headerOf(result).previews, full.previews);
      expect(headerOf(result).dateTimeOriginal, full.dateTimeOriginal);
    });

    test('every prefix length either asks for more bytes or succeeds', () {
      final dng = buildSyntheticDng();
      final reasons = <String>{};

      for (var n = 0; n <= dng.bytes.length; n++) {
        final result = scanPhotoHeader(dng.bytes.sublist(0, n), fileLength: dng.bytes.length);
        expect(result, isNot(isA<PreviewScanFailure>()), reason: 'prefix of $n bytes: $result');
        if (result is PreviewScanNeedsMoreBytes) reasons.add(result.what);
      }

      // A prefix that stops inside an out-of-line ASCII value must say so
      // against that tag, not fail the photo.
      expect(reasons, contains(contains('0x9003')));
    });
  });

  group('plain JPEG', () {
    test('yields its EXIF thumbnail as the grid variant and itself as the full one', () {
      final thumbnail = fakeJpeg(payloadBytes: 180, fill: 0x77);
      final file = buildExifJpeg(tiffBlock: buildJpegExifBlock(thumbnailJpeg: thumbnail));

      final header = headerOf(scanPhotoHeader(file));

      expect(header.previews.length, 2);
      final grid = header.gridPreview!;
      expect(grid.kind, PreviewStreamKind.exifThumbnail);
      expect(grid.width, 160);
      expect(file.sublist(grid.offset, grid.offset + grid.length), thumbnail);
      expectJpegFraming(file, grid);

      final viewer = header.viewerPreview!;
      expect(viewer.kind, PreviewStreamKind.wholeFile);
      expect(viewer.offset, 0);
      expect(viewer.length, file.length);
      expect(viewer.width, 7808);
      expect(viewer.reducedResolution, isFalse);

      expect(header.dateTimeOriginal, DateTime.utc(2026, 3, 14, 9, 26, 53));
      expect(header.bodySerial, syntheticDngSerial);
    });

    test('orders by byte length when the thumbnail declares no dimensions', () {
      final thumbnail = fakeJpeg(payloadBytes: 180, fill: 0x77);
      final file = buildExifJpeg(
        tiffBlock: buildJpegExifBlock(thumbnailJpeg: thumbnail, thumbnailDimensions: false),
      );

      final header = headerOf(scanPhotoHeader(file));

      expect(header.gridPreview!.kind, PreviewStreamKind.exifThumbnail);
      expect(header.viewerPreview!.kind, PreviewStreamKind.wholeFile);
    });

    test('degrades to the file itself when EXIF holds no thumbnail', () {
      final file = buildExifJpeg(tiffBlock: buildJpegExifBlock(thumbnailJpeg: null));

      final header = headerOf(scanPhotoHeader(file));

      expect(header.previews.single.kind, PreviewStreamKind.wholeFile);
      expect(header.previews.single.length, file.length);
      expect(header.dateTimeOriginal, isNotNull);
    });

    test('degrades to the file itself when there is no EXIF segment at all', () {
      final file = buildExifJpeg();

      final header = headerOf(scanPhotoHeader(file));

      expect(header.previews.single.kind, PreviewStreamKind.wholeFile);
      expect(header.dateTimeOriginal, isNull);
      expect(header.bodySerial, isNull);
    });

    test('degrades to the file itself when the EXIF block is corrupt', () {
      final file = buildExifJpeg(
        tiffBlock: Uint8List.fromList(List<int>.filled(48, 0xAB)),
      );

      final header = headerOf(scanPhotoHeader(file));

      expect(header.previews.single.kind, PreviewStreamKind.wholeFile);
    });

    test('big-endian EXIF in a JPEG parses to the same thumbnail', () {
      final thumbnail = fakeJpeg(payloadBytes: 180, fill: 0x77);
      final little = buildExifJpeg(tiffBlock: buildJpegExifBlock(thumbnailJpeg: thumbnail));
      final big = buildExifJpeg(
        tiffBlock: buildJpegExifBlock(
          thumbnailJpeg: thumbnail,
          order: TiffByteOrder.bigEndian,
        ),
      );

      expect(headerOf(scanPhotoHeader(big)).previews, headerOf(scanPhotoHeader(little)).previews);
    });
  });

  group('EXIF timestamps', () {
    test('parses the camera format and rejects anything else', () {
      expect(parseExifDateTime('2026:03:14 09:26:53'), DateTime.utc(2026, 3, 14, 9, 26, 53));
      expect(parseExifDateTime('    :  :     :  :  '), isNull);
      expect(parseExifDateTime('2026:13:14 09:26:53'), isNull);
      expect(parseExifDateTime(''), isNull);
    });
  });
}
