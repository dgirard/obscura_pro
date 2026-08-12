import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

/// The one authoritative mapping between what is on screen and where it is in
/// the photograph (KTD-12).
///
/// Four things need this mapping and they must agree: the zoom/pan matrix, the
/// obscura rotation, crop-handle hit testing, and layer placement. Three
/// separate implementations would diverge precisely where the errors are
/// hardest to see — a handle that drifts from the pointer only while rotated,
/// a zoom that walks away from the cursor at high magnification.
///
/// **Normalized space** is `(0,0)` at the photograph's top-left and `(1,1)` at
/// its bottom-right, in the photograph as the photographer sees it: EXIF
/// orientation already applied, obscura not. Crop rectangles and layer
/// transforms are stored in that space and never in screen coordinates, so they
/// survive a window resize, a zoom, and obscura being switched on.
///
/// **Obscura** is a presentation-time flip, `(x,y) -> (1-x, 1-y)`, applied
/// inside this chain and nowhere else. It is a 180-degree rotation and not a
/// mirror, which is why both axes invert and the aspect ratio is untouched.
@immutable
final class ViewTransform {
  const ViewTransform({
    required this.imageSize,
    required this.viewport,
    this.matrix,
    this.obscura = false,
  });

  /// Pixel size of the photograph *upright* — EXIF orientation already applied,
  /// so a portrait frame is taller than it is wide here even though its stored
  /// preview is not.
  final Size imageSize;

  /// The area the viewer draws into, in logical pixels.
  final Size viewport;

  /// The zoom/pan matrix, mapping scene coordinates to viewport coordinates.
  ///
  /// This is `TransformationController.value`. Null means the identity, which
  /// is the fitted view.
  final Matrix4? matrix;

  final bool obscura;

  /// Scale at which the whole photograph is visible.
  ///
  /// Zero when either size is degenerate — a viewport of no width happens for
  /// one frame during a window resize, and dividing by it would poison every
  /// coordinate that followed.
  double get fitScale {
    if (imageSize.width <= 0 ||
        imageSize.height <= 0 ||
        viewport.width <= 0 ||
        viewport.height <= 0) {
      return 0;
    }
    return math.min(
      viewport.width / imageSize.width,
      viewport.height / imageSize.height,
    );
  }

  /// Where the fitted photograph sits in scene coordinates: centred, whole,
  /// never cropped.
  Rect get fittedRect {
    final scale = fitScale;
    final width = imageSize.width * scale;
    final height = imageSize.height * scale;
    return Rect.fromLTWH(
      (viewport.width - width) / 2,
      (viewport.height - height) / 2,
      width,
      height,
    );
  }

  /// Zoom factor, relative to fit, currently applied by [matrix].
  double get zoom {
    final m = matrix;
    if (m == null) return 1;
    // Uniform scaling is all InteractiveViewer produces, so the x basis vector's
    // length is the scale.
    return m.getMaxScaleOnAxis();
  }

  /// On-screen logical pixels per image pixel.
  double get pixelScale => fitScale * zoom;

  /// The [zoom] at which one image pixel covers one *device* pixel.
  ///
  /// Device and not logical: on a Retina display "100%" in a photo tool means
  /// the sensor's pixels mapped onto the screen's, which is the magnification
  /// at which a photographer judges focus. Mapping to logical pixels instead
  /// would quietly show them a half-size image and call it 100%.
  double zoomForActualPixels(double devicePixelRatio) {
    final fit = fitScale;
    if (fit <= 0 || devicePixelRatio <= 0) return 1;
    return 1 / (fit * devicePixelRatio);
  }

  /// The whole chain as one affine transform: normalized space to the viewport.
  ///
  /// Obscura's flip, the fitted rectangle and the zoom matrix are all affine,
  /// so the three compose into one. Layers need it as a matrix rather than as a
  /// mapping of points: a guide is a path, and transforming the path once is
  /// both cheaper and the only way to keep the stroke one pixel wide while the
  /// geometry under it scales.
  ///
  /// [normalizedToScreen] is implemented with this, so the chain exists once.
  Matrix4 get normalizedToViewport {
    final rect = fittedRect;
    final m = matrix?.clone() ?? Matrix4.identity();
    m
      ..translateByDouble(rect.left, rect.top, 0, 1)
      ..scaleByDouble(rect.width, rect.height, 1, 1);
    if (obscura) {
      m
        ..translateByDouble(1, 1, 0, 1)
        ..scaleByDouble(-1, -1, 1, 1);
    }
    return m;
  }

  /// A normalized point to a point in the viewport.
  Offset normalizedToScreen(Offset normalized) {
    final v = normalizedToViewport.perspectiveTransform(
      Vector3(normalized.dx, normalized.dy, 0),
    );
    return Offset(v.x, v.y);
  }

  /// A point in the viewport to a normalized point.
  ///
  /// Points outside the photograph come back outside `0..1` rather than
  /// clamped: a crop drag that leaves the frame needs to know by how much, and
  /// clamping here would hide it from every caller.
  Offset screenToNormalized(Offset viewportPoint) {
    final scene = _viewportToScene(viewportPoint);
    final rect = fittedRect;
    if (rect.width <= 0 || rect.height <= 0) return Offset.zero;
    final unit = Offset(
      (scene.dx - rect.left) / rect.width,
      (scene.dy - rect.top) / rect.height,
    );
    return obscura ? Offset(1 - unit.dx, 1 - unit.dy) : unit;
  }

  /// A normalized rectangle to its place in the viewport.
  ///
  /// Built from two opposite corners and then normalized, because under obscura
  /// the top-left corner maps to the bottom-right one and a rectangle assembled
  /// from a raw origin plus size would come out inside out.
  Rect screenRectOf(Rect normalized) {
    final a = normalizedToScreen(normalized.topLeft);
    final b = normalizedToScreen(normalized.bottomRight);
    return Rect.fromPoints(a, b);
  }

  /// Whether a normalized point is inside the photograph.
  static bool containsNormalized(Offset normalized) =>
      normalized.dx >= 0 &&
      normalized.dx <= 1 &&
      normalized.dy >= 0 &&
      normalized.dy <= 1;

  /// The matrix that zooms to [zoom] while holding [focus] — a viewport point —
  /// still.
  ///
  /// This is what makes zoom-to-cursor and double-click-to-point land where the
  /// user pointed instead of at the middle of the window.
  Matrix4 zoomedAround(Offset focus, double zoom) {
    final scene = _viewportToScene(focus);
    return Matrix4.identity()
      ..translateByDouble(focus.dx, focus.dy, 0, 1)
      ..scaleByDouble(zoom, zoom, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
  }

  ViewTransform copyWith({Matrix4? matrix, bool? obscura, Size? viewport}) =>
      ViewTransform(
        imageSize: imageSize,
        viewport: viewport ?? this.viewport,
        matrix: matrix ?? this.matrix,
        obscura: obscura ?? this.obscura,
      );

  Offset _viewportToScene(Offset viewportPoint) {
    final m = matrix;
    if (m == null) return viewportPoint;
    final inverse = Matrix4.inverted(m);
    final v = inverse.perspectiveTransform(
      Vector3(viewportPoint.dx, viewportPoint.dy, 0),
    );
    return Offset(v.x, v.y);
  }

  @override
  String toString() => 'ViewTransform($imageSize in $viewport, '
      'zoom ${zoom.toStringAsFixed(2)}${obscura ? ', obscura' : ''})';
}
