import 'dart:io';
import 'dart:typed_data';

import '../infra/preview/tiff_fixture.dart';

/// Builds DCF trees on a temp disk, written with real forged DNG/JPEG bytes.
///
/// The catalog is tested against files a parser can actually read rather than
/// against empty placeholders: pairing, stable keys and preview ranges all come
/// out of the file's header, so a fixture of zero-byte files would exercise
/// almost none of the code that matters.
class FakeCard {
  FakeCard._(this.root);

  final Directory root;

  String get path => root.path;

  static Future<FakeCard> create() async {
    final root = await Directory.systemTemp.createTemp('obscura_fake_card');
    return FakeCard._(root);
  }

  /// Writes a photograph into [folder].
  ///
  /// [raw] and [jpeg] choose which files of the pair exist, so a DNG-only or
  /// orphan-JPG entity can be built as easily as a full pair.
  Future<void> addPhoto(
    String radical, {
    String folder = '100LEICA',
    bool raw = true,
    bool jpeg = true,
    String captureTime = syntheticDngDateTimeOriginal,
    String serial = syntheticDngSerial,

    /// Embeds real, decodable JPEG previews. Off by default because the catalog
    /// scan never decodes anything; the thumbnail pipeline's fixtures turn it on.
    bool decodable = false,
    bool fullPreviewTruncated = false,

    /// EXIF `Orientation` for the DNG. 6 is the portrait case that dominates a
    /// real card: roughly half the frames on the measured Q3 session.
    int? orientation,
  }) async {
    final dir = Directory('${root.path}/DCIM/$folder');
    await dir.create(recursive: true);

    if (raw) {
      final dng = buildSyntheticDng(
        dateTimeOriginal: captureTime,
        serialNumber: serial,
        decodable: decodable,
        fullPreviewTruncated: fullPreviewTruncated,
        orientation: orientation,
      );
      await File('${dir.path}/$radical.DNG').writeAsBytes(dng.bytes);
    }
    if (jpeg) {
      await File('${dir.path}/$radical.JPG').writeAsBytes(buildExifJpeg());
    }
  }

  /// Writes a file the catalog is not meant to model, such as video.
  Future<void> addUnsupportedFile(
    String name, {
    String folder = '100LEICA',
  }) async {
    final dir = Directory('${root.path}/DCIM/$folder');
    await dir.create(recursive: true);
    await File('${dir.path}/$name').writeAsBytes(Uint8List(64));
  }

  /// Writes a corrupt file under a valid DCF name.
  Future<void> addCorruptPhoto(
    String radical, {
    String folder = '100LEICA',
  }) async {
    final dir = Directory('${root.path}/DCIM/$folder');
    await dir.create(recursive: true);
    await File('${dir.path}/$radical.DNG')
        .writeAsBytes(Uint8List.fromList(List.filled(4096, 0x7F)));
  }

  /// Reproduces the camera's own bookkeeping folder, which sits beside `DCIM`
  /// on a real card and must never be catalogued or touched.
  Future<void> addCameraPrivateFolder() async {
    final dir = Directory('${root.path}/PRIVATE/TEMP');
    await dir.create(recursive: true);
    await File('${root.path}/PRIVATE/META_001.DAT').writeAsBytes(Uint8List(32));
    await File('${root.path}/PRIVATE/FASTLOAD.DAT').writeAsBytes(Uint8List(32));
    await File('${dir.path}/0d32ce30.CPC').writeAsBytes(Uint8List(16));
  }

  /// Plants the debris macOS leaves on any volume it touches.
  Future<void> addMacosDebris({String folder = '100LEICA'}) async {
    final dir = Directory('${root.path}/DCIM/$folder');
    await dir.create(recursive: true);
    await File('${dir.path}/.DS_Store').writeAsBytes(Uint8List(48));
    await File('${dir.path}/._L1000863.DNG').writeAsBytes(Uint8List(48));
  }

  /// Copies the whole tree to a second temp root, standing in for the same card
  /// mounted at a different point.
  Future<FakeCard> remountElsewhere() async {
    final other = await Directory.systemTemp.createTemp('obscura_remount');
    await for (final entry in root.list(recursive: true, followLinks: false)) {
      final relative = entry.path.substring(root.path.length + 1);
      final target = '${other.path}/$relative';
      if (entry is Directory) {
        await Directory(target).create(recursive: true);
      } else if (entry is File) {
        await Directory(target).parent.create(recursive: true);
        await entry.copy(target);
      }
    }
    return FakeCard._(other);
  }

  Future<void> dispose() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
