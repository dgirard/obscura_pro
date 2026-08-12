/// Turning a crop into a file on the Mac (R16, FONC-CROP-2, FONC-CROP-3).
///
/// Two things this never does.
///
/// **It never touches the DNG.** Cropping is a decision recorded on the Mac and
/// an new JPEG written on the Mac. The camera's file is opened read-only, for a
/// byte range, and closed. A test checksums it before and after.
///
/// **It never exports the picture the screen was showing.** The crop rectangle
/// is normalized, and it is applied to the full-resolution embedded preview —
/// 9520 x 6336 on a Q3 — not to the display-sized bitmap the crop widget was
/// fed. Those two paths look identical in code and differ by a factor of eleven
/// in the result, which is exactly the kind of loss that is never noticed until
/// the print comes back.
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../infra/preview/preview_extractor.dart';
import '../catalog/photo_entity.dart';
import 'ratio.dart';
import 'dart:ui' show Rect, Size;

/// Where exports go when the user has not said otherwise.
///
/// Under `~/Pictures`, because that is where a photographer looks, and in a
/// dated folder per session so a run of exports stays together instead of
/// silting up one directory over months.
Future<Directory> defaultExportFolder({DateTime? now}) async {
  final day = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
  return Directory(p.join((await defaultExportRoot()).path, day));
}

/// The folder the dated ones live in.
///
/// Separated because the exports screen reads *the folder*, not just the rows:
/// what a photographer means by "my exports" is what is in there, including
/// files this app did not put there and files it has forgotten.
Future<Directory> defaultExportRoot() async {
  final pictures = await getApplicationDocumentsDirectory();
  final home = p.dirname(pictures.path);
  return Directory(p.join(home, 'Pictures', 'Q3Culling', 'Exports'));
}

/// Where an export has got to.
///
/// Three steps because there are three, and they are the three that take time:
/// pulling a full-resolution stream off the card, turning and cutting and
/// re-encoding thirty-nine megapixels on a worker, and writing the file. A
/// photographer who has just pressed the button is owed more than a disabled
/// button — a Q3 frame takes seconds, and seconds with no sign of life are
/// indistinguishable from a hang.
enum ExportStage { reading, rendering, writing }

sealed class ExportOutcome {
  const ExportOutcome();
}

final class ExportWritten extends ExportOutcome {
  const ExportWritten({
    required this.path,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.bytes,
  });

  final String path;
  final int pixelWidth;
  final int pixelHeight;
  final int bytes;
}

final class ExportFailed extends ExportOutcome {
  const ExportFailed(this.reason);
  final String reason;

  @override
  String toString() => 'ExportFailed: $reason';
}

class ExportService {
  const ExportService({this.quality = 92});

  /// JPEG quality. High, because this is the deliverable rather than a cache
  /// entry, and the source is already a JPEG so every generation costs.
  final int quality;

  /// Crops [photo] and writes the result.
  ///
  /// The source is the full-resolution embedded preview. The rectangle is
  /// applied to *its* pixel dimensions, which is what makes the exported file
  /// as large as the photograph allows rather than as large as the window
  /// happened to be.
  /// [onStage] is called as each step begins, on the caller's isolate.
  Future<ExportOutcome> export({
    required PhotoEntity photo,
    required CropRect crop,
    required Directory folder,
    DateTime? now,
    void Function(ExportStage stage)? onStage,
  }) async {
    final source = photo.viewerPreview;
    if (source == null) {
      return const ExportFailed('cette photographie n\'a pas de preview lisible');
    }
    final file = photo.fileForStream(source);
    if (file == null) return const ExportFailed('aucun fichier à lire');

    final Uint8List bytes;
    try {
      onStage?.call(ExportStage.reading);
      bytes = await _readRange(file.path, source.offset, source.length);
    } on FileSystemException catch (error) {
      return ExportFailed(error.message);
    }

    // Decoding, turning, cropping and re-encoding a 39 Mpx frame is seconds of
    // arithmetic. On the UI isolate that is seconds of a frozen window, so it
    // happens on a worker and only the finished JPEG comes back.
    final _Rendered rendered;
    try {
      onStage?.call(ExportStage.rendering);
      final job = _CropJob(
        source: bytes,
        orientation: photo.orientation,
        angleDegrees: crop.angleDegrees,
        left: crop.rect.left,
        top: crop.rect.top,
        width: crop.rect.width,
        height: crop.rect.height,
        ratioIndex: crop.ratio.index,
        orientationIndex: crop.orientation.index,
        quality: quality,
        stamp: photo.captureTime == null ? null : _exifStamp(photo.captureTime!),
        model: photo.settings.model,
        lens: photo.settings.lens,
        iso: photo.settings.iso,
        focalLength35mm: photo.settings.focalLength35mm,
      );
      rendered = await Isolate.run(() => _renderCrop(job));
    } on Object catch (error) {
      return ExportFailed('$error');
    }

    final destination = File(p.join(
      folder.path,
      await nextFileName(folder: folder, photo: photo, ratio: crop.ratio),
    ));

    try {
      onStage?.call(ExportStage.writing);
      await folder.create(recursive: true);
      // Through a temporary name and a rename: an export folder should never
      // hold a half-written file that a photographer might pick up.
      final temp = File('${destination.path}.part');
      await temp.writeAsBytes(rendered.bytes, flush: true);
      await temp.rename(destination.path);

      return ExportWritten(
        path: destination.path,
        pixelWidth: rendered.width,
        pixelHeight: rendered.height,
        bytes: rendered.bytes.length,
      );
    } on FileSystemException catch (error) {
      return ExportFailed(error.message);
    }
  }

  /// `L1000001_3x2_01.jpg`, then `_02` the next time.
  ///
  /// Numbered per photograph *and* per ratio, so trying the same frame as a
  /// square and as an XPan gives two names rather than a collision, while
  /// exporting the same crop twice gives two files rather than an overwrite.
  /// Nothing here ever replaces a file that already exists.
  static Future<String> nextFileName({
    required Directory folder,
    required PhotoEntity photo,
    required CropRatio ratio,
  }) async {
    final stem = '${photo.radical}_${ratio.slug}';
    for (var index = 1; index < 1000; index++) {
      final name = '${stem}_${index.toString().padLeft(2, '0')}.jpg';
      if (!await File(p.join(folder.path, name)).exists()) return name;
    }
    // A thousand exports of one crop of one frame is not a case to design for,
    // but silently overwriting the first would be the wrong answer to it.
    return '${stem}_${DateTime.now().microsecondsSinceEpoch}.jpg';
  }

  static String _exifStamp(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}:'
      '${t.month.toString().padLeft(2, '0')}:'
      '${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';


  static Future<Uint8List> _readRange(String path, int offset, int length) async {
    final handle = await File(path).open();
    try {
      if (offset != 0) await handle.setPosition(offset);
      return await handle.read(length);
    } finally {
      await handle.close();
    }
  }

  static img.Image _applyOrientation(img.Image source, int orientation) =>
      switch (orientation) {
        ExifOrientation.rotate90 => img.copyRotate(source, angle: 90),
        ExifOrientation.rotate180 => img.copyRotate(source, angle: 180),
        ExifOrientation.rotate270 => img.copyRotate(source, angle: 270),
        ExifOrientation.flipHorizontal =>
          img.copyFlip(source, direction: img.FlipDirection.horizontal),
        ExifOrientation.flipVertical =>
          img.copyFlip(source, direction: img.FlipDirection.vertical),
        ExifOrientation.transpose => img.copyFlip(
            img.copyRotate(source, angle: 90),
            direction: img.FlipDirection.horizontal,
          ),
        ExifOrientation.transverse => img.copyFlip(
            img.copyRotate(source, angle: 270),
            direction: img.FlipDirection.horizontal,
          ),
        _ => source,
      };
}

/// Everything the worker needs, and nothing that cannot cross an isolate.
///
/// Primitives and one byte buffer. The crop is carried as four doubles plus two
/// enum indices rather than as a [CropRect] so that no `dart:ui` object has to
/// survive the hop; the rectangle is rebuilt on the far side, where the
/// straightened image's real pixel dimensions are finally known.
final class _CropJob {
  const _CropJob({
    required this.source,
    required this.orientation,
    required this.angleDegrees,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.ratioIndex,
    required this.orientationIndex,
    required this.quality,
    required this.stamp,
    required this.model,
    required this.lens,
    required this.iso,
    required this.focalLength35mm,
  });

  final Uint8List source;
  final int orientation;
  final double angleDegrees;
  final double left;
  final double top;
  final double width;
  final double height;
  final int ratioIndex;
  final int orientationIndex;
  final int quality;
  final String? stamp;
  final String? model;
  final String? lens;
  final int? iso;
  final int? focalLength35mm;
}

final class _Rendered {
  const _Rendered({required this.bytes, required this.width, required this.height});
  final Uint8List bytes;
  final int width;
  final int height;
}

/// The CPU-bound half of an export. Runs on a worker isolate.
///
/// Upright, then straightened, then cropped — the same order the screen showed.
/// The rectangle is expressed over the photograph as the photographer sees it,
/// and applying it to sensor-orientation pixels would crop a portrait frame
/// along the wrong axis entirely.
_Rendered _renderCrop(_CropJob job) {
  final decoded = img.decodeJpg(job.source);
  if (decoded == null) throw const FormatException('preview illisible');

  final upright = ExportService._applyOrientation(decoded, job.orientation);
  // Positive turns clockwise, which is what `Transform.rotate` does in the
  // preview. Negating here is how an export came out tilted the opposite way
  // from what the photographer had just straightened on screen — twice as
  // crooked as the frame they started with.
  final straightened = job.angleDegrees == 0
      ? upright
      : img.copyRotate(upright, angle: job.angleDegrees);

  final crop = CropRect(
    rect: Rect.fromLTWH(job.left, job.top, job.width, job.height),
    ratio: CropRatio.values[job.ratioIndex],
    orientation: CropOrientation.values[job.orientationIndex],
    angleDegrees: job.angleDegrees,
  );
  final pixels = crop.toPixels(
    Size(straightened.width.toDouble(), straightened.height.toDouble()),
  );

  final cropped = img.copyCrop(
    straightened,
    x: pixels.left.round(),
    y: pixels.top.round(),
    width: pixels.width.round(),
    height: pixels.height.round(),
  );

  _writeEssentialExif(cropped, job);
  return _Rendered(
    bytes: img.encodeJpg(cropped, quality: job.quality),
    width: cropped.width,
    height: cropped.height,
  );
}

/// Writes the metadata that identifies the photograph, and nothing else.
///
/// Date, camera, lens and exposure: what a photographer needs to find the frame
/// again and to know how it was taken. The crop's own dimensions are left to the
/// encoder, and no location data is invented.
void _writeEssentialExif(img.Image target, _CropJob job) {
  final exif = target.exif;

  // Numeric tags, not names. The library's name table does not resolve every
  // one of these to the id the format specifies — ISO written by name lands
  // somewhere a reader will never look for it — and the extractor already holds
  // the numbers this app trusts.
  if (job.stamp != null) {
    final stamp = img.IfdValueAscii(job.stamp!);
    exif.imageIfd[0x0132] = stamp; // DateTime
    exif.exifIfd[PreviewTags.dateTimeOriginal] = stamp;
    exif.exifIfd[0x9004] = stamp; // DateTimeDigitized
  }
  if (job.model != null) {
    exif.imageIfd[PreviewTags.model] = img.IfdValueAscii(job.model!);
  }
  if (job.lens != null) {
    exif.exifIfd[PreviewTags.lensModel] = img.IfdValueAscii(job.lens!);
  }
  if (job.iso != null) {
    exif.exifIfd[PreviewTags.isoSpeedRatings] = img.IfdValueShort(job.iso!);
  }
  if (job.focalLength35mm != null) {
    exif.exifIfd[PreviewTags.focalLengthIn35mm] =
        img.IfdValueShort(job.focalLength35mm!);
  }
  // The export is upright, so the orientation tag says so. What matters is that
  // the source's tag is *not* carried over: a rotating value here would turn an
  // already-turned picture a second time in every viewer that honours it, and
  // the result looks deliberate.
  exif.imageIfd.orientation = ExifOrientation.normal;
  exif.imageIfd[0x0131] = img.IfdValueAscii('Obscura Pro'); // Software
}
