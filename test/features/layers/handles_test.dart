import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/layers/handles.dart';
import 'package:obscura_pro/features/layers/layer_placement.dart';
import 'package:obscura_pro/infra/geometry/view_transform.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

/// U13. The coordinate stack, from the pointer to the stored transform.
///
/// A 3:2 photograph of 1500 x 1000 pixels in a 900 x 600 window: the fit is
/// exact, so a screen pixel is 1.667 image pixels and the arithmetic below can
/// be read by hand.
void main() {
  const imageSize = Size(1500, 1000);
  const viewport = Size(900, 600);

  ViewTransform view({Matrix4? matrix, bool obscura = false}) => ViewTransform(
        imageSize: imageSize,
        viewport: viewport,
        matrix: matrix,
        obscura: obscura,
      );

  LayerFrame frameOf(
    LayerPlacement placement, {
    Matrix4? matrix,
    bool obscura = false,
  }) =>
      LayerFrame(
        placement: placement,
        transform: view(matrix: matrix, obscura: obscura),
      );

  const full = LayerPlacement(localId: 1, patternCode: 'rule-of-thirds');

  group('screen and layer space', () {
    test('a full-frame layer covers the fitted photograph', () {
      final frame = frameOf(full);

      expect(frame.localToScreen(Offset.zero), const Offset(0, 0));
      expect(frame.localToScreen(const Offset(1, 1)), const Offset(900, 600));
      expect(frame.localToScreen(const Offset(0.5, 0.5)), const Offset(450, 300));
    });

    test('round-trips a point at fit and at 100 %', () {
      for (final matrix in [null, Matrix4.identity()..scaleByDouble(3, 3, 1, 1)]) {
        final frame = frameOf(full, matrix: matrix);
        const local = Offset(0.31, 0.72);
        final back = frame.screenToLocal(frame.localToScreen(local))!;

        expect(back.dx, closeTo(local.dx, 1e-9));
        expect(back.dy, closeTo(local.dy, 1e-9));
      }
    });

    test('a half-size layer sits where it was placed', () {
      const half = LayerPlacement(
        localId: 1,
        patternCode: 'rule-of-thirds',
        position: Offset(0.25, 0.5),
        scaleX: 0.5,
        scaleY: 0.5,
      );
      final frame = frameOf(half);

      // A quarter of the way across, half the frame wide: from 0 to 0.5 of the
      // photograph, which is 0 to 450 on screen.
      expect(frame.localToScreen(Offset.zero).dx, closeTo(0, 1e-9));
      expect(frame.localToScreen(const Offset(1, 0)).dx, closeTo(450, 1e-9));
    });

    test('a degenerate viewport gives no hit rather than a false one', () {
      final frame = LayerFrame(
        placement: full,
        transform: const ViewTransform(imageSize: imageSize, viewport: Size.zero),
      );

      expect(frame.screenToLocal(const Offset(10, 10)), isNull);
      expect(frame.hitTest(const Offset(10, 10)), isNull);
    });
  });

  group('hit testing', () {
    test('finds all four corners', () {
      final frame = frameOf(full);

      for (final handle in GuideHandle.corners) {
        expect(
          frame.hitTest(frame.localToScreen(handle.local)),
          handle,
          reason: handle.name,
        );
      }
      expect(frame.hitTest(const Offset(450, 300)), GuideHandle.body);
      // Outside the layer entirely: the canvas hands the drag back to the
      // viewer's own pan rather than swallowing it.
      expect(frame.hitTest(const Offset(-40, -40)), isNull);
    });

    test('finds them after the layer has been turned', () {
      const turned = LayerPlacement(
        localId: 1,
        patternCode: 'symmetry',
        scaleX: 0.4,
        scaleY: 0.4,
        rotation: math.pi / 5,
      );
      final frame = frameOf(turned);

      for (final handle in GuideHandle.corners) {
        expect(
          frame.hitTest(frame.localToScreen(handle.local)),
          handle,
          reason: handle.name,
        );
      }
      // The corner has actually moved: a hit test that ignored the rotation
      // would still pass the loop above by being wrong in both directions.
      expect(
        (frame.localToScreen(GuideHandle.topLeft.local) - const Offset(0, 0))
            .distance,
        greaterThan(20),
      );
    });

    test('maps a click to the right handle in obscura mode', () {
      const layer = LayerPlacement(
        localId: 1,
        patternCode: 'golden-spiral',
        position: Offset(0.3, 0.3),
        scaleX: 0.4,
        scaleY: 0.4,
      );
      final upright = frameOf(layer);
      final flipped = frameOf(layer, obscura: true);

      // The photograph is upside down, so the layer's top-left corner is now at
      // the bottom right of the window -- and clicking there must still be the
      // top-left corner of the guide, because that is the corner the stored
      // transform will move.
      final where = flipped.localToScreen(GuideHandle.topLeft.local);
      expect(flipped.hitTest(where), GuideHandle.topLeft);
      expect(
        where,
        isNot(upright.localToScreen(GuideHandle.topLeft.local)),
      );
      expect(where.dx, closeTo(900 - upright.localToScreen(Offset.zero).dx, 1e-9));
    });
  });

  group('dragging', () {
    test('the body moves the layer and changes nothing else', () {
      const layer = LayerPlacement(
        localId: 1,
        patternCode: 'rule-of-thirds',
        scaleX: 0.5,
        scaleY: 0.5,
      );
      final moved = frameOf(layer)
          .moved(const Offset(450, 300), const Offset(540, 240));

      // 90 screen pixels of 900 is a tenth of the frame; 60 of 600 is a tenth.
      expect(moved.position.dx, closeTo(0.6, 1e-9));
      expect(moved.position.dy, closeTo(0.4, 1e-9));
      expect(moved.scaleX, layer.scaleX);
      expect(moved.scaleY, layer.scaleY);
      expect(moved.rotation, layer.rotation);
    });

    test('the body follows the pointer the same way under obscura', () {
      const layer = LayerPlacement(
        localId: 1,
        patternCode: 'rule-of-thirds',
        scaleX: 0.5,
        scaleY: 0.5,
      );
      final moved = frameOf(layer, obscura: true)
          .moved(const Offset(450, 300), const Offset(540, 240));

      // Dragging right on an upside-down photograph moves the guide left in the
      // photograph's own coordinates. The guide still tracks the pointer, which
      // is what the user sees, and the stored number is the honest one.
      expect(moved.position.dx, closeTo(0.4, 1e-9));
      expect(moved.position.dy, closeTo(0.6, 1e-9));
    });

    test('a corner scales the layer and moves only its centre', () {
      const layer = LayerPlacement(
        localId: 1,
        patternCode: 'rule-of-thirds',
        scaleX: 0.5,
        scaleY: 0.5,
      );
      final frame = frameOf(layer);
      // The layer covers 0.25..0.75 of the frame: on screen, 225..675 across
      // and 150..450 down. Drag its top-left corner to the middle of that.
      final resized = frame.resized(GuideHandle.topLeft, const Offset(450, 300));

      expect(resized.scaleX, closeTo(0.25, 1e-9));
      expect(resized.scaleY, closeTo(0.25, 1e-9));
      expect(resized.rotation, layer.rotation);
      // The opposite corner stayed put, so the centre moved half as far.
      expect(resized.position.dx, closeTo(0.625, 1e-9));
      expect(resized.position.dy, closeTo(0.625, 1e-9));
    });

    test('a corner keeps the proportions unless the modifier is held', () {
      const layer = LayerPlacement(localId: 1, patternCode: 'golden-spiral');
      final frame = frameOf(layer);

      // A pointer that has moved further in x than in y.
      final locked = frame.resized(GuideHandle.topLeft, const Offset(300, 60));
      expect(locked.scaleX, closeTo(locked.scaleY, 1e-9));

      final free = frame.resized(
        GuideHandle.topLeft,
        const Offset(300, 60),
        free: true,
      );
      expect(free.scaleX, isNot(closeTo(free.scaleY, 1e-6)));
      expect(free.scaleX, closeTo(2 / 3, 1e-9));
      expect(free.scaleY, closeTo(0.9, 1e-9));
    });

    test('a corner dragged past its anchor stops instead of inverting', () {
      const layer = LayerPlacement(localId: 1, patternCode: 'rule-of-thirds');
      final resized = frameOf(layer)
          .resized(GuideHandle.topLeft, const Offset(1400, 900));

      expect(resized.scaleX, LayerPlacement.minScale);
      expect(resized.scaleY, LayerPlacement.minScale);
    });

    test('a locked layer refuses both', () {
      const locked = LayerPlacement(
        localId: 1,
        patternCode: 'rule-of-thirds',
        locked: true,
      );
      final frame = frameOf(locked);

      expect(frame.moved(const Offset(450, 300), const Offset(600, 300)), locked);
      expect(frame.resized(GuideHandle.topLeft, const Offset(450, 300)), locked);
    });
  });
}
