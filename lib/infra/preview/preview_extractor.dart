import 'dart:typed_data';

import 'ifd_parser.dart';

/// How many bytes of each file the catalog scan reads to obtain, in one go, the
/// stable-key EXIF fields and every embedded preview's byte range.
///
/// PENDING MEASUREMENT: no authentic Leica Q3 DNG has been measured on this
/// machine, so this is a placeholder sized to comfortably cover IFD0, the
/// SubIFD chain and the EXIF IFD of a typical DNG -- not an observed figure.
/// See `test/fixtures/README.md`. Undersizing it is not a correctness risk:
/// [PreviewScanNeedsMoreBytes] names the exact prefix length to retry with.
const int kHeaderPrefixBytes = 256 * 1024;

/// Depth limit on SubIFD nesting.
///
/// The visited-offset set already stops cycles; this stops a deep but acyclic
/// forgery from recursing until the stack gives out.
const int _maxSubIfdDepth = 4;

/// TIFF/EXIF/DNG tags this extractor reads.
abstract final class PreviewTags {
  static const newSubfileType = 0x00FE;
  static const imageWidth = 0x0100;
  static const imageLength = 0x0101;
  static const compression = 0x0103;
  static const photometricInterpretation = 0x0106;
  static const stripOffsets = 0x0111;
  static const stripByteCounts = 0x0117;
  static const jpegInterchangeFormat = 0x0201;
  static const jpegInterchangeFormatLength = 0x0202;
  static const subIfds = 0x014A;
  static const exifIfdPointer = 0x8769;
  static const dateTimeOriginal = 0x9003;
  static const pixelXDimension = 0xA002;
  static const pixelYDimension = 0xA003;
  static const bodySerialNumber = 0xA431;

  /// DNG's own serial tag, present on files whose EXIF IFD omits
  /// [bodySerialNumber].
  static const cameraSerialNumber = 0xC62F;
}

const int _compressionJpeg = 7;
const int _photometricRgb = 2;
const int _photometricYCbCr = 6;

/// Where a preview's bytes came from. The caller needs this to know what it is
/// holding: everything but [wholeFile] is a stream it can hand to a decoder as
/// is, while [wholeFile] means no smaller variant existed and the grid must
/// downscale a full-size frame itself.
enum PreviewStreamKind { jpegInterchange, jpegStrips, exifThumbnail, wholeFile }

/// One embedded JPEG, located but not read.
///
/// [offset] is an absolute file offset, so a decode worker can seek straight to
/// it without re-parsing anything.
final class PreviewStream {
  const PreviewStream({
    required this.offset,
    required this.length,
    required this.kind,
    this.width,
    this.height,
    this.reducedResolution = false,
  });

  final int offset;
  final int length;
  final PreviewStreamKind kind;

  /// Pixel dimensions when the directory declared them. Absent is normal: some
  /// thumbnail IFDs omit them entirely.
  final int? width;
  final int? height;

  /// `NewSubfileType` bit 0 -- the directory calls itself a reduced-resolution
  /// version of another image in the same file.
  final bool reducedResolution;

  int? get pixelCount => (width == null || height == null) ? null : width! * height!;

  @override
  bool operator ==(Object other) =>
      other is PreviewStream &&
      other.offset == offset &&
      other.length == length &&
      other.kind == kind &&
      other.width == width &&
      other.height == height &&
      other.reducedResolution == reducedResolution;

  @override
  int get hashCode => Object.hash(offset, length, kind, width, height, reducedResolution);

  @override
  String toString() =>
      'PreviewStream(${kind.name}, $offset+$length, ${width ?? '?'}x${height ?? '?'}'
      '${reducedResolution ? ', reduced' : ''})';
}

/// Everything one bounded read of a photo's header yields.
final class PhotoHeader {
  const PhotoHeader({
    required this.previews,
    required this.dateTimeOriginal,
    required this.bodySerial,
  });

  /// Located preview streams in discovery order. May be empty: a DNG written
  /// without any embedded preview parses fine and simply offers nothing to
  /// display.
  final List<PreviewStream> previews;

  /// EXIF `DateTimeOriginal`. The camera records no timezone, so this is a
  /// wall-clock reading, not an instant. It is UTC-flagged only so its digits
  /// survive storage unshifted -- never convert it to local time.
  final DateTime? dateTimeOriginal;

  final String? bodySerial;

  /// Previews smallest first.
  ///
  /// Pixel count orders them when every stream declares its dimensions, byte
  /// length otherwise. The two are never mixed: comparing a megapixel figure
  /// against a byte figure would order the list by unit rather than by size.
  List<PreviewStream> get orderedBySize {
    final ordered = [...previews];
    final allSized = ordered.every((s) => s.pixelCount != null);
    ordered.sort(
      allSized
          ? (a, b) => a.pixelCount!.compareTo(b.pixelCount!)
          : (a, b) => a.length.compareTo(b.length),
    );
    return ordered;
  }

  PreviewStream? get gridPreview => previews.isEmpty ? null : orderedBySize.first;

  PreviewStream? get viewerPreview => previews.isEmpty ? null : orderedBySize.last;
}

/// Outcome of a bounded header scan.
sealed class PreviewScanResult {
  const PreviewScanResult();
}

final class PreviewScanSuccess extends PreviewScanResult {
  const PreviewScanSuccess(this.header);

  final PhotoHeader header;
}

/// The prefix stopped short of something the scan had to interpret.
///
/// Not an error: re-read the file's first [requiredBytes] bytes and scan again.
final class PreviewScanNeedsMoreBytes extends PreviewScanResult {
  const PreviewScanNeedsMoreBytes({required this.requiredBytes, required this.what});

  final int requiredBytes;
  final String what;

  @override
  String toString() => 'PreviewScanNeedsMoreBytes($requiredBytes for $what)';
}

final class PreviewScanFailure extends PreviewScanResult {
  const PreviewScanFailure(this.kind, this.message);

  final IfdErrorKind kind;
  final String message;

  @override
  String toString() => 'PreviewScanFailure(${kind.name}): $message';
}

/// Reads a photo's header out of [prefix], the first bytes of a file of
/// [fileLength] bytes.
///
/// Pass [fileLength] whenever [prefix] is a partial read: preview streams are
/// validated against the real file size, so a full-size preview sitting far
/// beyond the prefix is still reported. Omitting it treats [prefix] as the
/// whole file.
///
/// Never throws. A truncated, corrupt or foreign file comes back as a
/// [PreviewScanFailure].
PreviewScanResult scanPhotoHeader(Uint8List prefix, {int? fileLength}) {
  final total = (fileLength == null || fileLength < prefix.length) ? prefix.length : fileLength;
  try {
    if (prefix.length >= 2 && prefix[0] == 0xFF && prefix[1] == 0xD8) {
      return _scanJpeg(prefix, total);
    }
    return _scanTiff(prefix, total);
  } on IfdPrefixTooShortException catch (e) {
    return PreviewScanNeedsMoreBytes(requiredBytes: e.requiredBytes, what: e.what);
  } on IfdMalformedException catch (e) {
    return PreviewScanFailure(e.kind, e.message);
  } catch (e) {
    // A forged file must not be able to reach the caller as an exception, so
    // even a bug in this library degrades to an error tile.
    return PreviewScanFailure(IfdErrorKind.malformedStructure, 'unexpected parse error: $e');
  }
}

// --- DNG / TIFF -------------------------------------------------------------

PreviewScanResult _scanTiff(Uint8List prefix, int fileLength) {
  final reader = TiffReader.open(prefix, fileLength: fileLength);
  final collector = _Collector(reader);
  collector.walkChain(reader.firstIfdOffset, depth: 0);

  if (collector.streams.isEmpty && collector.rejectedCandidates > 0) {
    return PreviewScanFailure(
      IfdErrorKind.offsetOutOfRange,
      'every preview stream points outside the $fileLength-byte file',
    );
  }

  return PreviewScanSuccess(
    PhotoHeader(
      previews: collector.streams,
      dateTimeOriginal: collector.dateTimeOriginal,
      bodySerial: collector.bodySerial,
    ),
  );
}

/// Walks IFD0, its SubIFDs and the next-IFD chain, gathering previews and the
/// stable-key fields.
class _Collector {
  _Collector(this.reader);

  final TiffReader reader;
  final List<PreviewStream> streams = [];
  final Set<int> _visited = {};

  /// Preview candidates dropped because their byte range left the file. Counted
  /// so that "this DNG declares no preview" stays distinguishable from "this
  /// DNG's previews are corrupt".
  int rejectedCandidates = 0;

  DateTime? dateTimeOriginal;
  String? bodySerial;

  void walkChain(int firstOffset, {required int depth}) {
    var offset = firstOffset;
    while (offset != 0) {
      if (!_visited.add(offset)) {
        throw IfdMalformedException(
          IfdErrorKind.cyclicIfdChain,
          'IFD at $offset is reachable from itself',
        );
      }
      final ifd = reader.readIfd(offset, what: 'IFD at $offset');
      _collect(ifd);

      final subIfds = ifd.field(PreviewTags.subIfds);
      if (subIfds != null && depth < _maxSubIfdDepth) {
        for (final sub in subIfds.asInts()) {
          walkChain(sub, depth: depth + 1);
        }
      }

      offset = ifd.nextIfdOffset;
    }
  }

  void _collect(Ifd ifd) {
    _collectStableKeyFields(ifd);
    final stream = _previewIn(reader, ifd);
    if (stream == null) return;
    if (!reader.spansFile(stream.offset, stream.length)) {
      rejectedCandidates++;
      return;
    }
    streams.add(stream);
  }

  void _collectStableKeyFields(Ifd ifd) {
    // DNG puts the body serial in IFD0; EXIF puts it in the EXIF IFD. Either
    // satisfies the stable key, so whichever turns up first is kept.
    bodySerial ??= _readSerial(ifd, PreviewTags.cameraSerialNumber);

    final exifPointer = ifd.intValue(PreviewTags.exifIfdPointer);
    if (exifPointer == null || exifPointer == 0) return;
    if (!_visited.add(exifPointer)) return;

    final exif = reader.readIfd(exifPointer, what: 'EXIF IFD at $exifPointer');
    final raw = exif.field(PreviewTags.dateTimeOriginal);
    if (raw != null) dateTimeOriginal ??= parseExifDateTime(raw.asAscii());
    bodySerial ??= _readSerial(exif, PreviewTags.bodySerialNumber);
  }

  String? _readSerial(Ifd ifd, int tag) {
    final field = ifd.field(tag);
    if (field == null) return null;
    final value = field.asAscii();
    return value.isEmpty ? null : value;
  }
}

/// The one preview stream a directory describes, or null when it describes
/// something else -- most importantly the raw image itself, which is also
/// JPEG-compressed in a DNG and would otherwise be mistaken for a preview.
PreviewStream? _previewIn(TiffReader reader, Ifd ifd) {
  final width = ifd.intValue(PreviewTags.imageWidth);
  final height = ifd.intValue(PreviewTags.imageLength);
  final reduced = ((ifd.intValue(PreviewTags.newSubfileType) ?? 0) & 1) != 0;

  final jpegOffset = ifd.intValue(PreviewTags.jpegInterchangeFormat);
  final jpegLength = ifd.intValue(PreviewTags.jpegInterchangeFormatLength);
  if (jpegOffset != null && jpegLength != null && jpegLength > 0) {
    return PreviewStream(
      offset: reader.base + jpegOffset,
      length: jpegLength,
      kind: PreviewStreamKind.jpegInterchange,
      width: width,
      height: height,
      reducedResolution: reduced,
    );
  }

  if (ifd.intValue(PreviewTags.compression) != _compressionJpeg) return null;

  // Lossless-JPEG raw data carries Compression 7 as well; only the photometric
  // interpretation separates a displayable preview from a CFA mosaic that no
  // JPEG decoder can open.
  final photometric = ifd.intValue(PreviewTags.photometricInterpretation);
  if (photometric != _photometricRgb && photometric != _photometricYCbCr) return null;

  final offsets = ifd.field(PreviewTags.stripOffsets)?.asInts();
  final counts = ifd.field(PreviewTags.stripByteCounts)?.asInts();
  // A multi-strip image is several JPEG streams that only mean something
  // stitched together; there is no single byte range to hand a decoder.
  if (offsets == null || counts == null || offsets.length != 1 || counts.length != 1) {
    return null;
  }
  if (counts.first <= 0) return null;

  return PreviewStream(
    offset: reader.base + offsets.first,
    length: counts.first,
    kind: PreviewStreamKind.jpegStrips,
    width: width,
    height: height,
    reducedResolution: reduced,
  );
}

/// Parses EXIF's `YYYY:MM:DD HH:MM:SS`.
///
/// Returned UTC-flagged although the camera writes no timezone: the flag keeps
/// the wall-clock digits from being shifted on the way through storage. A value
/// that does not match the format yields null rather than failing the scan --
/// the stable key has a size+mtime fallback for exactly this.
DateTime? parseExifDateTime(String value) {
  final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})').firstMatch(value);
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  if (parts[1] < 1 || parts[1] > 12 || parts[2] < 1 || parts[2] > 31) return null;
  if (parts[3] > 23 || parts[4] > 59 || parts[5] > 59) return null;
  return DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
}

// --- Plain JPEG -------------------------------------------------------------

/// Locates the EXIF thumbnail of a plain `.JPG` and reports the file itself as
/// the full-size variant.
///
/// The thumbnail matters: a Q3 JPEG is a 39 Mpx frame, and decoding one per
/// grid cell would cost orders of magnitude more than reading the few kilobytes
/// its own EXIF already carries. JPG-only is a supported camera setting, so a
/// whole card can take this path.
PreviewScanResult _scanJpeg(Uint8List prefix, int fileLength) {
  final streams = <PreviewStream>[];
  DateTime? dateTimeOriginal;
  String? bodySerial;
  int? fullWidth;
  int? fullHeight;

  try {
    final tiffBase = _findExifTiffBlock(prefix, fileLength);
    if (tiffBase != null) {
      final reader = TiffReader.open(prefix, base: tiffBase, fileLength: fileLength);
      final ifd0 = reader.readIfd(reader.firstIfdOffset, what: 'EXIF IFD0');
      bodySerial = ifd0.field(PreviewTags.cameraSerialNumber)?.asAscii();
      fullWidth = ifd0.intValue(PreviewTags.imageWidth);
      fullHeight = ifd0.intValue(PreviewTags.imageLength);

      final exifPointer = ifd0.intValue(PreviewTags.exifIfdPointer);
      if (exifPointer != null && exifPointer != 0) {
        final exif = reader.readIfd(exifPointer, what: 'EXIF IFD');
        final raw = exif.field(PreviewTags.dateTimeOriginal);
        if (raw != null) dateTimeOriginal = parseExifDateTime(raw.asAscii());
        bodySerial ??= exif.field(PreviewTags.bodySerialNumber)?.asAscii();
        fullWidth = exif.intValue(PreviewTags.pixelXDimension) ?? fullWidth;
        fullHeight = exif.intValue(PreviewTags.pixelYDimension) ?? fullHeight;
      }

      // IFD1 -- the second directory of a JPEG's EXIF block -- is by definition
      // the embedded thumbnail.
      if (ifd0.nextIfdOffset != 0 && ifd0.nextIfdOffset != reader.firstIfdOffset) {
        final ifd1 = reader.readIfd(ifd0.nextIfdOffset, what: 'EXIF IFD1');
        final thumb = _previewIn(reader, ifd1);
        if (thumb != null && reader.spansFile(thumb.offset, thumb.length)) {
          streams.add(
            PreviewStream(
              offset: thumb.offset,
              length: thumb.length,
              kind: PreviewStreamKind.exifThumbnail,
              width: thumb.width,
              height: thumb.height,
              reducedResolution: true,
            ),
          );
        }
      }
    }
  } on IfdMalformedException {
    // Defined degradation: a JPEG with no EXIF, unreadable EXIF or no IFD1
    // thumbnail still yields exactly one stream -- the file itself -- so the
    // grid downscales a full frame instead of showing an error tile. The file
    // is decodable whatever its metadata says, and refusing it would hide a
    // perfectly good photograph. A prefix that is merely too short is not
    // caught here: that one is answered with PreviewScanNeedsMoreBytes.
  }

  streams.add(
    PreviewStream(
      offset: 0,
      length: fileLength,
      kind: PreviewStreamKind.wholeFile,
      width: fullWidth,
      height: fullHeight,
    ),
  );

  return PreviewScanSuccess(
    PhotoHeader(
      previews: streams,
      dateTimeOriginal: dateTimeOriginal,
      bodySerial: (bodySerial?.isEmpty ?? true) ? null : bodySerial,
    ),
  );
}

/// Absolute offset of the TIFF block inside the APP1 `Exif\0\0` segment, or
/// null when the file carries no such segment.
int? _findExifTiffBlock(Uint8List prefix, int fileLength) {
  int byteAt(int i, String what) {
    if (i >= fileLength) {
      throw IfdMalformedException(IfdErrorKind.malformedStructure, 'JPEG ends before $what');
    }
    if (i >= prefix.length) {
      throw IfdPrefixTooShortException(requiredBytes: i + 1, what: what);
    }
    return prefix[i];
  }

  // `cursor` strictly increases every iteration and byteAt throws past the end
  // of the file, so this terminates on any input.
  var cursor = 2;
  while (true) {
    if (byteAt(cursor, 'a JPEG marker') != 0xFF) return null;

    var markerAt = cursor + 1;
    while (byteAt(markerAt, 'a JPEG marker') == 0xFF) {
      markerAt++;
    }
    final marker = byteAt(markerAt, 'a JPEG marker');

    // SOS starts entropy-coded data and EOI ends the image: no further headers
    // follow either, so an EXIF segment that has not appeared by now does not
    // exist.
    if (marker == 0xDA || marker == 0xD9) return null;

    // Standalone markers carry no length field.
    if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      cursor = markerAt + 1;
      continue;
    }

    final segmentLength =
        (byteAt(markerAt + 1, 'a JPEG segment length') << 8) |
        byteAt(markerAt + 2, 'a JPEG segment length');
    if (segmentLength < 2) {
      throw const IfdMalformedException(
        IfdErrorKind.malformedStructure,
        'JPEG segment declares a length below its own length field',
      );
    }
    final dataStart = markerAt + 3;
    final dataLength = segmentLength - 2;

    if (marker == 0xE1 && dataLength >= 6) {
      const signature = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"
      var matches = true;
      for (var i = 0; i < signature.length; i++) {
        if (byteAt(dataStart + i, 'the APP1 EXIF signature') != signature[i]) {
          matches = false;
          break;
        }
      }
      if (matches) return dataStart + signature.length;
    }

    cursor = dataStart + dataLength;
  }
}
