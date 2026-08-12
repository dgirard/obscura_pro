import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/layers/patterns/constructions.dart';
import 'package:obscura_pro/features/layers/patterns/pattern_library.dart';

/// U12. The library is generated; the geometry is not, and this is where the
/// two are held to the document.
///
/// Every construction below is checked against the coordinates
/// `docs/reference/grammaire-du-cadre.html` draws in its own schema, converted
/// out of that schema's viewBox. The document's numbers are hand-rounded to a
/// tenth of a pixel, so the tolerances are a few thousandths of the frame --
/// tight enough that a wrong construction fails, loose enough that a rounded
/// one does not.
void main() {
  group('the generated library', () {
    test('is the document\'s thirty patterns, in its order', () {
      expect(grammairePatterns, hasLength(30));
      expect(
        grammairePatterns.map((p) => p.number),
        List.generate(30, (i) => i + 1),
      );
      expect(grammairePatterns.map((p) => p.code).toSet(), hasLength(30));
    });

    test('has every section of the document filled', () {
      for (final category in PatternCategory.values) {
        expect(patternsByCategory[category], isNotEmpty, reason: category.label);
      }
    });

    test('splits into fifteen placeable guides and fifteen cards', () {
      expect(placeableGuides, hasLength(15));
      expect(
        grammairePatterns.where((p) => p.kind == PatternKind.reference),
        hasLength(15),
      );
    });

    test('carries the three fields every card of the document has', () {
      for (final pattern in grammairePatterns) {
        expect(pattern.definition, isNotEmpty, reason: pattern.code);
        expect(pattern.recognise, isNotEmpty, reason: pattern.code);
        expect(pattern.effect, isNotEmpty, reason: pattern.code);
      }
    });

    test('finds a pattern by the code a saved layer would name', () {
      expect(patternByCode('golden-spiral')?.number, 3);
      // A code from a later version of the document is a miss, not a crash: the
      // panel has to be able to say "unknown guide" over someone's saved
      // composition rather than take the composition down with it.
      expect(patternByCode('no-such-pattern'), isNull);
    });
  });

  group('what has a construction and what does not', () {
    test('every guide draws something', () {
      for (final guide in placeableGuides) {
        expect(
          buildGuide(guide.code),
          isNotEmpty,
          reason: '${guide.code} is a guide with no geometry',
        );
      }
    });

    test('no card pretends to', () {
      for (final pattern in grammairePatterns) {
        if (pattern.isGuide) continue;
        expect(
          buildGuide(pattern.code),
          isEmpty,
          reason: '${pattern.code} is a teaching diagram, not an overlay',
        );
      }
    });

    test('stays inside the frame, at every ratio the app can crop to', () {
      for (final aspect in [3 / 2, 4 / 3, 5 / 4, 1.0, 16 / 9, 65 / 24, 2 / 3]) {
        for (final guide in placeableGuides) {
          for (final point in _coordinatesOf(buildGuide(guide.code, aspect: aspect))) {
            expect(
              point.dx,
              inInclusiveRange(-1e-9, 1 + 1e-9),
              reason: '${guide.code} at $aspect',
            );
            expect(
              point.dy,
              inInclusiveRange(-1e-9, 1 + 1e-9),
              reason: '${guide.code} at $aspect',
            );
          }
        }
      }
    });

    test('a degenerate aspect falls back rather than poisoning the geometry', () {
      // A viewport of no width happens for one frame during a window resize.
      for (final aspect in [0.0, -1.0, double.nan, double.infinity]) {
        final built = buildGuide('golden-spiral', aspect: aspect);
        expect(built, isNotEmpty);
        for (final point in _coordinatesOf(built)) {
          expect(point.dx.isFinite && point.dy.isFinite, isTrue);
        }
      }
    });
  });

  group('the constructions, against the document', () {
    test('rule of thirds: the frame in nine, and four points of force', () {
      final built = buildGuide('rule-of-thirds');
      // The document marks three in red and hides the fourth under its blue
      // subject. Four is what the rule says, and four is what gets drawn.
      expect(built.whereType<GuidePoint>(), hasLength(4));
      expect(_verticals(built), _closeTo([1 / 3, 2 / 3]));
      expect(_horizontals(built), _closeTo([1 / 3, 2 / 3]));
    });

    test('phi grid: 0.382 and 0.618, tighter to the centre than the thirds', () {
      final built = buildGuide('golden-ratio');
      // The document labels these lines 0.382 and 0.618 in the schema itself.
      expect(_verticals(built), _closeTo([0.382, 0.618], 0.001));
      expect(_horizontals(built), _closeTo([0.382, 0.618], 0.001));
      expect(built.whereType<GuidePoint>(), hasLength(4));
    });

    test('golden spiral: the document\'s own subdivisions and eye', () {
      // The document draws the spiral in a 300 x 186 frame -- a golden
      // rectangle to within a rounding -- so its coordinates are the check.
      const phi = 1.618033988749895;
      final built = buildGuide('golden-spiral', aspect: phi);

      // First cut at 185.4/300 = 0.618, the second at 114.6/186 = 0.616 of the
      // height, measured inside the remainder.
      expect(_verticals(built).first, closeTo(185.4 / 300, 0.005));
      expect(_horizontals(built).first, closeTo(114.6 / 186, 0.005));

      // The eye is the limit of the subdivision, so it must lie inside the last
      // square drawn. The document's own pair of concentric circles sits just
      // outside its own last square -- a marker placed by hand rather than
      // constructed -- so it is checked loosely and the geometry tightly.
      // Six quarter turns, each a quarter of a circle in the photograph's own
      // pixels: the radii differ per axis exactly as the frame does.
      final arcs = built.whereType<GuideArc>().toList();
      expect(arcs, hasLength(6));

      final eye = built.whereType<GuidePoint>().single.at;
      final last = arcs.last;
      expect((eye.dx - last.centre.dx).abs(), lessThan(last.radii.dx + 1e-6));
      expect((eye.dy - last.centre.dy).abs(), lessThan(last.radii.dy + 1e-6));
      expect(eye.dx, closeTo(207 / 300, 0.05));
      expect(eye.dy, closeTo(131 / 186, 0.05));

      for (final arc in arcs) {
        expect(arc.sweep, closeTo(math.pi / 2, 1e-9));
        expect(arc.radii.dx * phi, closeTo(arc.radii.dy, 1e-9));
      }
      // Each turn is smaller than the last by roughly 1/phi.
      for (var i = 1; i < arcs.length; i++) {
        expect(arcs[i].radii.dy, closeTo(arcs[i - 1].radii.dy / phi, 1e-3));
      }
    });

    test('rabatment: the square folded in from each end', () {
      // On a 3:2 frame the folds land on the vertical thirds, which is the
      // coincidence the document points out (its lines are at x=100 and x=200
      // of 300).
      expect(_verticals(buildGuide('rabatment', aspect: 3 / 2)),
          _closeTo([1 / 3, 2 / 3]));
      // On a portrait frame it folds the other way, and the lines are
      // horizontal.
      final portrait = buildGuide('rabatment', aspect: 2 / 3);
      expect(_horizontals(portrait), _closeTo([1 / 3, 2 / 3]));
      expect(_verticals(portrait), isEmpty);
      // A square contains no second square, so there is nothing to draw rather
      // than two lines on top of the frame's own edges.
      expect(buildGuide('rabatment', aspect: 1), isEmpty);
    });

    test('dynamic symmetry: two diagonals, four reciprocals, four eyes', () {
      final built = buildGuide('dynamic-symmetry-hambidge', aspect: 3 / 2);
      final eyes = built.whereType<GuidePoint>().map((p) => p.at).toList();

      expect(eyes, hasLength(4));
      // The document's four red circles, at (92.3, 61.5) and its mirrors in a
      // 300 x 200 schema.
      for (final expected in [
        const Offset(92.3 / 300, 61.5 / 200),
        const Offset(207.7 / 300, 61.5 / 200),
        const Offset(92.3 / 300, 138.5 / 200),
        const Offset(207.7 / 300, 138.5 / 200),
      ]) {
        expect(
          eyes.any((eye) => (eye - expected).distance < 0.002),
          isTrue,
          reason: 'no eye near $expected',
        );
      }

      // The reciprocal from the top-left corner leaves through the bottom edge
      // at 133.3/300, which is where the document ends its line.
      final reciprocal = built
          .whereType<GuideSegment>()
          .firstWhere((s) => s.dashed && s.a == Offset.zero);
      expect(reciprocal.b.dx, closeTo(133.3 / 300, 0.002));
      expect(reciprocal.b.dy, closeTo(1, 1e-9));
    });

    test('dynamic symmetry: a portrait frame sends the reciprocals out the side',
        () {
      // The construction is the same and the exit is not: on a tall frame the
      // perpendicular meets the side before it meets the bottom. A version that
      // assumed the bottom edge would draw outside the picture here.
      final built = buildGuide('dynamic-symmetry-hambidge', aspect: 2 / 3);
      final reciprocal = built
          .whereType<GuideSegment>()
          .firstWhere((s) => s.dashed && s.a == Offset.zero);
      expect(reciprocal.b.dx, closeTo(1, 1e-9));
      expect(reciprocal.b.dy, closeTo((2 / 3) * (2 / 3), 0.002));
    });

    test('diagonal method: 45 degrees in pixels, not corner to corner', () {
      // The document's line runs from (1,1) to (199,199) of a 300 x 200 frame:
      // it stops at the far edge after a run equal to the short side.
      final built = buildGuide('diagonal-method-westhoff', aspect: 3 / 2);
      final fromTopLeft = built
          .whereType<GuideSegment>()
          .firstWhere((s) => s.a == Offset.zero);
      expect(fromTopLeft.b.dx, closeTo(199 / 300, 0.005));
      expect(fromTopLeft.b.dy, closeTo(1, 1e-9));
      expect(built.whereType<GuideSegment>(), hasLength(4));

      // On a square the method and the diagonals coincide, which is the one
      // frame on which they do.
      final square = buildGuide('diagonal-method-westhoff', aspect: 1);
      expect(
        square.whereType<GuideSegment>().first.b,
        const Offset(1, 1),
      );
    });

    test('golden triangle: the diagonal and the feet of its perpendiculars', () {
      final built = buildGuide('golden-triangle', aspect: 3 / 2);
      final feet = built.whereType<GuidePoint>().map((p) => p.at).toList();

      // The document's two red circles, at (92.3, 138.5) and (207.7, 61.5).
      expect(feet, hasLength(2));
      expect((feet[0] - const Offset(92.3 / 300, 138.5 / 200)).distance,
          lessThan(0.002));
      expect((feet[1] - const Offset(207.7 / 300, 61.5 / 200)).distance,
          lessThan(0.002));
    });

    test('centring: a ring that stays round on any frame', () {
      final circle = buildGuide('center-composition').whereType<GuideCircle>().single;
      expect(circle.centre, const Offset(0.5, 0.5));
      // 34 of a 200-tall schema: the radius is a fraction of the short side, so
      // the ring is a circle and not an ellipse on a panorama.
      expect(circle.radius, closeTo(34 / 200, 0.005));
      expect(circle.dashed, isTrue);
    });

    test('horizon: the two thirds solid, the middle one dashed', () {
      final built = buildGuide('horizon-placement');
      expect(_horizontals(built), _closeTo([1 / 3, 0.5, 2 / 3]));
      final middle = built
          .whereType<GuideSegment>()
          .firstWhere((s) => (s.a.dy - 0.5).abs() < 1e-9);
      expect(middle.dashed, isTrue);
    });
  });

  group('which constructions move with the frame', () {
    test('the five that are built from its proportions do', () {
      for (final code in parametricGuides) {
        expect(
          _shapeOf(buildGuide(code, aspect: 3 / 2)),
          isNot(_shapeOf(buildGuide(code, aspect: 1))),
          reason: '$code should be recomputed for the frame it lands on',
        );
      }
    });

    test('the other ten do not', () {
      for (final guide in placeableGuides) {
        if (parametricGuides.contains(guide.code)) continue;
        expect(
          _shapeOf(buildGuide(guide.code, aspect: 3 / 2)),
          _shapeOf(buildGuide(guide.code, aspect: 65 / 24)),
          reason: '${guide.code} claims to be ratio-independent',
        );
      }
    });
  });
}

// --- Reading a construction --------------------------------------------------

/// The x of every vertical line in [built], in order and without duplicates.
List<double> _verticals(List<GuidePrimitive> built) {
  final out = <double>[];
  for (final primitive in built) {
    if (primitive is! GuideSegment) continue;
    if ((primitive.a.dx - primitive.b.dx).abs() > 1e-9) continue;
    if (!out.any((x) => (x - primitive.a.dx).abs() < 1e-6)) out.add(primitive.a.dx);
  }
  return out..sort();
}

List<double> _horizontals(List<GuidePrimitive> built) {
  final out = <double>[];
  for (final primitive in built) {
    if (primitive is! GuideSegment) continue;
    if ((primitive.a.dy - primitive.b.dy).abs() > 1e-9) continue;
    if (!out.any((y) => (y - primitive.a.dy).abs() < 1e-6)) out.add(primitive.a.dy);
  }
  return out..sort();
}

/// Every coordinate a construction names, for the inside-the-frame check.
///
/// An arc's centre rather than its extent: a quarter arc centred on a corner
/// reaches no further than the square it turns inside, and testing
/// `centre + radii` would fail on geometry that is perfectly inside the frame.
List<Offset> _coordinatesOf(List<GuidePrimitive> built) => [
      for (final primitive in built)
        ...switch (primitive) {
          GuideSegment(:final a, :final b) => [a, b],
          GuidePolyline(:final points) => points,
          GuideCubic(:final start, :final control1, :final control2, :final end) =>
            [start, control1, control2, end],
          GuideArc(:final centre) => [centre],
          GuideCircle(:final centre) => [centre],
          GuidePoint(:final at) => [at],
        },
    ];

/// A construction's coordinates, rounded, as one comparable string.
String _shapeOf(List<GuidePrimitive> built) => _coordinatesOf(built)
    .map((o) => '${o.dx.toStringAsFixed(4)},${o.dy.toStringAsFixed(4)}')
    .join(' ');

Matcher _closeTo(List<double> expected, [double epsilon = 0.005]) => pairwiseCompare<double, double>(
      expected,
      (e, actual) => (e - actual).abs() < epsilon,
      'within $epsilon of $expected',
    );
