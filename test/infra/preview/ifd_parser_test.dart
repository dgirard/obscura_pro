import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/infra/preview/ifd_parser.dart';

import 'tiff_fixture.dart';

/// Reader-level checks. The extractor tests cover the walk; these cover the
/// primitives it stands on -- byte order, inline versus out-of-line values, and
/// the two ways a read can fail.
void main() {
  test('accepts both byte-order markers and finds IFD0', () {
    for (final order in TiffByteOrder.values) {
      final ifd0 = IfdSpec({0x0100: const LongField([320])});
      final bytes = buildTiff(ifd0: ifd0, layout: [ifd0], order: order);

      final reader = TiffReader.open(bytes, fileLength: bytes.length);

      expect(reader.order, order);
      expect(reader.firstIfdOffset, 8);
      expect(reader.readIfd(8).intValue(0x0100), 320);
    }
  });

  test('rejects a non-TIFF header', () {
    expect(
      () => TiffReader.open(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0]), fileLength: 8),
      throwsA(
        isA<IfdMalformedException>().having((e) => e.kind, 'kind', IfdErrorKind.notTiff),
      ),
    );
  });

  test('rejects BigTIFF, whose 8-byte offsets this reader would misread', () {
    final bytes = Uint8List.fromList([0x49, 0x49, 43, 0, 8, 0, 0, 0]);

    expect(
      () => TiffReader.open(bytes, fileLength: bytes.length),
      throwsA(
        isA<IfdMalformedException>().having((e) => e.kind, 'kind', IfdErrorKind.notTiff),
      ),
    );
  });

  test('asks for more bytes when the header is not in the prefix yet', () {
    expect(
      () => TiffReader.open(Uint8List.fromList([0x49, 0x49, 42, 0]), fileLength: 4096),
      throwsA(
        isA<IfdPrefixTooShortException>().having((e) => e.requiredBytes, 'requiredBytes', 8),
      ),
    );
  });

  test('reads inline and out-of-line values in both byte orders', () {
    for (final order in TiffByteOrder.values) {
      final ifd0 = IfdSpec({
        0x0103: const ShortField([7]), // two bytes, inline
        0x0117: const LongField([1234567]), // four bytes, still inline
        0x011A: const RationalField([(numerator: 300, denominator: 1)]), // eight, out of line
        0x9003: const AsciiField('2026:03:14 09:26:53'), // twenty, out of line
      });
      final bytes = buildTiff(ifd0: ifd0, layout: [ifd0], order: order);

      final ifd = TiffReader.open(bytes, fileLength: bytes.length).readIfd(8);

      expect(ifd.intValue(0x0103), 7, reason: '$order');
      expect(ifd.intValue(0x0117), 1234567, reason: '$order');
      expect(ifd.field(0x011A)!.asRationals(), [(numerator: 300, denominator: 1)]);
      expect(ifd.field(0x9003)!.asAscii(), '2026:03:14 09:26:53');
    }
  });

  test('distinguishes a value outside the file from one outside the prefix', () {
    final ifd0 = IfdSpec({0x9003: const AsciiField('2026:03:14 09:26:53')});
    final bytes = buildTiff(ifd0: ifd0, layout: [ifd0]);

    // Present in the file, absent from the prefix: recoverable by reading more.
    final short = TiffReader.open(bytes.sublist(0, bytes.length - 4), fileLength: bytes.length);
    expect(
      () => short.readIfd(8).field(0x9003)!.asAscii(),
      throwsA(
        isA<IfdPrefixTooShortException>().having(
          (e) => e.requiredBytes,
          'requiredBytes',
          bytes.length,
        ),
      ),
    );

    // The same bytes described as the whole file: the value now points past the
    // end, which is corruption, not a short read.
    final truncated = bytes.sublist(0, bytes.length - 4);
    expect(
      () => TiffReader.open(truncated, fileLength: truncated.length).readIfd(8).field(0x9003)!.asAscii(),
      throwsA(
        isA<IfdMalformedException>().having((e) => e.kind, 'kind', IfdErrorKind.offsetOutOfRange),
      ),
    );
  });

  test('refuses to read a field as a type it does not hold', () {
    final ifd0 = IfdSpec({0x0100: const LongField([320])});
    final bytes = buildTiff(ifd0: ifd0, layout: [ifd0]);

    final field = TiffReader.open(bytes, fileLength: bytes.length).readIfd(8).field(0x0100)!;

    expect(
      field.asAscii,
      throwsA(
        isA<IfdMalformedException>().having(
          (e) => e.kind,
          'kind',
          IfdErrorKind.unsupportedFieldType,
        ),
      ),
    );
  });

  test('reports preview ranges that lie beyond the prefix but inside the file', () {
    final reader = TiffReader.open(
      Uint8List.fromList([0x49, 0x49, 42, 0, 8, 0, 0, 0]),
      fileLength: 90000000,
    );

    expect(reader.spansFile(60000000, 12000000), isTrue);
    expect(reader.spansFile(89000000, 12000000), isFalse);
    expect(reader.spansFile(-1, 10), isFalse);
    expect(reader.spansFile(10, 0), isFalse);
  });
}
