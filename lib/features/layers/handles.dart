import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import '../../infra/geometry/view_transform.dart';
import 'layer_placement.dart';

/// What the pointer is over.
enum GuideHandle {
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,

  /// Anywhere else inside the layer: a drag moves it.
  body;

  bool get isCorner => this != GuideHandle.body;

  /// The corner in the layer's own unit square.
  Offset get local => switch (this) {
        GuideHandle.topLeft => const Offset(0, 0),
        GuideHandle.topRight => const Offset(1, 0),
        GuideHandle.bottomRight => const Offset(1, 1),
        GuideHandle.bottomLeft => const Offset(0, 1),
        GuideHandle.body => const Offset(0.5, 0.5),
      };

  /// The corner that stays put while this one is dragged.
  GuideHandle get opposite => switch (this) {
        GuideHandle.topLeft => GuideHandle.bottomRight,
        GuideHandle.topRight => GuideHandle.bottomLeft,
        GuideHandle.bottomRight => GuideHandle.topLeft,
        GuideHandle.bottomLeft => GuideHandle.topRight,
        GuideHandle.body => GuideHandle.body,
      };

  static const corners = [topLeft, topRight, bottomRight, bottomLeft];
}

/// Where one placed guide is on screen, and what a pointer landing there means.
///
/// The whole coordinate stack in one object, and deliberately no arithmetic of
/// its own: the screen mapping comes from the U8 [ViewTransform] — which owns
/// zoom, pan and the obscura flip — and this composes the layer's own placement
/// onto it. A handle that drifted from the pointer only while obscura was on
/// would be the exact failure KTD-12 exists to prevent, and it cannot happen
/// here because nothing here re-implements the flip.
@immutable
final class LayerFrame {
  LayerFrame({
    required this.placement,
    required this.transform,
  }) : localToNormalized = _placementMatrix(placement, transform.imageSize);

  final LayerPlacement placement;
  final ViewTransform transform;

  /// The layer's unit square onto the photograph, in normalized frame space.
  final Matrix4 localToNormalized;

  /// The layer's unit square onto the window.
  Matrix4 get localToViewport =>
      transform.normalizedToViewport.multiplied(localToNormalized);

  /// Rotation happens in the photograph's pixels, so the chain goes through
  /// them: unit square → centred → pixels → turned → back to normalized →
  /// placed. Rotating in normalized space instead would shear every guide on
  /// any frame that is not square, and look right on the 1:1 test.
  static Matrix4 _placementMatrix(LayerPlacement placement, Size imageSize) {
    final width = imageSize.width > 0 ? imageSize.width : 1.0;
    final height = imageSize.height > 0 ? imageSize.height : 1.0;
    return Matrix4.identity()
      ..translateByDouble(placement.position.dx, placement.position.dy, 0, 1)
      ..scaleByDouble(1 / width, 1 / height, 1, 1)
      ..rotateZ(placement.rotation)
      ..scaleByDouble(placement.scaleX * width, placement.scaleY * height, 1, 1)
      ..translateByDouble(-0.5, -0.5, 0, 1);
  }

  Offset localToScreen(Offset local) => _apply(localToViewport, local);

  Offset localToFrame(Offset local) => _apply(localToNormalized, local);

  /// The pointer, in the layer's own unit square.
  ///
  /// Returns null when the mapping is not invertible — a viewport of no width
  /// during a window resize — rather than a coordinate that would look like a
  /// hit somewhere near the origin.
  Offset? screenToLocal(Offset viewportPoint) {
    final m = localToViewport;
    if (m.determinant().abs() < 1e-12) return null;
    return _apply(Matrix4.inverted(m), viewportPoint);
  }

  /// The four corners, in the order [GuideHandle.corners] names them.
  List<Offset> get cornersOnScreen =>
      [for (final corner in GuideHandle.corners) localToScreen(corner.local)];

  /// What [viewportPoint] is over, or null if it is off the layer.
  ///
  /// Corners first and by screen distance, so an overlapping pair at a tight
  /// scale still resolves to the nearer one rather than to whichever was
  /// checked first. [slop] is a screen radius: the drawn handle is smaller,
  /// because a guide is aligned by feel.
  GuideHandle? hitTest(Offset viewportPoint, {double slop = 10}) {
    GuideHandle? nearest;
    var best = slop;
    for (final corner in GuideHandle.corners) {
      final distance = (localToScreen(corner.local) - viewportPoint).distance;
      if (distance <= best) {
        best = distance;
        nearest = corner;
      }
    }
    if (nearest != null) return nearest;

    final local = screenToLocal(viewportPoint);
    if (local == null) return null;
    final inside = local.dx >= 0 && local.dx <= 1 && local.dy >= 0 && local.dy <= 1;
    return inside ? GuideHandle.body : null;
  }

  /// The placement after dragging [handle] to [viewportPoint].
  ///
  /// [free] is the modifier: without it the guide keeps its proportions, which
  /// is what a construction wants — a golden spiral stretched on one axis is no
  /// longer a golden spiral. With it, each axis follows the pointer.
  LayerPlacement resized(
    GuideHandle handle,
    Offset viewportPoint, {
    bool free = false,
  }) {
    if (!handle.isCorner || placement.locked) return placement;
    final pointer = screenToLocal(viewportPoint);
    if (pointer == null) return placement;

    final anchor = handle.opposite.local;
    final toward = handle.local - anchor; // (±1, ±1)
    var dx = (pointer.dx - anchor.dx) * toward.dx.sign;
    var dy = (pointer.dy - anchor.dy) * toward.dy.sign;
    // Dragging a corner past its anchor would flip the guide inside out; the
    // useful reading of that gesture is "as small as it goes".
    dx = math.max(dx, 0);
    dy = math.max(dy, 0);

    if (!free) {
      final uniform = math.max(dx, dy);
      dx = uniform;
      dy = uniform;
    }

    final corner = Offset(
      anchor.dx + toward.dx * dx,
      anchor.dy + toward.dy * dy,
    );
    final centreLocal = Offset(
      (anchor.dx + corner.dx) / 2,
      (anchor.dy + corner.dy) / 2,
    );

    return placement.resizedTo(
      centre: localToFrame(centreLocal),
      scaleX: placement.scaleX * dx,
      scaleY: placement.scaleY * dy,
    );
  }

  /// The placement after dragging the body by [delta] screen pixels.
  LayerPlacement moved(Offset from, Offset to) {
    if (placement.locked) return placement;
    final a = transform.screenToNormalized(from);
    final b = transform.screenToNormalized(to);
    return placement.movedTo(placement.position + (b - a));
  }

  static Offset _apply(Matrix4 m, Offset point) {
    final v = m.perspectiveTransform(Vector3(point.dx, point.dy, 0));
    return Offset(v.x, v.y);
  }
}
