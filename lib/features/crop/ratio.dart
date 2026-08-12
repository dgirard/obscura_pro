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

/// A corner of the crop, the thing a pointer grabs to resize it.
enum CropCorner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  /// The corner that stays put while this one is dragged.
  CropCorner get opposite => switch (this) {
        CropCorner.topLeft => CropCorner.bottomRight,
        CropCorner.topRight => CropCorner.bottomLeft,
        CropCorner.bottomLeft => CropCorner.topRight,
        CropCorner.bottomRight => CropCorner.topLeft,
      };

  Offset of(Rect rect) => switch (this) {
        CropCorner.topLeft => rect.topLeft,
        CropCorner.topRight => rect.topRight,
        CropCorner.bottomLeft => rect.bottomLeft,
        CropCorner.bottomRight => rect.bottomRight,
      };
}

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

  /// The smallest a crop may become, as a fraction of the frame.
  ///
  /// Not zero: a rectangle dragged to nothing is an encoder error rather than a
  /// photograph, and a user who overshoots should find a small crop, not a
  /// broken one.
  static const double minExtent = 0.05;

  /// This crop's shape expressed in normalized space.
  ///
  /// Normalized space is stretched by the frame's own aspect, so the ratio a
  /// photographer chose is *not* the ratio of the stored rectangle. Every
  /// resize has to go through this or it silently produces a shape nobody asked
  /// for.
  double normalizedAspect(double frameAspect) =>
      frameAspect <= 0 ? 1 : ratio.aspectIn(orientation) / frameAspect;

  /// The crop after [corner] has been dragged to [pointer].
  ///
  /// The opposite corner is the anchor and does not move, which is what makes a
  /// resize feel like pulling on a frame rather than sliding one. The chosen
  /// ratio is preserved throughout: the pointer proposes a size and the ratio
  /// decides it, so there is no drag that can produce a shape off the list.
  CropRect resizedFrom({
    required CropCorner corner,
    required Offset pointer,
    required double frameAspect,
  }) {
    final anchor = corner.opposite.of(rect);
    final aspect = normalizedAspect(frameAspect);

    // The pointer rarely lands on the ratio exactly, so the larger of the two
    // dimensions it implies wins and the other follows. Taking the smaller
    // instead would make the crop shrink away from a pointer moving outward.
    final proposedWidth = (pointer.dx - anchor.dx).abs();
    final proposedHeight = (pointer.dy - anchor.dy).abs();
    // Both dimensions must clear the floor, and height follows width, so the
    // floor on width is whichever of the two constraints binds.
    final floorWidth = math.max(minExtent, minExtent * aspect);
    var width = math.max(
      math.max(proposedWidth, proposedHeight * aspect),
      floorWidth,
    );
    var height = width / aspect;

    // Room between the anchor and the frame edge the drag is heading for.
    final towardsLeft = pointer.dx < anchor.dx;
    final towardsTop = pointer.dy < anchor.dy;
    final roomX = towardsLeft ? anchor.dx : 1 - anchor.dx;
    final roomY = towardsTop ? anchor.dy : 1 - anchor.dy;
    final scale = math.min(
      roomX <= 0 ? 0.0 : math.min(1.0, roomX / width),
      roomY <= 0 ? 0.0 : math.min(1.0, roomY / height),
    );
    width *= scale;
    height *= scale;

    // The floor again, by assignment rather than by scaling: a pointer landing
    // exactly on the anchor leaves zero, and no multiplication grows a zero.
    if (width < floorWidth) {
      width = floorWidth;
      height = width / aspect;
    }

    final left = towardsLeft ? anchor.dx - width : anchor.dx;
    final top = towardsTop ? anchor.dy - height : anchor.dy;

    return CropRect(
      rect: Rect.fromLTWH(left, top, width, height),
      ratio: ratio,
      orientation: orientation,
    ).clampedToFrame();
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
