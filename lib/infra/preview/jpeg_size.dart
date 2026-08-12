import 'dart:typed_data';
import 'dart:ui' show Size;

/// The pixel size a JPEG declares, read from its header.
///
/// Header only: the frame marker sits within the first few kilobytes of any
/// file this app or a camera writes, and decoding a 39 Mpx export to find out
/// how large it is would cost tens of megabytes per row of a list.
///
/// Returns null when the bytes are not a JPEG, or when the marker is not in the
/// slice given — both of which the caller has to be able to say nothing about
/// rather than guess at.
Size? jpegPixelSize(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;

  var offset = 2;
  while (offset + 3 < bytes.length) {
    if (bytes[offset] != 0xFF) {
      offset++;
      continue;
    }
    final marker = bytes[offset + 1];

    // Standalone markers carry no length.
    if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      offset += 2;
      continue;
    }
    // The scan begins; everything after it is entropy-coded data, and any
    // frame header worth reading has already gone past.
    if (marker == 0xDA || marker == 0xD9) return null;

    final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
    if (length < 2) return null;

    // SOF0..SOF15, except the four that are not frame headers: DHT (C4),
    // JPG (C8) and DAC (CC).
    final isFrame = marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isFrame) {
      if (offset + 9 >= bytes.length) return null;
      final height = (bytes[offset + 5] << 8) | bytes[offset + 6];
      final width = (bytes[offset + 7] << 8) | bytes[offset + 8];
      if (width <= 0 || height <= 0) return null;
      return Size(width.toDouble(), height.toDouble());
    }

    offset += 2 + length;
  }
  return null;
}
