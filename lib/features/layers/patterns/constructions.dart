/// The geometry of the fifteen guides, built from the frame they go onto.
///
/// The plan expected `tool/extract_patterns.dart` to lift these shapes out of
/// the Grammaire's inline SVGs. It cannot: those are teaching diagrams drawn
/// around a blue blob standing in for a subject, and half of them mark three
/// points of force because the fourth is under the blob. So the constructions
/// are written here, from the definitions, and `patterns_test.dart` pins each
/// one back to the coordinates the document draws. Verified against the source
/// beats copied from it.
///
/// **Local space.** Everything here is built inside the unit square of the
/// *layer*, `(0,0)` top-left to `(1,1)` bottom-right. At the default placement
/// that square is the whole photograph; once the layer is moved or resized it
/// is the part of it the layer covers. The placement, the obscura flip and the
/// zoom are all applied afterwards, by one matrix, in `layer_painter.dart`.
///
/// **Aspect.** [buildGuide] takes the width-over-height ratio of that square
/// *in pixels*, because five of the fifteen are constructions of the frame's
/// own proportions and a shape baked at 3:2 would be wrong on every other crop
/// (the plan's execution note says so in as many words). The other ten are the
/// same on any frame and ignore it.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'pattern.dart';

/// φ − 1: the short arm of the golden section, and the grid line at 38.2 %.
const double _phiShort = 0.3819660112501051;

/// The guides whose geometry changes with the shape of the frame.
///
/// Named rather than inferred so the test can walk exactly this set and check
/// that each one *does* move between 3:2 and 1:1 — and, just as usefully, that
/// the other ten do not.
const Set<String> parametricGuides = {
  'golden-spiral',
  'rabatment',
  'dynamic-symmetry-hambidge',
  'diagonal-method-westhoff',
  'golden-triangle',
};

/// The drawable geometry of [code], for a layer whose pixel aspect is [aspect].
///
/// Returns empty for a [PatternKind.reference] pattern: those have no
/// construction to draw, which is the whole distinction [PatternKind] records.
List<GuidePrimitive> buildGuide(String code, {double aspect = 3 / 2}) {
  final a = aspect.isFinite && aspect > 0 ? aspect : 3 / 2;
  return switch (code) {
    'rule-of-thirds' => _grid(1 / 3, 2 / 3),
    'golden-ratio' => _grid(_phiShort, 1 - _phiShort),
    'golden-spiral' => _goldenSpiral(a),
    'rabatment' => _rabatment(a),
    'dynamic-symmetry-hambidge' => _dynamicSymmetry(a),
    'leading-lines' => _leadingLines(),
    'baroque-sinister-diagonals' => _diagonals(),
    'diagonal-method-westhoff' => _diagonalMethod(a),
    's-curve' => _sCurve(),
    'golden-triangle' => _goldenTriangle(a),
    'triangle' => _triangle(),
    'symmetry' => _symmetry(),
    'center-composition' => _centring(),
    'horizon-placement' => _horizon(),
    'blocking' => _blocking(),
    _ => const [],
  };
}

// --- I. Grilles & rapports ---------------------------------------------------

/// Two verticals, two horizontals, and the four points where they cross.
///
/// One function for the thirds and for the phi grid because they are the same
/// construction at two ratios — which is also what the Grammaire says about
/// them, phi being "plus resserrée vers le centre que les tiers".
List<GuidePrimitive> _grid(double near, double far) => [
      for (final x in [near, far])
        GuideSegment(Offset(x, 0), Offset(x, 1)),
      for (final y in [near, far])
        GuideSegment(Offset(0, y), Offset(1, y)),
      for (final x in [near, far])
        for (final y in [near, far]) GuidePoint(Offset(x, y)),
    ];

/// Whirling squares: cut a square off the frame, arc through it, repeat.
///
/// Built from the frame rather than from a φ rectangle scaled to fit. On a
/// golden frame the two are the same construction — which is why this
/// reproduces the document's own drawing — but on a 1:1 or an XPan they are
/// not, and a spiral whose squares are not the frame's squares is a picture of
/// a spiral rather than a reading of the composition.
///
/// The cut goes left, top, right, bottom and round again, each arc a quarter
/// circle centred on the corner of its square that the next square touches.
/// Six turns are drawn — by then the remaining square is under a thousandth of
/// the frame — and the cutting is carried on silently to find the eye, which is
/// the limit of the sequence rather than the middle of wherever it was stopped.
List<GuidePrimitive> _goldenSpiral(double aspect) {
  const drawnTurns = 6;
  // Pixel-ish space: width `aspect`, height 1, so a square is square.
  var left = 0.0, top = 0.0, right = aspect, bottom = 1.0;
  final out = <GuidePrimitive>[];

  Offset local(double x, double y) => Offset(x / aspect, y);

  for (var turn = 0; turn < 48; turn++) {
    final width = right - left;
    final height = bottom - top;
    if (width <= 1e-12 || height <= 1e-12) break;
    final side = math.min(width, height);

    if (turn >= drawnTurns) {
      switch (turn % 4) {
        case 0:
          left += side;
        case 1:
          top += side;
        case 2:
          right -= side;
        default:
          bottom -= side;
      }
      continue;
    }

    // The corner the arc turns around, the angle it starts at, and the cut that
    // separates this square from what is left of the frame.
    final (Offset centre, double start, Offset cutA, Offset cutB) =
        switch (turn % 4) {
      // Cut from the left: the arc runs from the square's bottom-left to its
      // top-right, around its bottom-right corner.
      0 => (
          local(left + side, bottom),
          math.pi,
          local(left + side, top),
          local(left + side, bottom),
        ),
      // From the top: top-left to bottom-right, around the bottom-left corner.
      1 => (
          local(left, top + side),
          3 * math.pi / 2,
          local(left, top + side),
          local(right, top + side),
        ),
      // From the right: top-right to bottom-left, around the top-left corner.
      2 => (
          local(right - side, top),
          0,
          local(right - side, top),
          local(right - side, bottom),
        ),
      // From the bottom: bottom-right to top-left, around the top-right corner.
      _ => (
          local(right, bottom - side),
          math.pi / 2,
          local(left, bottom - side),
          local(right, bottom - side),
        ),
    };

    out.add(GuideArc(
      centre: centre,
      radii: Offset(side / aspect, side),
      startAngle: start,
      sweep: math.pi / 2,
    ));
    // The cut itself, dashed: it is the scaffolding that produced the arc, and
    // the Grammaire draws it that way.
    out.add(GuideSegment(cutA, cutB, dashed: true));

    switch (turn % 4) {
      case 0:
        left += side;
      case 1:
        top += side;
      case 2:
        right -= side;
      default:
        bottom -= side;
    }
  }

  // The eye: where the cuts converge. On a golden frame it lands at about
  // (0.72, 0.72), inside the last square the spiral draws — the document's own
  // circle sits a little outside its own last square, which is a hand-placed
  // marker rather than a construction.
  out.add(GuidePoint(local((left + right) / 2, (top + bottom) / 2)));
  return out;
}

/// The two squares a rectangle contains, folded in from each end.
///
/// On a 3:2 frame the fold lines coincide with the vertical thirds, which is
/// the coincidence the Grammaire points out. On a square there is nothing to
/// fold and the construction is empty rather than a pair of lines drawn on top
/// of the frame's own edges.
List<GuidePrimitive> _rabatment(double aspect) {
  final out = <GuidePrimitive>[];
  if ((aspect - 1).abs() < 1e-9) return out;

  if (aspect > 1) {
    final side = 1 / aspect; // The square's side, as a fraction of the width.
    out
      ..add(GuideSegment(Offset(side, 0), Offset(side, 1)))
      ..add(GuideSegment(Offset(1 - side, 0), Offset(1 - side, 1)))
      // The swing that produces the fold: the short side rotated about the
      // inner corner of the square until it lies along the long one.
      ..add(GuideArc(
        centre: Offset(side, 1),
        radii: Offset(side, 1),
        startAngle: 3 * math.pi / 2,
        sweep: -math.pi / 2,
        dashed: true,
      ));
  } else {
    final side = aspect; // Portrait: the square's side as a fraction of height.
    out
      ..add(GuideSegment(Offset(0, side), Offset(1, side)))
      ..add(GuideSegment(Offset(0, 1 - side), Offset(1, 1 - side)))
      ..add(GuideArc(
        centre: Offset(1, side),
        radii: Offset(1, side),
        startAngle: math.pi,
        sweep: math.pi / 2,
        dashed: true,
      ));
  }
  return out;
}

/// Hambidge's armature: the two diagonals, the four reciprocals, and the eyes.
///
/// A reciprocal is the perpendicular dropped from a corner onto the diagonal it
/// does not touch, run on to the far edge. Where it meets that diagonal is an
/// "eye of the rectangle" — and the whole point of the system is that those
/// four points are properties of the frame's proportions, so they are computed
/// from [aspect] and never tabulated.
List<GuidePrimitive> _dynamicSymmetry(double aspect) {
  final a2 = aspect * aspect;
  final near = 1 / (1 + a2);
  final far = a2 / (1 + a2);

  return [
    GuideSegment(const Offset(0, 0), const Offset(1, 1)),
    GuideSegment(const Offset(0, 1), const Offset(1, 0)),
    // Each reciprocal starts at a corner. The perpendicular to the diagonal
    // `(-w,h)` is `(h,w)` in pixels, which in the layer's own units — x over w,
    // y over h — is `(1/a, a)`. Writing that `(1/a, 1)` is the mistake this
    // construction is most likely to contain, and it looks right on a square.
    for (final (corner, direction) in [
      (const Offset(0, 0), Offset(1 / aspect, aspect)),
      (const Offset(1, 0), Offset(-1 / aspect, aspect)),
      (const Offset(0, 1), Offset(1 / aspect, -aspect)),
      (const Offset(1, 1), Offset(-1 / aspect, -aspect)),
    ])
      GuideSegment(corner, _exit(corner, direction), dashed: true),
    GuidePoint(Offset(near, far)),
    GuidePoint(Offset(far, near)),
    GuidePoint(Offset(near, near)),
    GuidePoint(Offset(far, far)),
  ];
}

// --- II. Lignes & directions -------------------------------------------------

/// Eight rays meeting at the layer's centre.
///
/// The Grammaire draws three lines converging on a subject at two-thirds
/// across; a photograph has its own lines and its own subject, so what is
/// placeable is the hub. Put it on the subject and see whether the road, the
/// rail and the shadow run along a ray.
List<GuidePrimitive> _leadingLines() {
  const hub = Offset(0.5, 0.5);
  return [
    for (final edge in const [
      Offset(0, 0),
      Offset(0.5, 0),
      Offset(1, 0),
      Offset(1, 0.5),
      Offset(1, 1),
      Offset(0.5, 1),
      Offset(0, 1),
      Offset(0, 0.5),
    ])
      GuideSegment(edge, hub),
    const GuidePoint(hub),
  ];
}

/// The frame's own two diagonals.
///
/// The document colours them apart — baroque rising, sinistre falling — and
/// this cannot: the stroke colour belongs to the user, who picks one that shows
/// against their photograph. Two lines, and the reading of them stays in the
/// card.
List<GuidePrimitive> _diagonals() => const [
      GuideSegment(Offset(0, 1), Offset(1, 0)),
      GuideSegment(Offset(0, 0), Offset(1, 1)),
    ];

/// Westhoff's method: a true 45° line from each corner.
///
/// True 45° *in pixels*, which is the entire content of the method and the
/// reason it is not the diagonals — on any frame that is not square the two
/// differ, and on a 3:2 the difference is what places the subject.
List<GuidePrimitive> _diagonalMethod(double aspect) {
  // The run of a 45° line before it meets the far edge, in local units.
  final (dx, dy) = aspect >= 1 ? (1 / aspect, 1.0) : (1.0, aspect);
  return [
    GuideSegment(const Offset(0, 0), Offset(dx, dy)),
    GuideSegment(const Offset(1, 0), Offset(1 - dx, dy)),
    GuideSegment(const Offset(0, 1), Offset(dx, 1 - dy)),
    GuideSegment(const Offset(1, 1), Offset(1 - dx, 1 - dy)),
  ];
}

/// The S, transcribed from the document's own curve.
///
/// Aspect-independent on purpose: an S drawn on a panorama should stretch with
/// it, because what it describes is a path across the frame rather than a
/// shape with a size of its own.
List<GuidePrimitive> _sCurve() => const [
      GuideCubic(
        start: Offset(0.433, 1),
        control1: Offset(0.183, 0.79),
        control2: Offset(0.783, 0.66),
        end: Offset(0.527, 0.48),
      ),
      GuideCubic(
        start: Offset(0.527, 0.48),
        control1: Offset(0.32, 0.33),
        control2: Offset(0.653, 0.19),
        end: Offset(0.5, 0),
      ),
    ];

// --- III. Formes & équilibre -------------------------------------------------

/// One diagonal and the two perpendiculars dropped onto it.
///
/// The feet of those perpendiculars are the triangle's two points of interest,
/// and like the armature's eyes they are a function of the frame: at 3:2 they
/// land at 0.308/0.692, which is what the document draws.
List<GuidePrimitive> _goldenTriangle(double aspect) {
  final a2 = aspect * aspect;
  final near = 1 / (1 + a2);
  final far = a2 / (1 + a2);
  final footA = Offset(near, far); // From the top-left corner.
  final footB = Offset(far, near); // From the bottom-right corner.

  return [
    GuideSegment(const Offset(0, 1), const Offset(1, 0)),
    GuideSegment(const Offset(0, 0), footA),
    GuideSegment(const Offset(1, 1), footB),
    GuidePoint(footA),
    GuidePoint(footB),
  ];
}

/// The classical triangle, seated on its base.
List<GuidePrimitive> _triangle() => const [
      GuidePolyline(
        [Offset(0.5, 0.19), Offset(0.207, 0.84), Offset(0.793, 0.84)],
        closed: true,
        dashed: true,
      ),
      GuidePoint(Offset(0.5, 0.19)),
      GuidePoint(Offset(0.207, 0.84)),
      GuidePoint(Offset(0.793, 0.84)),
    ];

/// The mirror axis.
///
/// Vertical, and rotatable like every other layer: a horizontal symmetry is the
/// same construction a quarter turn round, and two patterns for one axis would
/// be two things to keep in step.
List<GuidePrimitive> _symmetry() => const [
      GuideSegment(Offset(0.5, 0), Offset(0.5, 1), dashed: true),
      GuidePoint(Offset(0.5, 0.5)),
    ];

/// Centre cross and the ring that says how far off centre is still centred.
List<GuidePrimitive> _centring() => const [
      GuideSegment(Offset(0.5, 0.43), Offset(0.5, 0.57)),
      GuideSegment(Offset(0.43, 0.5), Offset(0.57, 0.5)),
      GuideCircle(centre: Offset(0.5, 0.5), radius: 0.17, dashed: true),
      GuidePoint(Offset(0.5, 0.5)),
    ];

// --- IV. Espace & profondeur, VII. Cinéma ------------------------------------

/// The two horizons that are a decision, and the one that is a default.
///
/// The middle line is dashed because the Grammaire is explicit that the centre
/// is a choice about reflection and formality, never the place an horizon ends
/// up for want of choosing.
List<GuidePrimitive> _horizon() => const [
      GuideSegment(Offset(0, 1 / 3), Offset(1, 1 / 3)),
      GuideSegment(Offset(0, 2 / 3), Offset(1, 2 / 3)),
      GuideSegment(Offset(0, 0.5), Offset(1, 0.5), dashed: true),
    ];

/// The camera's axis and its field, seen from above.
///
/// The document's schema is a plan view — the camera at the bottom, the staging
/// depths in front of it. Laid over a photograph it reads as the frontality
/// check it is: the axis on the centre of symmetry, the cone on what the
/// staging is supposed to fill.
List<GuidePrimitive> _blocking() => const [
      GuideSegment(Offset(0.5, 0), Offset(0.5, 1)),
      GuideSegment(Offset(0.5, 0.93), Offset(0.207, 0.15), dashed: true),
      GuideSegment(Offset(0.5, 0.93), Offset(0.793, 0.15), dashed: true),
      GuidePoint(Offset(0.5, 0.65)),
      GuidePoint(Offset(0.373, 0.44)),
      GuidePoint(Offset(0.627, 0.44)),
      GuidePoint(Offset(0.5, 0.26)),
    ];

// --- Plumbing ----------------------------------------------------------------

/// Where a ray leaving [from] in [direction] crosses the unit square.
///
/// Clipped rather than tabulated because a reciprocal leaves through the bottom
/// edge on a landscape frame and through the side on a portrait one, and a
/// construction that assumed either would draw outside the picture on half the
/// crops this app offers.
Offset _exit(Offset from, Offset direction) {
  var t = double.infinity;
  for (final (component, delta) in [
    (from.dx, direction.dx),
    (from.dy, direction.dy),
  ]) {
    if (delta.abs() < 1e-12) continue;
    final hit = ((delta > 0 ? 1.0 : 0.0) - component) / delta;
    if (hit > 0 && hit < t) t = hit;
  }
  if (!t.isFinite) return from;
  return Offset(from.dx + direction.dx * t, from.dy + direction.dy * t);
}
