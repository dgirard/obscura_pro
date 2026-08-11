import 'package:flutter/foundation.dart';

import '../../infra/preview/preview_extractor.dart';
import 'stable_key.dart';

/// One photograph, as the user thinks of it.
///
/// Shooting in DNG+JPG writes two files sharing a radical, and they are one
/// picture, not two: the grid shows a single cell and deleting it removes both.
/// Treating them separately is how a culling tool ends up leaving orphan JPEGs
/// behind on a card the user believes they have cleared.
@immutable
class PhotoEntity {
  const PhotoEntity({
    required this.radical,
    required this.folder,
    required this.key,
    required this.files,
    this.captureTime,
    this.bodySerial,
    this.gridPreview,
    this.viewerPreview,
  });

  /// DCF file radical, e.g. `L1000863`. The camera's own name for the picture,
  /// and the one thing about it that must never change.
  final String radical;

  /// DCF folder, e.g. `100LEICA`.
  final String folder;

  final StableKey key;

  /// Every file on the card belonging to this photograph. Deletion acts on all
  /// of them or on none.
  final List<PhotoFile> files;

  /// EXIF capture time. Null when no file in the entity had readable EXIF.
  final DateTime? captureTime;

  final String? bodySerial;

  /// Byte ranges of the embedded JPEG streams, recorded during the scan so a
  /// decode worker never has to walk the IFD chain a second time.
  final PreviewStream? gridPreview;
  final PreviewStream? viewerPreview;

  /// `100LEICA/L1000863` — stable across remounts, unlike an absolute path.
  String get dcfPath => '$folder/$radical';

  bool get hasRaw => files.any((f) => f.kind == PhotoFileKind.raw);
  bool get hasJpeg => files.any((f) => f.kind == PhotoFileKind.jpeg);

  /// What the grid badge says.
  String get formatBadge => switch ((hasRaw, hasJpeg)) {
        (true, true) => 'RAW+JPG',
        (true, false) => 'RAW',
        (false, true) => 'JPG',
        _ => '—',
      };

  /// Total bytes this photograph occupies, so the trash can quote what emptying
  /// it will actually reclaim.
  int get totalBytes => files.fold(0, (sum, f) => sum + f.sizeBytes);

  /// True when no preview could be located and the grid must show an error
  /// tile. Such a photo stays selectable and deletable — a picture the app
  /// cannot render is exactly one the user may want gone.
  bool get isUnreadable => gridPreview == null;

  @override
  String toString() => 'PhotoEntity($dcfPath, $formatBadge)';
}

enum PhotoFileKind { raw, jpeg }

@immutable
class PhotoFile {
  const PhotoFile({
    required this.name,
    required this.path,
    required this.kind,
    required this.sizeBytes,
    required this.modified,
  });

  /// File name as the camera wrote it, e.g. `L1000863.DNG`.
  final String name;

  /// Absolute path at the current mount. Volatile by nature — never persisted
  /// as identity, only used to reach the bytes during this session.
  final String path;

  final PhotoFileKind kind;
  final int sizeBytes;
  final DateTime modified;

  @override
  String toString() => 'PhotoFile($name)';
}

/// The result of walking a card.
@immutable
class CardCatalog {
  const CardCatalog({
    required this.photos,
    required this.unsupportedFiles,
    required this.scanDuration,
  });

  /// Photographs, ordered by capture time then radical.
  final List<PhotoEntity> photos;

  /// Files inside `DCIM/` the catalog deliberately does not model — video, most
  /// notably, which a Q3 writes alongside the stills.
  ///
  /// Surfaced rather than dropped: a card that reports "0 photos" while still
  /// holding gigabytes of video would be lying to someone deciding whether it is
  /// safe to reformat.
  final List<String> unsupportedFiles;

  final Duration scanDuration;

  int get photoCount => photos.length;
  int get totalBytes => photos.fold(0, (sum, p) => sum + p.totalBytes);
}
