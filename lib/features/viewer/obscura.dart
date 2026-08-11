import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infra/preview/preview_extractor.dart';

/// Obscura mode: the photograph shown upside down.
///
/// The point is not an effect. Turning a picture half a turn stops the eye
/// reading the subject and leaves it reading the masses, which is the whole
/// technique the camera obscura is named for. So: rotation and not mirror, and
/// no darkening or masking of any kind (FONC-OBS-1).
///
/// The state is global rather than per photograph, and stays on as the user
/// moves through a session — that is how the technique is used, on a run of
/// frames rather than on one.
class ObscuraNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final obscuraProvider =
    NotifierProvider<ObscuraNotifier, bool>(ObscuraNotifier.new);

/// How stored pixels must be turned to be seen the right way up.
///
/// Two rotations compose here and both are presentation-only: the EXIF
/// orientation the camera recorded, and obscura. Neither ever touches a stored
/// coordinate — crop rectangles and layer transforms live in upright normalized
/// space and are mapped through [ViewTransform] instead.
@immutable
final class DisplayOrientation {
  const DisplayOrientation({required this.quarterTurns, required this.mirrored});

  /// Composes the EXIF orientation with obscura.
  ///
  /// Obscura is added as two quarter turns even when the EXIF orientation is a
  /// mirrored one, and the order does not matter: a half turn commutes with a
  /// mirror, so there is no arrangement of the two that gives a different
  /// picture. The mirrored orientations are supported although no camera in
  /// this app's path writes one.
  factory DisplayOrientation.of(int exif, {bool obscura = false}) {
    final (turns, mirrored) = switch (exif) {
      ExifOrientation.flipHorizontal => (0, true),
      ExifOrientation.rotate180 => (2, false),
      ExifOrientation.flipVertical => (2, true),
      ExifOrientation.transpose => (1, true),
      ExifOrientation.rotate90 => (1, false),
      ExifOrientation.transverse => (3, true),
      ExifOrientation.rotate270 => (3, false),
      _ => (0, false),
    };
    return DisplayOrientation(
      quarterTurns: (turns + (obscura ? 2 : 0)) % 4,
      mirrored: mirrored,
    );
  }

  /// Clockwise quarter turns, 0..3.
  final int quarterTurns;
  final bool mirrored;

  bool get swapsAxes => quarterTurns.isOdd;

  /// The size [stored] presents once turned.
  Size sizeOf(Size stored) =>
      swapsAxes ? Size(stored.height, stored.width) : stored;

  @override
  bool operator ==(Object other) =>
      other is DisplayOrientation &&
      other.quarterTurns == quarterTurns &&
      other.mirrored == mirrored;

  @override
  int get hashCode => Object.hash(quarterTurns, mirrored);

  @override
  String toString() =>
      'DisplayOrientation(${quarterTurns * 90}deg${mirrored ? ', mirrored' : ''})';
}

/// Draws a decoded frame turned the right way up, filling [orientedRect].
///
/// The turn happens on the GPU, in the canvas transform. The alternative —
/// rotating the pixels — would mean a second copy of a frame that is already
/// tens of megabytes, once per toggle, to produce something the compositor can
/// do for free.
class OrientedImagePainter extends CustomPainter {
  const OrientedImagePainter({
    required this.image,
    required this.orientation,
    required this.filterQuality,
  });

  final ui.Image image;
  final DisplayOrientation orientation;
  final FilterQuality filterQuality;

  @override
  void paint(Canvas canvas, Size size) {
    final stored = Size(image.width.toDouble(), image.height.toDouble());
    if (stored.isEmpty || size.isEmpty) return;

    final upright = orientation.sizeOf(stored);
    final scale = math.min(size.width / upright.width, size.height / upright.height);
    final drawn = Size(stored.width * scale, stored.height * scale);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(orientation.quarterTurns * math.pi / 2);
    if (orientation.mirrored) canvas.scale(-1, 1);
    canvas.drawImageRect(
      image,
      Offset.zero & stored,
      Rect.fromCenter(
        center: Offset.zero,
        width: drawn.width,
        height: drawn.height,
      ),
      Paint()..filterQuality = filterQuality,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(OrientedImagePainter old) =>
      old.image != image ||
      old.orientation != orientation ||
      old.filterQuality != filterQuality;
}

/// A decoded frame, shown upright and turned by obscura when it is on.
class OrientedImage extends StatelessWidget {
  const OrientedImage({
    super.key,
    required this.image,
    required this.orientation,
    this.filterQuality = FilterQuality.medium,
  });

  final ui.Image image;
  final DisplayOrientation orientation;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: OrientedImagePainter(
          image: image,
          orientation: orientation,
          filterQuality: filterQuality,
        ),
        size: Size.infinite,
      );
}
