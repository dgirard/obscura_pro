import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/infra/geometry/view_transform.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

void main() {
  /// A 3:2 frame in a viewport wider than it is tall, so fitting leaves bars at
  /// the sides — the ordinary case for a landscape Q3 frame in a window.
  ViewTransform fitted({bool obscura = false, Matrix4? matrix}) => ViewTransform(
        imageSize: const Size(6000, 4000),
        viewport: const Size(1000, 600),
        matrix: matrix,
        obscura: obscura,
      );

  group('fitting the photograph', () {
    test('scales to the tighter axis and centres what is left', () {
      final t = fitted();

      // Height binds: 600/4000 is smaller than 1000/6000.
      expect(t.fitScale, closeTo(0.15, 1e-12));
      expect(t.fittedRect, const Rect.fromLTWH(50, 0, 900, 600));
    });

    test('survives a viewport of no size', () {
      // Happens for a frame during a window resize. Dividing by it would poison
      // every coordinate downstream, so it degrades rather than throwing.
      const t = ViewTransform(
        imageSize: Size(6000, 4000),
        viewport: Size.zero,
      );

      expect(t.fitScale, 0);
      expect(t.screenToNormalized(const Offset(10, 10)), Offset.zero);
    });

    test('knows the zoom at which pixels are actual pixels', () {
      final t = fitted();

      // At fit, one image pixel is 0.15 logical pixels. On a 2x display, one
      // image pixel per device pixel means 0.5 logical, so zoom is 1/(0.15*2).
      expect(t.zoomForActualPixels(2), closeTo(1 / 0.3, 1e-12));
      expect(t.pixelScale, closeTo(0.15, 1e-12));
    });
  });

  group('screen and normalized round-trip', () {
    // The four combinations the whole coordinate stack rests on. Every one of
    // them is a case where a crop handle could drift away from the pointer.
    final cases = <String, ViewTransform>{
      'fit': fitted(),
      'fit, obscura': fitted(obscura: true),
      'zoomed and panned': fitted(
        matrix: Matrix4.identity()
          ..translateByDouble(-300, -220, 0, 1)
          ..scaleByDouble(3.5, 3.5, 1, 1),
      ),
      'zoomed and panned, obscura': fitted(
        obscura: true,
        matrix: Matrix4.identity()
          ..translateByDouble(-300, -220, 0, 1)
          ..scaleByDouble(3.5, 3.5, 1, 1),
      ),
    };

    for (final entry in cases.entries) {
      test('is exact under ${entry.key}', () {
        final t = entry.value;
        for (final point in const [
          Offset(0, 0),
          Offset(1, 1),
          Offset(0.5, 0.5),
          Offset(0.13, 0.87),
          // Outside the frame: a crop drag that leaves the photograph still has
          // to know by how much.
          Offset(-0.2, 1.4),
        ]) {
          final screen = t.normalizedToScreen(point);
          final back = t.screenToNormalized(screen);
          expect(back.dx, closeTo(point.dx, 1e-9), reason: '$point x');
          expect(back.dy, closeTo(point.dy, 1e-9), reason: '$point y');
        }
      });
    }
  });

  group('obscura', () {
    test('turns the photograph half a turn, it does not mirror it', () {
      final upright = fitted();
      final turned = fitted(obscura: true);

      // The top-left of the picture lands where the bottom-right of the
      // untouched one was. A mirror would move one axis and leave the other.
      expect(
        turned.normalizedToScreen(const Offset(0, 0)),
        upright.normalizedToScreen(const Offset(1, 1)),
      );
      expect(
        turned.normalizedToScreen(const Offset(1, 0)),
        upright.normalizedToScreen(const Offset(0, 1)),
      );
    });

    test('leaves the centre where it was', () {
      expect(
        fitted(obscura: true).normalizedToScreen(const Offset(0.5, 0.5)),
        fitted().normalizedToScreen(const Offset(0.5, 0.5)),
      );
    });

    test('changes nothing about the fitted rectangle', () {
      // A 180-degree turn does not swap the axes, so the frame on screen is the
      // same frame. Anything else would mean the picture jumped when toggled.
      expect(fitted(obscura: true).fittedRect, fitted().fittedRect);
    });

    test('keeps a rectangle a rectangle, right way up', () {
      final normalized = const Rect.fromLTRB(0.2, 0.1, 0.6, 0.4);
      final screen = fitted(obscura: true).screenRectOf(normalized);

      // Under obscura the stored top-left maps to the on-screen bottom-right;
      // assembling from origin-plus-size would give an inside-out rectangle
      // whose width was negative.
      expect(screen.width, greaterThan(0));
      expect(screen.height, greaterThan(0));
      expect(
        screen,
        fitted().screenRectOf(const Rect.fromLTRB(0.4, 0.6, 0.8, 0.9)),
      );
    });
  });

  group('zooming around a point', () {
    test('holds the point under the cursor still', () {
      final t = fitted();
      const cursor = Offset(720, 180);
      final before = t.screenToNormalized(cursor);

      final zoomed = t.copyWith(matrix: t.zoomedAround(cursor, 4));

      expect(zoomed.zoom, closeTo(4, 1e-9));
      final after = zoomed.screenToNormalized(cursor);
      expect(after.dx, closeTo(before.dx, 1e-9));
      expect(after.dy, closeTo(before.dy, 1e-9));
    });

    test('holds it still under obscura too', () {
      // The case worth having a test for: the rotation is applied after the
      // matrix, so a chain that got the order wrong would zoom towards the
      // point diagonally opposite the cursor.
      final t = fitted(obscura: true);
      const cursor = Offset(300, 500);
      final before = t.screenToNormalized(cursor);

      final zoomed = t.copyWith(matrix: t.zoomedAround(cursor, 2.5));

      final after = zoomed.screenToNormalized(cursor);
      expect(after.dx, closeTo(before.dx, 1e-9));
      expect(after.dy, closeTo(before.dy, 1e-9));
    });

    test('zooming from a zoomed state compounds around the new point', () {
      final t = fitted(matrix: Matrix4.identity()..scaleByDouble(2, 2, 1, 1));
      const cursor = Offset(400, 300);
      final before = t.screenToNormalized(cursor);

      final zoomed = t.copyWith(matrix: t.zoomedAround(cursor, 6));

      expect(zoomed.zoom, closeTo(6, 1e-9));
      expect(zoomed.screenToNormalized(cursor).dx, closeTo(before.dx, 1e-9));
    });
  });

  group('a portrait frame', () {
    test('fits by its width and is taller than it is wide', () {
      // The upright size, EXIF orientation already applied — which is the whole
      // reason this class is handed the upright size and not the stored one.
      const t = ViewTransform(
        imageSize: Size(4000, 6000),
        viewport: Size(1000, 600),
      );

      expect(t.fitScale, closeTo(0.1, 1e-12));
      expect(t.fittedRect, const Rect.fromLTWH(300, 0, 400, 600));
    });
  });

  test('containsNormalized marks the frame boundary as inside', () {
    expect(ViewTransform.containsNormalized(const Offset(0, 0)), isTrue);
    expect(ViewTransform.containsNormalized(const Offset(1, 1)), isTrue);
    expect(ViewTransform.containsNormalized(const Offset(1.0001, 0.5)), isFalse);
    expect(ViewTransform.containsNormalized(const Offset(0.5, -0.0001)), isFalse);
  });

  test('reports the zoom the matrix carries', () {
    final t = fitted(
      matrix: Matrix4.identity()..scaleByDouble(math.sqrt2, math.sqrt2, 1, 1),
    );

    expect(t.zoom, closeTo(math.sqrt2, 1e-12));
  });
}
