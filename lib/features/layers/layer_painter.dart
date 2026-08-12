import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../infra/geometry/view_transform.dart';
import 'handles.dart';
import 'layer_placement.dart';
import 'patterns/constructions.dart';
import 'patterns/pattern.dart';

/// The guides, drawn over the photograph.
///
/// One path per layer, built in the layer's own unit square and then
/// transformed once by the matrix [LayerFrame] composes. Two consequences, both
/// deliberate: the geometry scales with the picture while the stroke stays a
/// hairline at any zoom, and the dashes are measured on the screen path, so a
/// dashed reciprocal looks the same at fit and at 400 %.
class LayerPainter extends CustomPainter {
  const LayerPainter({
    required this.layers,
    required this.transform,
    this.selected,
    this.showHandles = true,
  });

  /// In paint order: the panel hands them over sorted by z-index.
  final List<LayerPlacement> layers;

  final ViewTransform transform;

  /// [LayerPlacement.localId] of the layer whose handles are showing.
  final int? selected;

  /// False while the panel is closed: the guides stay on the photograph — that
  /// is what they are for — but a frame and four handles around them are tool
  /// chrome, and tool chrome over a picture nobody is editing is in the way.
  final bool showHandles;

  /// Radius of a point of force, in screen pixels.
  ///
  /// Fixed, not scaled: it marks a place rather than covering an area, and one
  /// that grew with the zoom would start to look like a target the subject has
  /// to fill.
  static const double pointRadius = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final frameAspect = transform.imageSize.height > 0
        ? transform.imageSize.width / transform.imageSize.height
        : 3 / 2;

    for (final placement in layers) {
      final primitives = buildGuide(
        placement.patternCode,
        aspect: placement.aspectIn(frameAspect),
      );
      if (primitives.isEmpty) continue;

      final frame = LayerFrame(placement: placement, transform: transform);
      final matrix = frame.localToViewport.storage;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ObscuraStrokes.hairline
        ..isAntiAlias = true
        ..color = Color(placement.color)
            .withValues(alpha: placement.opacity.clamp(0.0, 1.0));

      final solid = Path();
      final dashed = Path();
      final points = <Offset>[];

      for (final primitive in primitives) {
        final into = primitive.dashed ? dashed : solid;
        switch (primitive) {
          case GuideSegment(:final a, :final b):
            into
              ..moveTo(a.dx, a.dy)
              ..lineTo(b.dx, b.dy);
          case GuidePolyline(:final points, :final closed):
            if (points.isEmpty) break;
            into.moveTo(points.first.dx, points.first.dy);
            for (final point in points.skip(1)) {
              into.lineTo(point.dx, point.dy);
            }
            if (closed) into.close();
          case GuideCubic(:final start, :final control1, :final control2, :final end):
            into
              ..moveTo(start.dx, start.dy)
              ..cubicTo(
                control1.dx,
                control1.dy,
                control2.dx,
                control2.dy,
                end.dx,
                end.dy,
              );
          case GuideArc(:final centre, :final radii, :final startAngle, :final sweep):
            into.addArc(
              Rect.fromCenter(
                center: centre,
                width: radii.dx * 2,
                height: radii.dy * 2,
              ),
              startAngle,
              sweep,
            );
          case GuideCircle(:final centre, :final radius):
            // A fraction of the layer's shorter side, so the ring stays round
            // on a panorama instead of becoming the ellipse an arc would give.
            final aspect = placement.aspectIn(frameAspect);
            final rx = radius * (aspect >= 1 ? 1 / aspect : 1.0);
            final ry = radius * (aspect >= 1 ? 1.0 : aspect);
            into.addOval(
              Rect.fromCenter(center: centre, width: rx * 2, height: ry * 2),
            );
          case GuidePoint(:final at):
            points.add(frame.localToScreen(at));
        }
      }

      canvas.drawPath(solid.transform(matrix), paint);
      if (!dashed.getBounds().isEmpty) {
        canvas.drawPath(_dashed(dashed.transform(matrix)), paint);
      }
      for (final point in points) {
        canvas.drawCircle(point, pointRadius, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      }

      if (showHandles && placement.localId == selected) {
        _drawSelection(canvas, frame);
      }
    }
  }

  /// The selected layer's own rectangle and its four corner handles.
  ///
  /// Drawn in the interface's colours rather than the guide's: this is chrome,
  /// and a handle in the user's chosen stroke colour would be indistinguishable
  /// from the geometry it is there to move.
  void _drawSelection(Canvas canvas, LayerFrame frame) {
    final corners = frame.cornersOnScreen;
    final outline = Path()..addPolygon(corners, true);
    canvas.drawPath(
      _dashed(outline, on: 4, off: 3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ObscuraStrokes.hairline
        ..color = ObscuraColors.textSecondary,
    );

    final locked = frame.placement.locked;
    for (final corner in corners) {
      canvas.drawRect(
        Rect.fromCenter(
          center: corner,
          width: ObscuraStrokes.handleHitSize,
          height: ObscuraStrokes.handleHitSize,
        ),
        Paint()
          ..style = locked ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = ObscuraStrokes.hairline
          ..color = locked
              ? ObscuraColors.textSecondary
              : ObscuraColors.textPrimary,
      );
    }
  }

  /// [source] cut into dashes, in screen pixels.
  static Path _dashed(Path source, {double on = 5, double off = 4}) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + on).clamp(0.0, metric.length);
        out.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + off;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(LayerPainter old) =>
      old.selected != selected ||
      old.showHandles != showHandles ||
      old.transform.viewport != transform.viewport ||
      old.transform.obscura != transform.obscura ||
      old.transform.imageSize != transform.imageSize ||
      old.transform.zoom != transform.zoom ||
      !listEquals(old.layers, layers);
}

/// A guide drawn at thumbnail size, for the palette in the panel.
///
/// The same [buildGuide] the canvas uses, at the tile's own aspect: the preview
/// a photographer taps is the construction they are about to get, and a stored
/// preview image would be the one place the two could drift apart.
class GuidePreviewPainter extends CustomPainter {
  const GuidePreviewPainter({required this.code, required this.color});

  final String code;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final primitives = buildGuide(code, aspect: size.width / size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ObscuraStrokes.hairline
      ..color = color;

    final matrix = (Matrix4.identity()
          ..scaleByDouble(size.width, size.height, 1, 1))
        .storage;
    final path = Path();
    for (final primitive in primitives) {
      switch (primitive) {
        case GuideSegment(:final a, :final b):
          path
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy);
        case GuidePolyline(:final points, :final closed):
          if (points.isEmpty) break;
          path.moveTo(points.first.dx, points.first.dy);
          for (final point in points.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
          if (closed) path.close();
        case GuideCubic(:final start, :final control1, :final control2, :final end):
          path
            ..moveTo(start.dx, start.dy)
            ..cubicTo(control1.dx, control1.dy, control2.dx, control2.dy,
                end.dx, end.dy);
        case GuideArc(:final centre, :final radii, :final startAngle, :final sweep):
          path.addArc(
            Rect.fromCenter(
              center: centre,
              width: radii.dx * 2,
              height: radii.dy * 2,
            ),
            startAngle,
            sweep,
          );
        case GuideCircle(:final centre, :final radius):
          final aspect = size.width / size.height;
          final rx = radius * (aspect >= 1 ? 1 / aspect : 1.0);
          final ry = radius * (aspect >= 1 ? 1.0 : aspect);
          path.addOval(
            Rect.fromCenter(center: centre, width: rx * 2, height: ry * 2),
          );
        case GuidePoint(:final at):
          canvas.drawCircle(
            Offset(at.dx * size.width, at.dy * size.height),
            1.5,
            Paint()..color = color,
          );
      }
    }
    canvas.drawPath(path.transform(matrix), paint);
  }

  @override
  bool shouldRepaint(GuidePreviewPainter old) =>
      old.code != code || old.color != color;
}
