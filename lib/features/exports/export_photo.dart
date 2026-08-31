import 'dart:io';

import 'package:path/path.dart' as p;

import '../../infra/preview/jpeg_size.dart';
import '../../infra/preview/preview_extractor.dart';
import '../catalog/photo_entity.dart';
import '../catalog/stable_key.dart';

/// A file in the export folder, read as a photograph.
///
/// The point of this file is that there is nothing else to it: an exported JPEG
/// becomes an ordinary [PhotoEntity], and the viewer, the crop screen and the
/// layers panel take it without knowing where it came from. The alternative —
/// a parallel viewer, a parallel crop, a parallel layer canvas for Mac files —
/// would be three subsystems drifting from the card's within a release.
///
/// Returns null for anything that is not a decodable photograph. A folder can
/// hold anything, and an entity that cannot be decoded would fail later, in the
/// viewer, where the user is the one who finds out.
Future<PhotoEntity?> readExportedPhoto(File file) async {
  RandomAccessFile? handle;
  try {
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file || stat.size <= 0) return null;

    handle = await file.open();
    final prefix = await handle.read(kHeaderPrefixBytes);
    final scan = scanPhotoHeader(prefix, fileLength: stat.size);
    if (scan is! PreviewScanSuccess) return null;

    final header = scan.header;
    // The whole file, because that is what an exported JPEG is: one frame with
    // no smaller variant inside it. The scanner always appends this stream, so
    // its absence means the file was not readable as a photograph at all.
    final found = header.previews
        .where((s) => s.kind == PreviewStreamKind.wholeFile)
        .firstOrNull;
    if (found == null) return null;

    // The scanner reads dimensions from EXIF tags, and a JPEG written by an
    // image library — including this app's own exports — carries none. The
    // frame marker in the file's own head is the answer, and it is the same
    // reader the exports list already uses to quote a size.
    final declared = jpegPixelSize(prefix);
    final width = found.width ?? declared?.width.round() ?? 0;
    final height = found.height ?? declared?.height.round() ?? 0;
    if (width <= 0 || height <= 0) return null;

    final whole = PreviewStream(
      offset: found.offset,
      length: found.length,
      kind: found.kind,
      width: width,
      height: height,
    );

    final name = p.basenameWithoutExtension(file.path);
    return PhotoEntity(
      radical: name,
      // No DCF folder: this photograph is not on a card, and inventing one
      // would be the first step towards a path that could be written to.
      folder: '',
      key: StableKey.fromMacFile(
        sizeBytes: stat.size,
        pixelWidth: width,
        pixelHeight: height,
        captureTime: header.dateTimeOriginal,
        bodySerial: header.bodySerial,
        fallbackName: name,
      ),
      // Its own file, because every reader downstream — the decode pipeline and
      // the export path both — resolves its bytes through `fileForStream`.
      files: [
        PhotoFile(
          name: p.basename(file.path),
          path: file.path,
          kind: PhotoFileKind.jpeg,
          sizeBytes: stat.size,
          modified: stat.modified,
        ),
      ],
      captureTime: header.dateTimeOriginal,
      bodySerial: header.bodySerial,
      gridPreview: whole,
      viewerPreview: whole,
      orientation: header.orientation,
      settings: header.settings,
    );
  } on FileSystemException {
    return null;
  } finally {
    await handle?.close();
  }
}
