import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/crop/ratio.dart';

void main() {
  group('the permitted ratios', () {
    test('are exactly the six the spec names, in the order of the keys', () {
      expect(
        CropRatio.values.map((r) => r.label),
        ['3:2', '4:3', '5:4', '1:1', '16:9', '65:24'],
      );
      // Bound to 1..6 in that order, which is what the keyboard table promises.
      expect(CropRatio.forKeyIndex(0), CropRatio.threeTwo);
      expect(CropRatio.forKeyIndex(5), CropRatio.xpan);
      expect(CropRatio.forKeyIndex(6), isNull);
    });

    test('every one has both orientations except the square', () {
      for (final ratio in CropRatio.values) {
        expect(
          ratio.hasOrientations,
          ratio != CropRatio.square,
          reason: ratio.label,
        );
      }
      // Offering a portrait toggle on a square would be a control that does
      // nothing, which is worse than no control.
      expect(
        CropRatio.square.aspectIn(CropOrientation.portrait),
        CropRatio.square.aspectIn(CropOrientation.landscape),
      );
    });

    test('turning a frame inverts its ratio', () {
      expect(CropRatio.threeTwo.aspectIn(CropOrientation.landscape), closeTo(1.5, 1e-12));
      expect(CropRatio.threeTwo.aspectIn(CropOrientation.portrait), closeTo(2 / 3, 1e-12));
    });

    test('gives each ratio a filename-safe form', () {
      expect(CropRatio.threeTwo.slug, '3x2');
      expect(CropRatio.xpan.slug, '65x24');
      // A colon is a path separator in some places and a legend of confusion in
      // the rest, so it never reaches a filename.
      expect(CropRatio.values.every((r) => !r.slug.contains(':')), isTrue);
    });
  });

  group('the largest crop that fits', () {
    // A Q3 frame, upright.
    const landscapeFrame = 3 / 2;
    const portraitFrame = 2 / 3;

    test('fills the width when the crop is wider than the photograph', () {
      final crop = CropRect.largestIn(
        frameAspect: landscapeFrame,
        ratio: CropRatio.xpan,
      );

      // 65:24 is far wider than 3:2, so the width binds and the crop is a band
      // across the middle.
      expect(crop.rect.width, 1);
      expect(crop.rect.height, closeTo(1.5 / (65 / 24), 1e-12));
      expect(crop.rect.center.dx, closeTo(0.5, 1e-12));
      expect(crop.rect.center.dy, closeTo(0.5, 1e-12));
    });

    test('accounts for normalized space not being square', () {
      final crop = CropRect.largestIn(
        frameAspect: landscapeFrame,
        ratio: CropRatio.square,
      );

      // A square crop of a 3:2 photograph is 2/3 of its width and all of its
      // height. Forgetting that normalized space is stretched is the classic
      // way to produce a crop that is subtly the wrong shape.
      expect(crop.rect.width, closeTo(2 / 3, 1e-12));
      expect(crop.rect.height, 1);
    });

    test('does the same for a portrait photograph', () {
      final crop = CropRect.largestIn(
        frameAspect: portraitFrame,
        ratio: CropRatio.square,
      );

      expect(crop.rect.width, 1);
      expect(crop.rect.height, closeTo(2 / 3, 1e-12));
    });

    test('a crop matching the frame fills it entirely', () {
      final crop = CropRect.largestIn(
        frameAspect: landscapeFrame,
        ratio: CropRatio.threeTwo,
      );

      expect(crop.rect, const Rect.fromLTWH(0, 0, 1, 1));
    });

    test('survives a frame of no aspect at all', () {
      // A photograph whose preview declared no dimensions. The crop degrades to
      // the whole frame rather than producing a rectangle of NaN.
      final crop = CropRect.largestIn(frameAspect: 0, ratio: CropRatio.threeTwo);

      expect(crop.rect, const Rect.fromLTWH(0, 0, 1, 1));
    });
  });

  group('turning and changing the frame', () {
    const frame = 3 / 2;

    test('turning swaps which axis binds', () {
      final landscape =
          CropRect.largestIn(frameAspect: frame, ratio: CropRatio.fourThree);
      final portrait = landscape.turned(frameAspect: frame);

      // Compared as they will look, not as they are stored. In normalized
      // space a landscape 4:3 crop of a 3:2 frame is 0.89 wide by 1.0 tall —
      // taller than it is wide, and still landscape. Reading those numbers as
      // proportions is the mistake this whole class is shaped to avoid.
      double visualAspect(CropRect c) => c.rect.width * frame / c.rect.height;

      expect(portrait.orientation, CropOrientation.portrait);
      expect(visualAspect(landscape), closeTo(4 / 3, 1e-12));
      expect(visualAspect(portrait), closeTo(3 / 4, 1e-12));
    });

    test('turning twice comes back to where it started', () {
      final start =
          CropRect.largestIn(frameAspect: frame, ratio: CropRatio.sixteenNine);

      expect(
        start.turned(frameAspect: frame).turned(frameAspect: frame),
        start,
      );
    });

    test('turning a square does nothing at all', () {
      final square =
          CropRect.largestIn(frameAspect: frame, ratio: CropRatio.square);

      expect(square.turned(frameAspect: frame), square);
    });

    test('changing ratio while portrait stays portrait', () {
      final portrait =
          CropRect.largestIn(frameAspect: frame, ratio: CropRatio.threeTwo)
              .turned(frameAspect: frame);

      final changed = portrait.withRatio(CropRatio.fiveFour, frameAspect: frame);

      expect(changed.orientation, CropOrientation.portrait);
    });

    test('changing to the square drops the orientation rather than keeping a lie',
        () {
      final portrait =
          CropRect.largestIn(frameAspect: frame, ratio: CropRatio.threeTwo)
              .turned(frameAspect: frame);

      final square = portrait.withRatio(CropRatio.square, frameAspect: frame);

      expect(square.orientation, CropOrientation.landscape);
    });
  });

  group('normalized to pixels', () {
    test('a full-frame crop is every pixel there is', () {
      const crop = CropRect(
        rect: Rect.fromLTWH(0, 0, 1, 1),
        ratio: CropRatio.threeTwo,
        orientation: CropOrientation.landscape,
      );

      // The Q3's full-size preview. Losing an edge row here means an export
      // that is not quite the photograph.
      expect(
        crop.toPixels(const Size(9520, 6336)),
        const Rect.fromLTRB(0, 0, 9520, 6336),
      );
    });

    test('a rectangle touching an edge exports to that edge', () {
      const crop = CropRect(
        rect: Rect.fromLTWH(0, 0.25, 0.5, 0.5),
        ratio: CropRatio.square,
        orientation: CropOrientation.landscape,
      );

      final pixels = crop.toPixels(const Size(9520, 6336));

      // Rounded outward, so floating-point drift can never eat a row.
      expect(pixels.left, 0);
      expect(pixels.right, 4760);
      expect(pixels.top, 1584);
      expect(pixels.bottom, 4752);
    });

    test('scales with the image it is applied to, not with any widget', () {
      const crop = CropRect(
        rect: Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
        ratio: CropRatio.square,
        orientation: CropOrientation.landscape,
      );

      // The resolution-loss guard, stated as arithmetic: the same crop against
      // the full-size preview yields eleven times the pixels it does against a
      // display-sized one. Exporting from the widget's bitmap would throw that
      // away silently.
      expect(crop.toPixels(const Size(9520, 6336)).width, 4760);
      expect(crop.toPixels(const Size(1620, 1080)).width, 810);
    });

    test('never returns an empty rectangle', () {
      const sliver = CropRect(
        rect: Rect.fromLTWH(0.5, 0.5, 0.0000001, 0.0000001),
        ratio: CropRatio.square,
        orientation: CropOrientation.landscape,
      );

      final pixels = sliver.toPixels(const Size(100, 100));

      // A zero-width crop would be an encoder crash rather than a photograph.
      expect(pixels.width, greaterThanOrEqualTo(1));
      expect(pixels.height, greaterThanOrEqualTo(1));
    });
  });

  group('keeping the crop inside the frame', () {
    test('a rectangle dragged past the edge slides back, keeping its size', () {
      const dragged = CropRect(
        rect: Rect.fromLTWH(0.8, -0.3, 0.5, 0.5),
        ratio: CropRatio.square,
        orientation: CropOrientation.landscape,
      );

      final clamped = dragged.clampedToFrame();

      // Slid, not shrunk: a drag that leaves the edge should stop at the edge,
      // not quietly change the shape the user chose.
      expect(clamped.rect.width, 0.5);
      expect(clamped.rect.height, 0.5);
      expect(clamped.rect.left, closeTo(0.5, 1e-12));
      expect(clamped.rect.top, 0);
    });

    test('a rectangle already inside is left alone', () {
      const inside = CropRect(
        rect: Rect.fromLTWH(0.2, 0.2, 0.5, 0.5),
        ratio: CropRatio.square,
        orientation: CropOrientation.landscape,
      );

      expect(inside.clampedToFrame(), inside);
    });
  });

  group('resizing the crop', () {
    // A 3:2 photograph, so normalized space is stretched by 1.5.
    const frame = 3 / 2;

    CropRect square() =>
        CropRect.largestIn(frameAspect: frame, ratio: CropRatio.square);

    /// The shape as it looks on screen, which is the only one the user cares
    /// about — the stored rectangle is stretched and says nothing directly.
    double visualAspect(CropRect c) => c.rect.width * frame / c.rect.height;

    test('dragging a corner keeps the chosen ratio exactly', () {
      final start = square();

      final smaller = start.resizedFrom(
        corner: CropCorner.topLeft,
        // Deliberately off the ratio: the pointer proposes, the ratio decides.
        pointer: const Offset(0.45, 0.1),
        frameAspect: frame,
      );

      expect(visualAspect(smaller), closeTo(1, 1e-9));
      expect(smaller.rect.width, lessThan(start.rect.width));
    });

    test('the opposite corner does not move', () {
      final start = square();
      final anchor = start.rect.bottomRight;

      final resized = start.resizedFrom(
        corner: CropCorner.topLeft,
        pointer: const Offset(0.4, 0.3),
        frameAspect: frame,
      );

      // What makes a resize feel like pulling on a frame rather than sliding
      // one somewhere else.
      expect(resized.rect.right, closeTo(anchor.dx, 1e-9));
      expect(resized.rect.bottom, closeTo(anchor.dy, 1e-9));
    });

    test('every ratio survives a resize', () {
      for (final ratio in CropRatio.values) {
        final start = CropRect.largestIn(frameAspect: frame, ratio: ratio);
        final resized = start.resizedFrom(
          corner: CropCorner.bottomRight,
          pointer: const Offset(0.7, 0.9),
          frameAspect: frame,
        );

        expect(
          visualAspect(resized),
          closeTo(ratio.aspectIn(CropOrientation.landscape), 1e-6),
          reason: ratio.label,
        );
      }
    });

    test('a resize cannot leave the photograph', () {
      final start = square();

      final overshot = start.resizedFrom(
        corner: CropCorner.bottomRight,
        // Far outside the frame, as a fast drag routinely goes.
        pointer: const Offset(4, 4),
        frameAspect: frame,
      );

      expect(overshot.rect.left, greaterThanOrEqualTo(-1e-9));
      expect(overshot.rect.top, greaterThanOrEqualTo(-1e-9));
      expect(overshot.rect.right, lessThanOrEqualTo(1 + 1e-9));
      expect(overshot.rect.bottom, lessThanOrEqualTo(1 + 1e-9));
      expect(visualAspect(overshot), closeTo(1, 1e-6));
    });

    test('a crop dragged to nothing stops at a usable size', () {
      final start = square();

      final tiny = start.resizedFrom(
        corner: CropCorner.topLeft,
        pointer: start.rect.bottomRight,
        frameAspect: frame,
      );

      // A rectangle of zero is an encoder error rather than a photograph, and a
      // user who overshoots should find a small crop, not a broken one.
      expect(tiny.rect.width, greaterThanOrEqualTo(CropRect.minExtent - 1e-9));
      expect(tiny.rect.height, greaterThanOrEqualTo(CropRect.minExtent - 1e-9));
      expect(visualAspect(tiny), closeTo(1, 1e-6));
    });

    test('resizing then exporting yields more than a token of pixels', () {
      final resized = square().resizedFrom(
        corner: CropCorner.topLeft,
        pointer: const Offset(0.4, 0.2),
        frameAspect: frame,
      );

      // The point of resizing at all: a tighter crop of the 60 Mpx preview is
      // still a large photograph.
      final pixels = resized.toPixels(const Size(9520, 6336));
      expect(pixels.width, greaterThan(2000));
    });

    test('a corner knows which one anchors it', () {
      expect(CropCorner.topLeft.opposite, CropCorner.bottomRight);
      expect(CropCorner.bottomLeft.opposite, CropCorner.topRight);
      expect(
        CropCorner.topRight.of(const Rect.fromLTWH(0.1, 0.2, 0.4, 0.4)),
        const Offset(0.5, 0.2),
      );
    });
  });

  group('straightening a horizon', () {
    const frame = 3 / 2;

    double visualAspect(CropRect c) =>
        c.rect.width * CropRect.straightenedAspect(frame, c.angleDegrees) /
        c.rect.height;

    test('a turned frame occupies a larger canvas', () {
      // Turning a rectangle grows its bounding box, and that box — corners and
      // all — is what the export produces.
      expect(CropRect.straightenedAspect(frame, 0), closeTo(frame, 1e-12));
      expect(
        CropRect.straightenedAspect(frame, 10),
        lessThan(frame),
        reason: 'the box grows more in height than in width for a wide frame',
      );
    });

    test('the safe area is the whole frame when nothing is turned', () {
      expect(
        CropRect.safeArea(frameAspect: frame, degrees: 0),
        const Rect.fromLTWH(0, 0, 1, 1),
      );
    });

    test('the safe area shrinks as the angle grows, and stays centred', () {
      var previous = 1.0;
      for (final degrees in [1.0, 3.0, 7.0, 15.0]) {
        final safe = CropRect.safeArea(frameAspect: frame, degrees: degrees);
        final area = safe.width * safe.height;

        expect(area, lessThan(previous), reason: '$degrees deg');
        expect(safe.center.dx, closeTo(0.5, 1e-9));
        expect(safe.center.dy, closeTo(0.5, 1e-9));
        previous = area;
      }
    });

    test('turning one way or the other costs the same', () {
      expect(
        CropRect.safeArea(frameAspect: frame, degrees: -6),
        CropRect.safeArea(frameAspect: frame, degrees: 6),
      );
    });

    test('a straightened crop starts inside the photograph, not the corners',
        () {
      for (final degrees in [-12.0, -4.0, 4.0, 12.0]) {
        final crop = CropRect.largestIn(
          frameAspect: frame,
          ratio: CropRatio.threeTwo,
          angleDegrees: degrees,
        );
        final safe = CropRect.safeArea(frameAspect: frame, degrees: degrees);

        // A crop reaching the empty corners would export a photograph with
        // black wedges in it, which is the whole difficulty of straightening.
        expect(crop.rect.left, greaterThanOrEqualTo(safe.left - 1e-9),
            reason: '$degrees deg');
        expect(crop.rect.right, lessThanOrEqualTo(safe.right + 1e-9),
            reason: '$degrees deg');
        expect(crop.rect.top, greaterThanOrEqualTo(safe.top - 1e-9),
            reason: '$degrees deg');
        expect(crop.rect.bottom, lessThanOrEqualTo(safe.bottom + 1e-9),
            reason: '$degrees deg');
      }
    });

    test('the chosen ratio survives straightening', () {
      for (final ratio in CropRatio.values) {
        final crop = CropRect.largestIn(
          frameAspect: frame,
          ratio: ratio,
          angleDegrees: 8,
        );

        expect(
          visualAspect(crop),
          closeTo(ratio.aspectIn(CropOrientation.landscape), 1e-6),
          reason: ratio.label,
        );
      }
    });

    test('a resize on a straightened frame stays out of the corners', () {
      final start = CropRect.largestIn(
        frameAspect: frame,
        ratio: CropRatio.square,
        angleDegrees: 10,
      );
      final safe = CropRect.safeArea(frameAspect: frame, degrees: 10);

      final pulled = start.resizedFrom(
        corner: CropCorner.bottomRight,
        pointer: const Offset(3, 3),
        frameAspect: frame,
      );

      expect(pulled.rect.right, lessThanOrEqualTo(safe.right + 1e-6));
      expect(pulled.rect.bottom, lessThanOrEqualTo(safe.bottom + 1e-6));
      expect(pulled.angleDegrees, 10);
    });

    test('moving a straightened crop cannot slide it into a corner', () {
      final start = CropRect.largestIn(
        frameAspect: frame,
        ratio: CropRatio.square,
        angleDegrees: 12,
      );
      final safe = CropRect.safeArea(frameAspect: frame, degrees: 12);

      final shoved = CropRect(
        rect: Rect.fromLTWH(-0.5, -0.5, start.rect.width, start.rect.height),
        ratio: start.ratio,
        orientation: start.orientation,
        angleDegrees: 12,
      ).clampedToFrame(frameAspect: frame);

      expect(shoved.rect.left, closeTo(safe.left, 1e-9));
      expect(shoved.rect.top, closeTo(safe.top, 1e-9));
    });

    test('the angle is capped rather than allowed to eat the photograph', () {
      final crop = CropRect.largestIn(frameAspect: frame, ratio: CropRatio.threeTwo);

      expect(crop.straightenedTo(90, frameAspect: frame).angleDegrees,
          CropRect.maxAngleDegrees);
      expect(crop.straightenedTo(-90, frameAspect: frame).angleDegrees,
          -CropRect.maxAngleDegrees);
    });

    test('straightening back to zero restores the full frame', () {
      final crop = CropRect.largestIn(frameAspect: frame, ratio: CropRatio.threeTwo)
          .straightenedTo(9, frameAspect: frame)
          .straightenedTo(0, frameAspect: frame);

      expect(crop.angleDegrees, 0);
      expect(crop.rect, const Rect.fromLTWH(0, 0, 1, 1));
    });
  });
}
