/// A byte-for-byte forger for TIFF-shaped fixtures.
///
/// No authentic Q3 DNG is available on this machine (see
/// `test/fixtures/README.md`), so the format knowledge the extractor is tested
/// against lives here instead: every offset, every inline-versus-out-of-line
/// decision and both byte orders are written out by hand.
library;

import 'dart:typed_data';

import 'package:obscura_pro/infra/preview/ifd_parser.dart' show TiffByteOrder;

// --- Field values -----------------------------------------------------------

/// A directory entry's value, with its layout size known before any offset is.
sealed class FieldValue {
  const FieldValue();

  int get tiffType;
  int get count;

  /// Bytes of the value, once every target's offset is known.
  Uint8List encode(TiffByteOrder order, Map<Object, int> offsets);

  int get byteLength => count * const [0, 1, 1, 2, 4, 8, 1, 1, 2, 4, 8, 4, 8][tiffType];
}

final class ShortField extends FieldValue {
  const ShortField(this.values);

  final List<int> values;

  @override
  int get tiffType => 3;
  @override
  int get count => values.length;
  @override
  Uint8List encode(TiffByteOrder order, Map<Object, int> offsets) =>
      _pack(values, 2, order);
}

final class LongField extends FieldValue {
  const LongField(this.values);

  final List<int> values;

  @override
  int get tiffType => 4;
  @override
  int get count => values.length;
  @override
  Uint8List encode(TiffByteOrder order, Map<Object, int> offsets) =>
      _pack(values, 4, order);
}

/// ASCII, NUL-terminated as the spec requires -- hence `count` one over the
/// string's length.
final class AsciiField extends FieldValue {
  const AsciiField(this.value);

  final String value;

  @override
  int get tiffType => 2;
  @override
  int get count => value.length + 1;
  @override
  Uint8List encode(TiffByteOrder order, Map<Object, int> offsets) =>
      Uint8List.fromList([...value.codeUnits, 0]);
}

final class RationalField extends FieldValue {
  const RationalField(this.values);

  final List<({int numerator, int denominator})> values;

  @override
  int get tiffType => 5;
  @override
  int get count => values.length;
  @override
  Uint8List encode(TiffByteOrder order, Map<Object, int> offsets) => _pack(
    [for (final v in values) ...[v.numerator, v.denominator]],
    4,
    order,
  );
}

/// A LONG field whose values are the resolved file offsets of other layout
/// items -- SubIFD lists, `JPEGInterchangeFormat`, `StripOffsets`.
final class PointerField extends FieldValue {
  const PointerField(this.targets);

  PointerField.to(Object target) : targets = [target];

  final List<Object> targets;

  @override
  int get tiffType => 4;
  @override
  int get count => targets.length;
  @override
  Uint8List encode(TiffByteOrder order, Map<Object, int> offsets) =>
      _pack([for (final t in targets) offsets[t]!], 4, order);
}

Uint8List _pack(List<int> values, int size, TiffByteOrder order) {
  final out = Uint8List(values.length * size);
  for (var i = 0; i < values.length; i++) {
    for (var b = 0; b < size; b++) {
      final shift = order == TiffByteOrder.littleEndian ? 8 * b : 8 * (size - 1 - b);
      out[i * size + b] = (values[i] >> shift) & 0xFF;
    }
  }
  return out;
}

// --- Layout items -----------------------------------------------------------

/// One image file directory. [next] forges the next-IFD chain and may point at
/// the spec itself, which is how the cyclic-chain fixture is made.
final class IfdSpec {
  IfdSpec(this.fields, {this.next});

  final Map<int, FieldValue> fields;
  IfdSpec? next;
}

/// An opaque run of bytes placed in the file: a JPEG stream, a raw strip.
final class BlobSpec {
  BlobSpec(this.bytes);

  final Uint8List bytes;

  int get length => bytes.length;
}

/// Assembles a TIFF from [layout], the items in the order they take in the
/// file. Every [IfdSpec] and [BlobSpec] referenced by a [PointerField] or by a
/// `next` chain must appear in [layout] exactly once.
Uint8List buildTiff({
  required IfdSpec ifd0,
  required List<Object> layout,
  TiffByteOrder order = TiffByteOrder.littleEndian,
}) {
  // Pass one: place every item, and every out-of-line value, at a fixed offset.
  final offsets = <Object, int>{};
  final valueOffsets = <IfdSpec, Map<int, int>>{};
  var cursor = 8; // the header occupies bytes 0..7

  for (final item in layout) {
    offsets[item] = cursor;
    if (item is BlobSpec) {
      cursor += item.length;
    } else if (item is IfdSpec) {
      final tags = item.fields.keys.toList()..sort();
      cursor += 2 + 12 * tags.length + 4;
      final placed = <int, int>{};
      for (final tag in tags) {
        final value = item.fields[tag]!;
        if (value.byteLength > 4) {
          // TIFF requires out-of-line values to start on an even boundary.
          if (cursor.isOdd) cursor++;
          placed[tag] = cursor;
          cursor += value.byteLength;
        }
      }
      valueOffsets[item] = placed;
    } else {
      throw ArgumentError('layout holds a ${item.runtimeType}');
    }
  }

  // Pass two: write, now that every pointer can be resolved.
  final out = Uint8List(cursor);
  out[0] = order == TiffByteOrder.littleEndian ? 0x49 : 0x4D;
  out[1] = out[0];
  out.setRange(2, 4, _pack([42], 2, order));
  out.setRange(4, 8, _pack([offsets[ifd0]!], 4, order));

  for (final item in layout) {
    final at = offsets[item]!;
    if (item is BlobSpec) {
      out.setRange(at, at + item.length, item.bytes);
      continue;
    }
    final ifd = item as IfdSpec;
    final tags = ifd.fields.keys.toList()..sort();
    out.setRange(at, at + 2, _pack([tags.length], 2, order));

    for (var i = 0; i < tags.length; i++) {
      final tag = tags[i];
      final value = ifd.fields[tag]!;
      final entry = at + 2 + i * 12;
      out.setRange(entry, entry + 2, _pack([tag], 2, order));
      out.setRange(entry + 2, entry + 4, _pack([value.tiffType], 2, order));
      out.setRange(entry + 4, entry + 8, _pack([value.count], 4, order));

      final encoded = value.encode(order, offsets);
      if (encoded.length <= 4) {
        // Short values sit left-justified in the entry's own value slot, in
        // both byte orders.
        out.setRange(entry + 8, entry + 8 + encoded.length, encoded);
      } else {
        final valueAt = valueOffsets[ifd]![tag]!;
        out.setRange(entry + 8, entry + 12, _pack([valueAt], 4, order));
        out.setRange(valueAt, valueAt + encoded.length, encoded);
      }
    }

    final nextAt = at + 2 + 12 * tags.length;
    final nextIfd = ifd.next;
    out.setRange(nextAt, nextAt + 4, _pack([nextIfd == null ? 0 : offsets[nextIfd]!], 4, order));
  }

  return out;
}

// --- JPEG streams -----------------------------------------------------------

/// A stand-in JPEG: real SOI/EOI framing around filler, which is all the
/// extractor can check without decoding.
Uint8List fakeJpeg({required int payloadBytes, int fill = 0x5A}) => Uint8List.fromList([
  0xFF, 0xD8,
  ...List<int>.filled(payloadBytes, fill),
  0xFF, 0xD9,
]);

/// Wraps [tiffBlock] into a JPEG's APP1 `Exif\0\0` segment and closes the file
/// with a token scan and EOI.
Uint8List buildExifJpeg({Uint8List? tiffBlock, int scanBytes = 96}) {
  final out = <int>[0xFF, 0xD8];
  if (tiffBlock != null) {
    final payloadLength = 6 + tiffBlock.length + 2; // "Exif\0\0" + block + length field
    if (payloadLength > 0xFFFF) {
      throw ArgumentError('APP1 payload of $payloadLength bytes exceeds the segment limit');
    }
    out.addAll([
      0xFF, 0xE1,
      (payloadLength >> 8) & 0xFF, payloadLength & 0xFF,
      0x45, 0x78, 0x69, 0x66, 0x00, 0x00,
      ...tiffBlock,
    ]);
  }
  out.addAll([0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00]);
  out.addAll(List<int>.filled(scanBytes, 0x11));
  out.addAll([0xFF, 0xD9]);
  return Uint8List.fromList(out);
}

/// File offset at which [buildExifJpeg] places the TIFF block: SOI, the APP1
/// marker, its length field and the `Exif\0\0` signature.
const int exifJpegTiffBase = 2 + 2 + 2 + 6;

// --- The synthetic Q3-shaped DNG -------------------------------------------

/// Where the body serial is written, so the extractor's two sources can each be
/// exercised on their own.
enum SerialSource { exifBodySerialNumber, dngCameraSerialNumber, none }

final class SyntheticDng {
  const SyntheticDng({
    required this.bytes,
    required this.thumbnailJpeg,
    required this.fullPreviewJpeg,
    required this.extraPreviewJpeg,
  });

  final Uint8List bytes;
  final Uint8List thumbnailJpeg;
  final Uint8List fullPreviewJpeg;
  final Uint8List? extraPreviewJpeg;
}

const String syntheticDngDateTimeOriginal = '2026:03:14 09:26:53';
const String syntheticDngSerial = '5301234';

/// A DNG-shaped TIFF laid out the way a real one is:
///
/// * IFD0 is the reduced-resolution thumbnail, stored as a single JPEG strip;
/// * SubIFD 0 is the raw CFA image, also `Compression 7`, which must *not* be
///   mistaken for a preview;
/// * SubIFD 1 is the full-size preview, stored via `JPEGInterchangeFormat`;
/// * the EXIF IFD carries `DateTimeOriginal` and, optionally, the body serial.
SyntheticDng buildSyntheticDng({
  TiffByteOrder order = TiffByteOrder.littleEndian,
  SerialSource serial = SerialSource.exifBodySerialNumber,
  bool cyclicIfdChain = false,
  bool fullPreviewBeyondEndOfFile = false,
  bool extraPreviewInIfd1 = false,
}) {
  final thumbnail = fakeJpeg(payloadBytes: 120, fill: 0x11);
  final rawImage = fakeJpeg(payloadBytes: 200, fill: 0x22);
  final fullPreview = fakeJpeg(payloadBytes: 400, fill: 0x33);
  final extraPreview = extraPreviewInIfd1 ? fakeJpeg(payloadBytes: 260, fill: 0x44) : null;

  final thumbnailBlob = BlobSpec(thumbnail);
  final rawBlob = BlobSpec(rawImage);
  final fullBlob = BlobSpec(fullPreview);
  final extraBlob = extraPreview == null ? null : BlobSpec(extraPreview);

  final exifIfd = IfdSpec({
    0x9003: const AsciiField(syntheticDngDateTimeOriginal),
    if (serial == SerialSource.exifBodySerialNumber)
      0xA431: const AsciiField(syntheticDngSerial),
  });

  final rawIfd = IfdSpec({
    0x00FE: const LongField([0]),
    0x0100: const LongField([8000]),
    0x0101: const LongField([6000]),
    0x0103: const ShortField([7]),
    0x0106: const ShortField([32803]), // CFA
    0x0111: PointerField.to(rawBlob),
    0x0117: LongField([rawImage.length]),
  });

  final previewIfd = IfdSpec({
    0x00FE: const LongField([1]),
    0x0100: const LongField([7808]),
    0x0101: const LongField([5202]),
    0x0201: fullPreviewBeyondEndOfFile
        ? const LongField([0x7FFFFF00])
        : PointerField.to(fullBlob),
    0x0202: LongField([fullPreview.length]),
  });

  final ifd1 = extraBlob == null
      ? null
      : IfdSpec({
          0x00FE: const LongField([1]),
          0x0100: const LongField([1600]),
          0x0101: const LongField([1066]),
          0x0103: const ShortField([7]),
          0x0106: const ShortField([6]),
          0x0111: PointerField.to(extraBlob),
          0x0117: LongField([extraPreview!.length]),
        });

  final ifd0 = IfdSpec({
    0x00FE: const LongField([1]),
    0x0100: const LongField([320]),
    0x0101: const LongField([213]),
    0x0103: const ShortField([7]),
    0x0106: const ShortField([6]), // YCbCr
    0x0111: PointerField.to(thumbnailBlob),
    0x0117: LongField([thumbnail.length]),
    0x011A: const RationalField([(numerator: 300, denominator: 1)]),
    0x014A: PointerField([rawIfd, previewIfd]),
    0x8769: PointerField.to(exifIfd),
    if (serial == SerialSource.dngCameraSerialNumber)
      0xC62F: const AsciiField(syntheticDngSerial),
  });

  if (cyclicIfdChain) {
    ifd0.next = ifd0;
  } else if (ifd1 != null) {
    ifd0.next = ifd1;
  }

  return SyntheticDng(
    bytes: buildTiff(
      ifd0: ifd0,
      order: order,
      layout: [
        ifd0,
        ?ifd1,
        rawIfd,
        previewIfd,
        exifIfd,
        thumbnailBlob,
        rawBlob,
        fullBlob,
        ?extraBlob,
      ],
    ),
    thumbnailJpeg: thumbnail,
    fullPreviewJpeg: fullPreview,
    extraPreviewJpeg: extraPreview,
  );
}

/// The EXIF TIFF block of a plain `.JPG`: IFD0 with the EXIF pointer, then IFD1
/// holding the embedded thumbnail.
Uint8List buildJpegExifBlock({
  required Uint8List? thumbnailJpeg,
  TiffByteOrder order = TiffByteOrder.littleEndian,
  bool thumbnailDimensions = true,
}) {
  final thumbBlob = thumbnailJpeg == null ? null : BlobSpec(thumbnailJpeg);

  final exifIfd = IfdSpec({
    0x9003: const AsciiField(syntheticDngDateTimeOriginal),
    0xA002: const LongField([7808]),
    0xA003: const LongField([5202]),
    0xA431: const AsciiField(syntheticDngSerial),
  });

  final ifd1 = thumbBlob == null
      ? null
      : IfdSpec({
          if (thumbnailDimensions) ...{
            0x0100: const LongField([160]),
            0x0101: const LongField([120]),
          },
          0x0103: const ShortField([6]),
          0x0201: PointerField.to(thumbBlob),
          0x0202: LongField([thumbnailJpeg!.length]),
        });

  final ifd0 = IfdSpec({0x8769: PointerField.to(exifIfd)}, next: ifd1);

  return buildTiff(
    ifd0: ifd0,
    order: order,
    layout: [ifd0, ?ifd1, exifIfd, ?thumbBlob],
  );
}
