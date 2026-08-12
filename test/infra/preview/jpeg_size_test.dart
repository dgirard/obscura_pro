import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/infra/preview/jpeg_size.dart';

import 'tiff_fixture.dart';

/// Reading a JPEG's size without decoding it.
void main() {
  test('reads the size a real JPEG declares', () {
    expect(jpegPixelSize(realJpeg(width: 640, height: 480)), const Size(640, 480));
    expect(jpegPixelSize(realJpeg(width: 17, height: 9)), const Size(17, 9));
  });

  test('reads it from the header alone', () {
    // The frame marker is near the front; a caller that only holds the first
    // few kilobytes of a twelve-megabyte export still gets an answer.
    final whole = realJpeg(width: 1200, height: 800);
    final head = Uint8List.sublistView(whole, 0, 512);

    expect(jpegPixelSize(head), const Size(1200, 800));
  });

  test('says nothing rather than guessing', () {
    // Not a JPEG.
    expect(jpegPixelSize(Uint8List.fromList([0x00, 0x01, 0x02, 0x03])), isNull);
    expect(jpegPixelSize(Uint8List(0)), isNull);
    // A JPEG whose header is not in the slice given: truncated before the frame
    // marker, which is a file the caller must not put a size against.
    expect(
      jpegPixelSize(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
      isNull,
    );
  });
}
