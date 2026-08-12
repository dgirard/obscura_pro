import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/layers/layer_canvas.dart';
import 'package:obscura_pro/features/layers/layer_controller.dart';
import 'package:obscura_pro/features/layers/layer_repository.dart';
import 'package:obscura_pro/infra/geometry/view_transform.dart';

/// U13, at the pointer.
///
/// The arithmetic is checked in `handles_test.dart`; what is checked here is
/// the thing only a real gesture can show -- which drags the canvas takes and
/// which it lets through to the viewer underneath it.
///
/// The drags below are sent as a run of small moves rather than through
/// `dragFrom`, which delivers the whole distance in one event: a pan recognised
/// by that single event reports it as the start of the gesture and never as an
/// update, so the guide would sit still and the test would be measuring the
/// gesture recogniser rather than the canvas. The first twenty pixels of a
/// gesture are spent being recognised, so where it matters the movement is
/// measured between two samples taken after that.
void main() {
  const imageSize = Size(1500, 1000);
  const viewport = Size(600, 400);

  /// The canvas over a stand-in for the photograph, which records the drags it
  /// receives. In the viewer that stand-in is the `InteractiveViewer`.
  Future<(ProviderContainer, List<String>)> pump(
    WidgetTester tester, {
    bool interactive = true,
  }) async {
    final underneath = <String>[];
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          layerRepositoryProvider.overrideWithValue(InMemoryLayerStore()),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              home: Scaffold(
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => underneath.add('pan'),
                    ),
                    LayerCanvas(
                      transform: const ViewTransform(
                        imageSize: imageSize,
                        viewport: viewport,
                      ),
                      interactive: interactive,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    container.read(layerBoardProvider.notifier).open(_photo());
    await tester.pump();
    return (container, underneath);
  }

  Future<void> drag(WidgetTester tester, Offset from, Offset by) async {
    final gesture = await tester.startGesture(from);
    await tester.pump();
    const steps = 6;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(by / steps.toDouble());
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
  }

  testWidgets('drags a guide by its body', (tester) async {
    final (container, underneath) = await pump(tester);
    final notifier = container.read(layerBoardProvider.notifier)
      ..place('rule-of-thirds');
    // Half the frame, so there is somewhere outside it to drag from.
    notifier.apply(
      container.read(layerBoardProvider).layers.single
          .copyWith(scaleX: 0.5, scaleY: 0.5),
    );
    await tester.pump();

    final gesture = await tester.startGesture(const Offset(300, 200));
    // Past the touch slop: the gesture is a pan from here on.
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    final from = container.read(layerBoardProvider).layers.single.position;

    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    // Sixty of six hundred is a tenth of the frame, and the guide follows the
    // pointer exactly.
    final to = container.read(layerBoardProvider).layers.single.position;
    expect(to.dx - from.dx, closeTo(0.1, 1e-9));
    expect(to.dy, from.dy);
    expect(underneath, isEmpty, reason: 'the viewer must not also pan');
  });

  testWidgets('lets a drag that misses every guide reach the viewer',
      (tester) async {
    final (container, underneath) = await pump(tester);
    final notifier = container.read(layerBoardProvider.notifier)
      ..place('rule-of-thirds');
    notifier.apply(
      container.read(layerBoardProvider).layers.single
          .copyWith(scaleX: 0.4, scaleY: 0.4),
    );
    await tester.pump();
    final before = container.read(layerBoardProvider).layers.single;

    // The top-left corner of the window: outside a guide that covers the middle
    // two fifths of the picture.
    await drag(tester, const Offset(20, 20), const Offset(40, 0));
    await tester.pump();

    expect(container.read(layerBoardProvider).layers.single, before);
    expect(underneath, ['pan'], reason: 'panning must survive the panel');
  });

  testWidgets('takes no pointer at all while the panel is closed',
      (tester) async {
    final (container, underneath) = await pump(tester, interactive: false);
    container.read(layerBoardProvider.notifier).place('rule-of-thirds');
    await tester.pump();
    final before = container.read(layerBoardProvider).layers.single;

    await drag(tester, const Offset(300, 200), const Offset(60, 0));
    await tester.pump();

    // The guides are still drawn -- that is what they are for -- but the whole
    // photograph is the viewer's again.
    expect(container.read(layerBoardProvider).layers.single, before);
    expect(underneath, ['pan']);
  });

  testWidgets('scales from a corner without moving the opposite one',
      (tester) async {
    final (container, _) = await pump(tester);
    final notifier = container.read(layerBoardProvider.notifier)
      ..place('golden-spiral');
    notifier.apply(
      container.read(layerBoardProvider).layers.single
          .copyWith(scaleX: 0.5, scaleY: 0.5),
    );
    await tester.pump();

    // The guide covers 0.25..0.75 of the frame: 150..450 across, 100..300 down.
    await drag(tester, const Offset(150, 100), const Offset(60, 40));
    await tester.pump();

    final after = container.read(layerBoardProvider).layers.single;
    expect(after.scaleX, lessThan(0.5));
    expect(after.scaleX, closeTo(after.scaleY, 1e-9));
    // The bottom-right corner is where it was, in the frame's own coordinates.
    expect(after.position.dx + after.scaleX / 2, closeTo(0.75, 1e-9));
    expect(after.position.dy + after.scaleY / 2, closeTo(0.75, 1e-9));
  });
}

PhotoEntity _photo() => PhotoEntity(
      radical: 'L1000001',
      folder: '100LEICA',
      key: StableKey.fromExif(
        dcfRadical: '100LEICA/L1000001',
        captureTime: DateTime.utc(2026, 3, 14, 9, 26, 53),
        bodySerial: '5301234',
      ),
      files: [
        PhotoFile(
          name: 'L1000001.DNG',
          path: '/Volumes/Q3/DCIM/100LEICA/L1000001.DNG',
          kind: PhotoFileKind.raw,
          sizeBytes: 84000000,
          modified: DateTime.utc(2026, 3, 14),
        ),
      ],
    );
