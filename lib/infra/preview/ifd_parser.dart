import 'dart:typed_data';

/// Byte order declared by the first two bytes of a TIFF header (`II` / `MM`).
///
/// Both occur in the wild; a DNG writer is free to pick either, so nothing in
/// this library may assume little-endian.
enum TiffByteOrder { littleEndian, bigEndian }

/// Why a TIFF structure could not be read.
///
/// The grid renders an error tile per failing photo and must still be able to
/// delete it, so every one of these is a value the pipeline carries, never a
/// thrown error that escapes.
enum IfdErrorKind {
  notTiff,
  malformedStructure,
  offsetOutOfRange,
  cyclicIfdChain,
  unsupportedFieldType,
}

/// Raised while walking a TIFF structure.
///
/// These stay inside this library and `preview_extractor.dart`, which converts
/// them into result values at its API boundary.
sealed class IfdParseException implements Exception {
  const IfdParseException();
}

final class IfdMalformedException extends IfdParseException {
  const IfdMalformedException(this.kind, this.message);

  final IfdErrorKind kind;
  final String message;

  @override
  String toString() => 'IfdMalformedException(${kind.name}): $message';
}

/// The bytes needed are inside the file but outside the prefix that was read.
///
/// Separate from [IfdMalformedException] because the caller's remedy differs:
/// re-read the file with [requiredBytes] bytes rather than mark the photo
/// unreadable.
final class IfdPrefixTooShortException extends IfdParseException {
  const IfdPrefixTooShortException({required this.requiredBytes, required this.what});

  /// Total prefix length that would have covered the read, counted from the
  /// start of the file so a caller can pass it straight to its next read.
  final int requiredBytes;

  final String what;

  @override
  String toString() => 'IfdPrefixTooShortException: $what needs the first $requiredBytes bytes';
}

/// Element size per TIFF field type, indexed by type code.
///
/// A zero marks a code this reader does not interpret. TIFF requires readers to
/// skip unknown field types rather than reject the file, so such fields are
/// dropped on the floor instead of failing the parse.
const List<int> _typeSizes = <int>[0, 1, 1, 2, 4, 8, 1, 1, 2, 4, 8, 4, 8];

const int _typeAscii = 2;
const int _typeRational = 5;
const int _typeSRational = 10;

/// Reads TIFF directories out of a byte prefix of a file.
///
/// Two lengths matter and they are not the same: [bytes] is what has been read,
/// [fileLength] is how big the file is. Offsets are validated against
/// [fileLength], so a preview stream lying megabytes past the prefix is still
/// reported as a valid byte range; only bytes this reader must *interpret* have
/// to be present in [bytes].
final class TiffReader {
  TiffReader._({
    required this.bytes,
    required this.order,
    required this.base,
    required this.fileLength,
    required this.firstIfdOffset,
  });

  /// The prefix that was read. Never assume it is the whole file.
  final Uint8List bytes;

  final TiffByteOrder order;

  /// Offset of the TIFF header within the file: 0 for a DNG, the start of the
  /// APP1 payload's TIFF block for a JPEG. Every offset stored inside a TIFF is
  /// relative to this, so callers converting to file offsets must add it.
  final int base;

  final int fileLength;

  /// TIFF-relative offset of IFD0.
  final int firstIfdOffset;

  /// Parses the 8-byte TIFF header at [base].
  ///
  /// Throws [IfdMalformedException] with [IfdErrorKind.notTiff] when the byte
  /// order marker or the magic number does not match, and
  /// [IfdPrefixTooShortException] when the header is not in the prefix yet.
  static TiffReader open(Uint8List bytes, {int base = 0, required int fileLength}) {
    // A caller that read the whole file may pass no length at all; a caller
    // that passes a smaller one is describing something impossible.
    final total = fileLength < bytes.length ? bytes.length : fileLength;

    if (base < 0 || base + 8 > total) {
      throw const IfdMalformedException(
        IfdErrorKind.notTiff,
        'file is too short to hold a TIFF header',
      );
    }
    if (base + 8 > bytes.length) {
      throw IfdPrefixTooShortException(requiredBytes: base + 8, what: 'TIFF header');
    }

    final TiffByteOrder order;
    if (bytes[base] == 0x49 && bytes[base + 1] == 0x49) {
      order = TiffByteOrder.littleEndian;
    } else if (bytes[base] == 0x4D && bytes[base + 1] == 0x4D) {
      order = TiffByteOrder.bigEndian;
    } else {
      throw const IfdMalformedException(
        IfdErrorKind.notTiff,
        'missing II/MM byte-order marker',
      );
    }

    // 42 only. BigTIFF's 43 uses 8-byte offsets and a different directory
    // layout, so accepting it here would misread every offset.
    final magic = _u16(bytes, base + 2, order);
    if (magic != 42) {
      throw IfdMalformedException(
        IfdErrorKind.notTiff,
        'TIFF magic is $magic, expected 42',
      );
    }

    return TiffReader._(
      bytes: bytes,
      order: order,
      base: base,
      fileLength: total,
      firstIfdOffset: _u32(bytes, base + 4, order),
    );
  }

  /// Reads the directory at [tiffOffset] (TIFF-relative).
  Ifd readIfd(int tiffOffset, {String what = 'IFD'}) {
    final start = base + tiffOffset;
    require(start, 2, '$what entry count');
    final entryCount = _u16(bytes, start, order);

    // The whole directory -- entries plus the trailing next-IFD pointer -- is
    // demanded up front: a directory half inside the prefix cannot be walked,
    // and saying so once is clearer than failing on an arbitrary entry.
    final directorySize = 2 + entryCount * 12 + 4;
    require(start, directorySize, what);

    final fields = <int, IfdField>{};
    for (var i = 0; i < entryCount; i++) {
      final entry = start + 2 + i * 12;
      final tag = _u16(bytes, entry, order);
      final type = _u16(bytes, entry + 2, order);
      final count = _u32(bytes, entry + 4, order);

      final elementSize = type < _typeSizes.length ? _typeSizes[type] : 0;
      if (elementSize == 0) continue;

      // Values of four bytes or fewer sit in the entry's own value slot; longer
      // ones are stored elsewhere and the slot holds their offset. The bytes at
      // that offset are not demanded here -- most fields are never read, and
      // requiring them would enlarge the prefix for nothing.
      final byteLength = elementSize * count;
      final valueStart = byteLength <= 4 ? entry + 8 : base + _u32(bytes, entry + 8, order);

      fields[tag] = IfdField._(
        this,
        tag: tag,
        type: type,
        count: count,
        valueStart: valueStart,
        byteLength: byteLength,
      );
    }

    return Ifd._(
      fields: fields,
      nextIfdOffset: _u32(bytes, start + 2 + entryCount * 12, order),
    );
  }

  /// Asserts that [length] bytes at absolute offset [absoluteOffset] are both
  /// inside the file and inside the prefix, distinguishing the two failures.
  void require(int absoluteOffset, int length, String what) {
    if (absoluteOffset < 0 || length < 0 || absoluteOffset > fileLength - length) {
      throw IfdMalformedException(
        IfdErrorKind.offsetOutOfRange,
        '$what spans $absoluteOffset..${absoluteOffset + length} outside the $fileLength-byte file',
      );
    }
    if (absoluteOffset + length > bytes.length) {
      throw IfdPrefixTooShortException(requiredBytes: absoluteOffset + length, what: what);
    }
  }

  /// Whether [length] bytes at [absoluteOffset] lie inside the file. Used for
  /// preview streams, whose bytes are deliberately not read here.
  bool spansFile(int absoluteOffset, int length) =>
      absoluteOffset >= 0 && length > 0 && absoluteOffset <= fileLength - length;

  int u16(int absoluteOffset) => _u16(bytes, absoluteOffset, order);

  int u32(int absoluteOffset) => _u32(bytes, absoluteOffset, order);

  static int _u16(Uint8List b, int i, TiffByteOrder order) => order == TiffByteOrder.littleEndian
      ? b[i] | (b[i + 1] << 8)
      : (b[i] << 8) | b[i + 1];

  static int _u32(Uint8List b, int i, TiffByteOrder order) => order == TiffByteOrder.littleEndian
      ? b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24)
      : (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
}

/// One image file directory: its fields by tag, plus the chain pointer.
final class Ifd {
  const Ifd._({required this.fields, required this.nextIfdOffset});

  final Map<int, IfdField> fields;

  /// TIFF-relative offset of the next IFD, or 0 at the end of the chain.
  final int nextIfdOffset;

  IfdField? field(int tag) => fields[tag];

  /// First value of [tag] as an integer, or null when the tag is absent.
  int? intValue(int tag) {
    final values = fields[tag]?.asInts();
    return (values == null || values.isEmpty) ? null : values.first;
  }
}

/// One directory entry, with its value still unread.
///
/// Values are read on demand: the entry itself is always in the prefix, its
/// out-of-line value may not be, and only the handful of tags this app cares
/// about should be able to force a longer read.
final class IfdField {
  const IfdField._(
    this._reader, {
    required this.tag,
    required this.type,
    required this.count,
    required this.valueStart,
    required this.byteLength,
  });

  final TiffReader _reader;
  final int tag;
  final int type;
  final int count;

  /// Absolute file offset of the first value byte.
  final int valueStart;

  final int byteLength;

  /// Integer values, for BYTE, SHORT, LONG, SLONG and UNDEFINED fields.
  ///
  /// Throws [IfdMalformedException] for a type that carries no integer, rather
  /// than silently returning nothing: a preview offset stored as a RATIONAL is
  /// a broken file, not an absent tag.
  List<int> asInts() {
    _reader.require(valueStart, byteLength, 'tag 0x${tag.toRadixString(16)}');
    final b = _reader.bytes;
    switch (type) {
      case 1: // BYTE
      case 7: // UNDEFINED
        return List<int>.generate(count, (i) => b[valueStart + i]);
      case 3: // SHORT
        return List<int>.generate(count, (i) => _reader.u16(valueStart + i * 2));
      case 4: // LONG
        return List<int>.generate(count, (i) => _reader.u32(valueStart + i * 4));
      case 9: // SLONG
        return List<int>.generate(count, (i) {
          final v = _reader.u32(valueStart + i * 4);
          return v >= 0x80000000 ? v - 0x100000000 : v;
        });
      default:
        throw IfdMalformedException(
          IfdErrorKind.unsupportedFieldType,
          'tag 0x${tag.toRadixString(16)} has non-integer type $type',
        );
    }
  }

  /// ASCII value with its terminating NUL and any trailing padding removed.
  String asAscii() {
    if (type != _typeAscii) {
      throw IfdMalformedException(
        IfdErrorKind.unsupportedFieldType,
        'tag 0x${tag.toRadixString(16)} has type $type, expected ASCII',
      );
    }
    _reader.require(valueStart, byteLength, 'tag 0x${tag.toRadixString(16)}');
    final b = _reader.bytes;
    final buffer = StringBuffer();
    for (var i = 0; i < count; i++) {
      final c = b[valueStart + i];
      if (c == 0) break;
      buffer.writeCharCode(c);
    }
    return buffer.toString().trim();
  }

  /// RATIONAL / SRATIONAL values as numerator/denominator pairs.
  ///
  /// Kept as pairs rather than divided: a zero denominator is legal in EXIF for
  /// "unknown", and collapsing it to a double would turn that into a NaN the
  /// caller cannot distinguish from a real value.
  List<({int numerator, int denominator})> asRationals() {
    if (type != _typeRational && type != _typeSRational) {
      throw IfdMalformedException(
        IfdErrorKind.unsupportedFieldType,
        'tag 0x${tag.toRadixString(16)} has type $type, expected RATIONAL',
      );
    }
    _reader.require(valueStart, byteLength, 'tag 0x${tag.toRadixString(16)}');
    return List.generate(count, (i) {
      var numerator = _reader.u32(valueStart + i * 8);
      var denominator = _reader.u32(valueStart + i * 8 + 4);
      if (type == _typeSRational) {
        if (numerator >= 0x80000000) numerator -= 0x100000000;
        if (denominator >= 0x80000000) denominator -= 0x100000000;
      }
      return (numerator: numerator, denominator: denominator);
    });
  }
}
