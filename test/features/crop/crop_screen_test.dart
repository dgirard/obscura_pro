import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/theme.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/crop/crop_screen.dart';
import 'package:obscura_pro/features/crop/ratio.dart';
import 'package:obscura_pro/features/viewer/viewer_screen.dart';
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
