import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/theme.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/crop/crop_screen.dart';
import 'package:obscura_pro/features/crop/ratio.dart';
import 'package:obscura_pro/features/layers/layer_controller.dart';
import 'package:obscura_pro/features/layers/layer_painter.dart';
import 'package:obscura_pro/features/layers/layer_repository.dart';
import 'package:obscura_pro/features/viewer/obscura.dart';
import 'package:obscura_pro/features/viewer/viewer_screen.dart';
import 'package:obscura_pro/infra/geometry/view_transform.dart';
import 'package:obscura_pro/infra/preview/preview_extractor.dart';

/// Crop mode, as a photographer meets it.
///
/// The screen showed the whole photograph under a veil from the moment it
/// opened until a file was written, and the rectangle looked like a decoration:
/// nothing on screen ever became the picture being made. These pin the step
/// that fixes it.
void main() {
  testWidgets('starts on the frame, with the export size stated', (tester) async {
    await _pump(tester);

    expect(find.byKey(const Key('crop-applied')), findsNothing);
    // The size of the file the button would write, taken from the
    // full-resolution frame and not from the window.
    expect(find.byKey(const Key('crop-size')), findsOneWidget);
    expect(_text(tester, 'crop-size'), '1620 × 1080 px');
    expect(_text(tester, 'crop-hint'), contains('Glissez le cadre'));
    expect(find.text('Recadrer'), findsOneWidget);
  });

  testWidgets('applies the frame to the picture on screen', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('crop-apply')));
    await tester.pump();

    expect(find.byKey(const Key('crop-applied')), findsOneWidget);
    expect(_text(tester, 'crop-hint'), contains('l\'export écrira cette image'));
    // And back, because a frame that cannot be reopened is a frame you have to
    // leave the screen to change.
    expect(find.text('Modifier'), findsOneWidget);
    await tester.tap(find.byKey(const Key('crop-apply')));
    await tester.pump();
    expect(find.byKey(const Key('crop-applied')), findsNothing);
  });

  testWidgets('a cropped preview quotes the pixels it will produce',
      (tester) async {
    final container = await _pump(tester);
    container.read(cropRectProvider.notifier).chooseRatio(
          CropRatio.square,
          3 / 2,
        );
    await tester.pump();

    // The largest square in a 1620 x 1080 frame.
    expect(_text(tester, 'crop-size'), '1080 × 1080 px');
  });

  testWidgets('shows the guides that are on the photograph', (tester) async {
    final container = await _pump(tester);
    container.read(layerBoardProvider.notifier)
      ..place('golden-spiral')
      ..place('symmetry');
    await tester.pump();

    // A frame is cut *against* a composition, so the composition has to be on
    // screen while it is being cut. Before this, crop mode drew the picture and
    // nothing else — the guides came back only on leaving it.
    final painter = tester
        .widget<CustomPaint>(find.byKey(const Key('crop-layers')))
        .painter as LayerPainter;
    expect(painter.layers.map((l) => l.patternCode),
        ['golden-spiral', 'symmetry']);
    // Drawn, not manipulable: this screen is for choosing a frame, and a guide
    // that could be dragged while a crop is being pulled would be two tools
    // under one pointer.
    expect(painter.showHandles, isFalse);
  });

  testWidgets('the guides turn with the picture and flip with obscura',
      (tester) async {
    final container = await _pump(tester);
    container.read(obscuraProvider.notifier).toggle();
    container.read(layerBoardProvider.notifier).place('golden-spiral');
    await tester.pump();

    final painter = tester
        .widget<CustomPaint>(find.byKey(const Key('crop-layers')))
        .painter as LayerPainter;
    // The guides sit in the same box as the picture, so obscura reaches them
    // through the same transform rather than being applied twice or not at all.
    expect(painter.transform.obscura, isTrue);
  });

  testWidgets('the frame follows the pointer, upright', (tester) async {
    final container = await _pump(tester);
    container.read(cropRectProvider.notifier).chooseRatio(CropRatio.square, 3 / 2);
    await tester.pump();
    final before = container.read(cropRectProvider)!.rect;

    await _dragFrame(tester, const Offset(120, 0));

    expect(container.read(cropRectProvider)!.rect.left, greaterThan(before.left));
  });

  testWidgets('a frame chosen under obscura cuts what was framed',
      (tester) async {
    final container = await _pump(tester);
    container.read(obscuraProvider.notifier).toggle();
    container.read(cropRectProvider.notifier).chooseRatio(CropRatio.square, 3 / 2);
    await tester.pump();
    final before = container.read(cropRectProvider)!.rect;

    await _dragFrame(tester, const Offset(120, 0));

    // The photograph is upside down, so dragging the frame to the right moves
    // it to the *left* of the picture being cut. The stored rectangle stays in
    // upright space -- which is what makes the exported file the right way up
    // whichever way the photographer was looking -- and it is that rectangle
    // that has to follow the subject the frame was put around. Before this,
    // the export came back as the opposite corner of the photograph.
    final after = container.read(cropRectProvider)!.rect;
    expect(after.left, lessThan(before.left));
    expect(after.width, closeTo(before.width, 1e-9));
  });

  testWidgets('a corner grabbed under obscura is the corner that moves',
      (tester) async {
    final container = await _pump(tester);
    container.read(obscuraProvider.notifier).toggle();
    container.read(cropRectProvider.notifier).chooseRatio(CropRatio.square, 3 / 2);
    await tester.pump();
    final before = container.read(cropRectProvider)!.rect;

    // Where the rectangle's top-left corner is actually drawn once the picture
    // is turned: the bottom-right of the screen. Pulling that handle inwards
    // has to shrink the frame rather than resize the corner on the other side
    // of the picture.
    final canvas = tester.getRect(find.byKey(const Key('crop-canvas')));
    final transform = ViewTransform(
      imageSize: const Size(1500, 1000),
      viewport: canvas.size,
      obscura: true,
    );
    // A pixel inside the canvas: the corner sits on its very edge, and a
    // pointer exactly on the boundary lands outside the box.
    final handle = canvas.topLeft +
        transform.normalizedToScreen(before.topLeft) -
        const Offset(1, 1);
    final gesture = await tester.startGesture(handle);
    // Inwards, which on screen is up and to the left of that handle.
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(-12, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    expect(container.read(cropRectProvider)!.rect.width, lessThan(before.width));
  });

  testWidgets('changing the frame takes the applied view back off',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('crop-apply')));
    await tester.pump();
    expect(find.byKey(const Key('crop-applied')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ratio-16x9')));
    await tester.pump();

    // Otherwise the screen would go on showing the previous frame, which is the
    // one thing this view exists not to do.
    expect(find.byKey(const Key('crop-applied')), findsNothing);
    expect(_text(tester, 'crop-size'), '1620 × 911 px');
  });
}

/// Drags the frame from the middle of the canvas, in a run of small moves.
///
/// Small moves because a pan is not recognised until the pointer has travelled
/// the touch slop, and a single event is spent being recognised rather than
/// being applied.
Future<void> _dragFrame(WidgetTester tester, Offset by) async {
  final gesture = await tester.startGesture(const Offset(600, 300));
  for (var i = 0; i < 8; i++) {
    await gesture.moveBy(by / 8);
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

Future<ProviderContainer> _pump(WidgetTester tester, {double width = 1200}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fullPreviewProvider.overrideWith((ref, request) => _image()),
        layerRepositoryProvider.overrideWithValue(InMemoryLayerStore()),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(
            theme: buildObscuraTheme(),
            home: Scaffold(body: CropScreen(photo: _photo())),
          );
        },
      ),
    ),
  );
  // The rectangle is reset after the first frame, so the controls only have
  // something to describe on the second.
  await tester.pump();
  await tester.pump();
  return container;
}

Future<ui.Image> _image() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 60, 40),
    Paint()..color = const Color(0xFF336699),
  );
  return recorder.endRecording().toImage(60, 40);
}

PhotoEntity _photo() => PhotoEntity(
      radical: 'L1000001',
      folder: '100LEICA',
      key: StableKey.fromExif(
        dcfRadical: '100LEICA/L1000001',
        captureTime: DateTime.utc(2026, 3, 14, 9, 26, 53),
        bodySerial: '5301234',
      ),
      files: const [],
      viewerPreview: const PreviewStream(
        offset: 4096,
        length: 20000,
        kind: PreviewStreamKind.jpegStrips,
        width: 1620,
        height: 1080,
      ),
    );
