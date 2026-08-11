import 'dart:math' as math;
import 'dart:ui';

import 'package:meta/meta.dart';

/// The crop ratios, and only these (R15, FONC-CROP-1).
///
/// Six, each in landscape and portrait except the square. There is no free
/// ratio and no way to reach one — a deliberate constraint, not an omission.
/// A frame is a decision, and a tool that lets you drag the edges until
/// something looks right is one that lets you avoid making it. These six are
/// the ones a camera actually offers, plus the XPan panorama.
enum CropRatio {
  /// The Q3's own frame. Cropping to it is recomposing, not reformatting.
  threeTwo('3:2', 3, 2),
  fourThree('4:3', 4, 3),
  fiveFour('5:4', 5, 4),
  square('1:1', 1, 1),
  sixteenNine('16:9', 16, 9),

  /// The Hasselblad XPan's frame. The reason it is here and 2:1 is not: it is a
  /// specific camera's panorama, and photographers who want it want *that*.
  xpan('65:24', 65, 24);

  const CropRatio(this.label, this.wide, this.tall);

  /// As written on a camera dial: `3:2`, `65:24`.
  final String label;

  /// The two terms, longer side first.
  final int wide;
  final int tall;

  /// Whether the frame can be turned. A square cannot, and offering the toggle
  /// for it would be a control that does nothing.
  bool get hasOrientations => wide != tall;

  /// Filename-safe form: `3x2`, `65x24`.
  String get slug => '${wide}x$tall';

  /// Width over height, in the given orientation.
  double aspectIn(CropOrientation orientation) =>
      orientation == CropOrientation.portrait && hasOrientations
          ? tall / wide
          : wide / tall;

  static CropRatio? fromLabel(String label) {
    for (final ratio in values) {
      if (ratio.label == label) return ratio;
    }
    return null;
  }

  /// The ratio bound to the `1`..`6` keys, in the order the selector shows.
  static CropRatio? forKeyIndex(int index) =>
      (index >= 0 && index < values.length) ? values[index] : null;
}

enum CropOrientation { landscape, portrait }

/// A crop, stored the only way that survives (KTD-12).
///
/// In normalized coordinates over the upright photograph — `(0,0)` top-left,
/// `(1,1)` bottom-right — never in pixels and never in screen coordinates. A
/// rectangle in pixels would be wrong the moment the app decoded the preview at
/// a different size, which it does routinely; a rectangle in screen
/// coordinates would be wrong the moment the window was resized.
@immutable
final class CropRect {
  const CropRect({
    required this.rect,
    required this.ratio,
    required this.orientation,
  });

  final Rect rect;
  final CropRatio ratio;
  final CropOrientation orientation;

  /// The largest rectangle of this ratio that fits inside the whole frame,
  /// centred. What crop mode starts from.
  ///
  /// [frameAspect] is the photograph's own width over height, upright.
  factory CropRect.largestIn({
    required double frameAspect,
    required CropRatio ratio,
    CropOrientation orientation = CropOrientation.landscape,
  }) {
    final wanted = ratio.aspectIn(orientation);
    if (frameAspect <= 0 || wanted <= 0) {
      return CropRect(
        rect: const Rect.fromLTWH(0, 0, 1, 1),
        ratio: ratio,
        orientation: orientation,
      );
    }

    // Normalized space is not square, so a ratio expressed there has to be
    // divided by the frame's own — forgetting that is the classic way to get a
    // crop that is subtly the wrong shape on anything but a square photograph.
    final double width;
    final double height;
    if (wanted >= frameAspect) {
      width = 1;
      height = frameAspect / wanted;
    } else {
      height = 1;
      width = wanted / frameAspect;
    }

    return CropRect(
      rect: Rect.fromLTWH((1 - width) / 2, (1 - height) / 2, width, height),
      ratio: ratio,
      orientation: orientation,
    );
  }

  /// The same crop in pixels of an image [size] across.
  ///
  /// The origin and the extent are each rounded, and the extent is *not*
  /// derived from a rounded opposite edge. Rounding both edges outward — the
  /// obvious way — grows the rectangle by up to a pixel on each axis
  /// independently, which turns a square a user asked for into 428 x 427. When
  /// choosing an exact ratio is the whole point of the feature, an exported
  /// file that is a pixel off is a bug and not a rounding detail.
  Rect toPixels(Size size) {
    final double width =
        math.max(1.0, (rect.width * size.width).roundToDouble());
    final double height =
        math.max(1.0, (rect.height * size.height).roundToDouble());
    final double left = (rect.left * size.width)
        .roundToDouble()
        .clamp(0.0, math.max(0.0, size.width - width))
        .toDouble();
    final double top = (rect.top * size.height)
        .roundToDouble()
        .clamp(0.0, math.max(0.0, size.height - height))
        .toDouble();
    return Rect.fromLTWH(
      left,
      top,
      math.min(width, size.width),
      math.min(height, size.height),
    );
  }

  /// Moved so it lies inside the frame, keeping its size.
  ///
  /// Slid rather than shrunk: a drag that leaves the edge should stop at the
  /// edge, not quietly change the shape the user chose.
  CropRect clampedToFrame() {
    final width = math.min(rect.width, 1.0);
    final height = math.min(rect.height, 1.0);
    return CropRect(
      rect: Rect.fromLTWH(
        rect.left.clamp(0.0, 1 - width),
        rect.top.clamp(0.0, 1 - height),
        width,
        height,
      ),
      ratio: ratio,
      orientation: orientation,
    );
  }

  CropRect withRatio(CropRatio next, {required double frameAspect}) =>
      CropRect.largestIn(
        frameAspect: frameAspect,
        ratio: next,
        orientation: next.hasOrientations ? orientation : CropOrientation.landscape,
      );

  /// Turns the frame between portrait and landscape. A no-op on the square,
  /// which has no second orientation to turn to.
  CropRect turned({required double frameAspect}) {
    if (!ratio.hasOrientations) return this;
    return CropRect.largestIn(
      frameAspect: frameAspect,
      ratio: ratio,
      orientation: orientation == CropOrientation.landscape
          ? CropOrientation.portrait
          : CropOrientation.landscape,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CropRect &&
      other.rect == rect &&
      other.ratio == ratio &&
      other.orientation == orientation;

  @override
  int get hashCode => Object.hash(rect, ratio, orientation);

  @override
  String toString() => 'CropRect(${ratio.label} ${orientation.name}, $rect)';
}
