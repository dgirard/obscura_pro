import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/crop/crop_screen.dart';
import 'package:obscura_pro/features/crop/ratio.dart';

/// The composing gestures, away from the widget that hosts them.
///
/// Dragging is the one gesture that rebuilds a [CropRect] by hand rather than
/// going through a method on it, which is how it came to drop the straightening
/// angle on the floor: every other path carries `angleDegrees` because it never
/// had the chance to forget.
void main() {
  const frameAspect = 3 / 2;

  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  CropRectNotifier notifier() => container.read(cropRectProvider.notifier);
  CropRect? crop() => container.read(cropRectProvider);

  test('a drag keeps the straightening the user just made', () {
    notifier().reset(frameAspect);
    notifier().straighten(7.5, frameAspect);
    final before = crop()!;
    expect(before.angleDegrees, 7.5);

    notifier().moveTo(
      Offset(before.rect.left + 0.02, before.rect.top + 0.01),
      frameAspect,
    );

    expect(
      crop()!.angleDegrees,
      7.5,
      reason: 'the horizon correction was lost by moving the frame',
    );
    // And it actually moved, so the assertion above is not passing on a no-op.
    expect(crop()!.rect.left, greaterThan(before.rect.left));
  });

  test('a drag cannot push a straightened crop into the empty corners', () {
    notifier().reset(frameAspect);
    notifier().straighten(12, frameAspect);
    final safe = CropRect.safeArea(frameAspect: frameAspect, degrees: 12);

    // Far past the edge, which is what a fast drag produces.
    notifier().moveTo(const Offset(5, 5), frameAspect);

    final rect = crop()!.rect;
    expect(rect.right, lessThanOrEqualTo(safe.right + 1e-9));
    expect(rect.bottom, lessThanOrEqualTo(safe.bottom + 1e-9));
    expect(rect.left, greaterThanOrEqualTo(safe.left - 1e-9));
    expect(rect.top, greaterThanOrEqualTo(safe.top - 1e-9));
  });

  test('a drag on an unstraightened crop still reaches the frame edge', () {
    notifier().reset(frameAspect);
    final width = crop()!.rect.width;

    notifier().moveTo(const Offset(-5, -5), frameAspect);

    // Slid to the edge, not shrunk: the shape the user chose survives.
    expect(crop()!.rect.left, 0);
    expect(crop()!.rect.top, 0);
    expect(crop()!.rect.width, closeTo(width, 1e-9));
  });
}
