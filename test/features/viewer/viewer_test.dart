import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/theme.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/grid/grid_screen.dart';
import 'package:obscura_pro/features/grid/photo_cell.dart';
import 'package:obscura_pro/features/grid/thumbnail_provider.dart';
import 'package:obscura_pro/features/layers/layer_controller.dart';
import 'package:obscura_pro/features/layers/layer_repository.dart';
import 'package:obscura_pro/features/trash/mark_store.dart';
import 'package:obscura_pro/features/trash/trash_providers.dart';
import 'package:obscura_pro/features/viewer/exif_overlay.dart';
import 'package:obscura_pro/features/viewer/obscura.dart';
import 'package:obscura_pro/features/viewer/viewer_screen.dart';
import 'package:obscura_pro/infra/preview/preview_extractor.dart';

import '../../infra/preview/tiff_fixture.dart';

void main() {
  group('composing the two rotations', () {
    test('an upright frame is not turned at all', () {
      final o = DisplayOrientation.of(ExifOrientation.normal);

      expect(o.quarterTurns, 0);
      expect(o.mirrored, isFalse);
      expect(o.swapsAxes, isFalse);
    });

    test('a portrait frame is stood up', () {
      final o = DisplayOrientation.of(ExifOrientation.rotate90);

      expect(o.quarterTurns, 1);
      expect(o.swapsAxes, isTrue);
      expect(o.sizeOf(const Size(1620, 1080)), const Size(1080, 1620));
    });

    test('obscura adds a half turn on top of the EXIF one', () {
      expect(
        DisplayOrientation.of(ExifOrientation.normal, obscura: true).quarterTurns,
        2,
      );
      expect(
        DisplayOrientation.of(ExifOrientation.rotate90, obscura: true).quarterTurns,
        3,
      );
      // Back to upright: a portrait frame already turned 270 plus obscura's 180
      // comes round to 90.
      expect(
        DisplayOrientation.of(ExifOrientation.rotate270, obscura: true).quarterTurns,
        1,
      );
    });

    test('obscura never mirrors, whatever the EXIF orientation said', () {
      // FONC-OBS-1 is explicit that this is a rotation and not a mirror. A half
      // turn also commutes with a mirror, so composing it cannot flip one that
      // was already there — worth pinning, since getting it wrong would show a
      // reversed photograph and look almost right.
      for (final exif in [1, 2, 3, 4, 5, 6, 7, 8]) {
        expect(
          DisplayOrientation.of(exif, obscura: true).mirrored,
          DisplayOrientation.of(exif).mirrored,
          reason: 'orientation $exif',
        );
      }
    });

    test('a half turn does not swap the axes', () {
      final o = DisplayOrientation.of(ExifOrientation.normal, obscura: true);

      expect(o.swapsAxes, isFalse);
      expect(o.sizeOf(const Size(1620, 1080)), const Size(1620, 1080));
    });
  });

  group('the viewer', () {
    late List<PhotoEntity> photos;

    setUp(() {
      photos = [
        _photo('L1000001'),
        _photo('L1000002'),
        _photo('L1000003'),
      ];
    });

    testWidgets('shows the photograph the grid cursor was on', (tester) async {
      await _pump(tester, photos, at: 1);

      expect(find.byKey(const Key('viewer-image')), findsOneWidget);
      expect(_positionText(tester), '2 / 3');
    });

    testWidgets('arrows move through the session', (tester) async {
      await _pump(tester, photos);

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_positionText(tester), '2 / 3');

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_positionText(tester), '3 / 3');

      // The end of the session is a stop, not a wrap: a photographer at the
      // last frame pressing right once more has not asked to start over.
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_positionText(tester), '3 / 3');

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_positionText(tester), '2 / 3');
    });

    testWidgets('moving leaves the grid cursor where the viewer left it',
        (tester) async {
      final container = await _pump(tester, photos);

      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.arrowRight);

      // Closing must return to the grid on the frame just reviewed, not the one
      // it was opened from.
      expect(container.read(gridCursorProvider), 2);
    });

    testWidgets('asks for the neighbours before the user reaches them',
        (tester) async {
      final requested = <String>[];
      await _pump(tester, photos, onFullPreview: requested.add);
      await tester.pump();

      // Both sides, so going back is as quick as going on (PERF-2).
      expect(requested, containsAll(['L1000001', 'L1000002', 'L1000003']));
    });

    testWidgets('Enter closes the viewer', (tester) async {
      final container = await _pump(tester, photos);
      expect(container.read(viewerOpenProvider), isTrue);

      await _press(tester, LogicalKeyboardKey.enter);

      expect(container.read(viewerOpenProvider), isFalse);
    });

    testWidgets('O turns the photograph and does not decode it again',
        (tester) async {
      var decodes = 0;
      final container =
          await _pump(tester, photos, onFullPreview: (_) => decodes++);
      await tester.pump();
      final before = decodes;

      await _press(tester, LogicalKeyboardKey.keyO);

      expect(container.read(obscuraProvider), isTrue);
      expect(_orientationOf(tester).quarterTurns, 2);
      // The turn is a canvas transform. Re-decoding a frame to rotate it would
      // cost a second copy of tens of megabytes for something the compositor
      // does for nothing.
      expect(decodes, before);
    });

    testWidgets('obscura stays on across photographs', (tester) async {
      await _pump(tester, photos);

      await _press(tester, LogicalKeyboardKey.keyO);
      await _press(tester, LogicalKeyboardKey.arrowRight);

      // The technique is used on a run of frames, not on one.
      expect(_orientationOf(tester).quarterTurns, 2);
    });

    testWidgets('Delete marks the photograph on screen', (tester) async {
      final container = await _pump(tester, photos);

      await _press(tester, LogicalKeyboardKey.backspace);

      expect(container.read(markedForDeletionProvider).length, 1);
      expect(find.byKey(const Key('viewer-marked')), findsOneWidget);
    });

    testWidgets('offers the same mark control as the grid does', (tester) async {
      final container = await _pump(tester, photos);

      // A photographer decides a frame's fate while looking at it full size at
      // least as often as from the grid; having to go back to find the control
      // is the reason they would stop looking properly.
      final button = find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == 'Marquer à supprimer (⌫)',
      );
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();

      expect(container.read(markedForDeletionProvider).length, 1);
      expect(find.byKey(const Key('viewer-marked')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == 'Ne plus supprimer (⌫)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('states the exposure over the frame', (tester) async {
      await _pump(tester, photos);

      expect(find.byKey(const Key('exif-overlay')), findsOneWidget);
      expect(find.text('35 mm'), findsOneWidget);
      expect(find.text('1/250'), findsOneWidget);
      expect(find.text('f/1.7'), findsOneWidget);
      expect(find.text('400'), findsOneWidget);
    });

    testWidgets('the overlay stays hidden once hidden, photograph after photograph',
        (tester) async {
      final container = await _pump(tester, photos);

      container.read(exifOverlayVisibleProvider.notifier).toggle();
      await tester.pump();
      expect(find.byKey(const Key('exif-overlay')), findsNothing);

      await _press(tester, LogicalKeyboardKey.arrowRight);

      // Re-deciding per photograph would make it flicker through a session.
      expect(find.byKey(const Key('exif-overlay')), findsNothing);
    });

    testWidgets('says so plainly when a frame has no readable preview',
        (tester) async {
      await _pump(tester, [_photo('L1000009', unreadable: true)]);

      expect(find.byKey(const Key('viewer-unreadable')), findsOneWidget);
      expect(find.byKey(const Key('viewer-image')), findsNothing);
    });

    testWidgets('shows the thumbnail while the full frame is still decoding',
        (tester) async {
      await _pump(tester, photos, fullPreviewNeverArrives: true);
      await tester.pump();

      // This stand-in is the whole of PERF-2: the frame changes at once and
      // sharpens a moment later, instead of the window going black while a
      // 13 MB stream is read.
      expect(find.byKey(const Key('viewer-standin')), findsOneWidget);
    });
  });

  group('the exposure the camera recorded', () {
    test('reads shutter, aperture, ISO and the cropped focal length', () {
      final header = _headerOf(buildSyntheticDng(exposure: true).bytes);

      expect(header.settings.shutterLabel, '1/250');
      expect(header.settings.apertureLabel, 'f/1.7');
      expect(header.settings.iso, 400);
      // 35, not 28: on a Q3 the equivalent focal length is what the crop ring
      // changed, and it is the number the photographer chose.
      expect(header.settings.focalLabel, '35 mm');
      expect(header.settings.model, 'LEICA Q3');
      expect(header.settings.lens, contains('Summilux'));
    });

    test('a file with none of the tags is empty rather than wrong', () {
      final header = _headerOf(buildSyntheticDng().bytes);

      expect(header.settings.isEmpty, isTrue);
      expect(header.settings.shutterLabel, isNull);
      expect(header.settings.apertureLabel, isNull);
    });

    test('states a long exposure in seconds and a short one as a fraction', () {
      expect(
        const CaptureSettings(exposureSeconds: 1 / 250).shutterLabel,
        '1/250',
      );
      expect(const CaptureSettings(exposureSeconds: 2).shutterLabel, '2s');
      expect(const CaptureSettings(exposureSeconds: 1.5).shutterLabel, '1.5s');
      // A zero denominator is a malformed tag, not an infinitely fast shutter.
      expect(const CaptureSettings(exposureSeconds: 0).shutterLabel, isNull);
    });

    test('drops the trailing zero from a whole-stop aperture', () {
      expect(const CaptureSettings(aperture: 8).apertureLabel, 'f/8');
      expect(const CaptureSettings(aperture: 1.7).apertureLabel, 'f/1.7');
    });

    test('falls back to the real focal length when no equivalent was written',
        () {
      expect(
        const CaptureSettings(focalLengthMm: 28).focalLabel,
        '28 mm',
      );
    });
  });
}

// --- Harness ----------------------------------------------------------------

PhotoHeader _headerOf(Uint8List bytes) =>
    (scanPhotoHeader(bytes) as PreviewScanSuccess).header;

final _pixel = realJpeg(width: 8, height: 8);

DisplayOrientation _orientationOf(WidgetTester tester) => tester
    .widget<OrientedImage>(find.byKey(const Key('viewer-image')))
    .orientation;

String _positionText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('viewer-position'))).data!;

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  // A second frame, because the new frame's decode resolves in a microtask.
  await tester.pump();
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<PhotoEntity> photos, {
  int at = 0,
  void Function(String radical)? onFullPreview,
  bool fullPreviewNeverArrives = false,
}) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  late ProviderContainer container;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // No application-support directory in a widget test, so the durable
        // store is stood in for. The write-through itself is checked where the
        // store is, not through the viewer.
        markStoreProvider.overrideWith((ref) async => InMemoryMarkStore()),
        // Same reason: the viewer points the composition at whichever
        // photograph it is showing, and that reads from the database.
        layerRepositoryProvider.overrideWith((ref) => InMemoryLayerStore()),
        gridThumbnailProvider.overrideWith(
          (ref, request) async => GridThumbnail(
            jpeg: _pixel,
            width: 8,
            height: 8,
            averageColor: 0xFF888888,
            fromCache: true,
          ),
        ),
        fullPreviewProvider.overrideWith((ref, request) async {
          onFullPreview?.call(request.photo.radical);
          if (fullPreviewNeverArrives) return Completer<ui.Image>().future;
          return _solidImage();
        }),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(
            theme: buildObscuraTheme(),
            home: Scaffold(body: ViewerScreen(photos: photos)),
          );
        },
      ),
    ),
  );

  container.read(gridCursorProvider.notifier).moveTo(at);
  container.read(viewerOpenProvider.notifier).open();
  await tester.pump();
  await tester.pump();
  return container;
}

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 60, 40),
    Paint()..color = const Color(0xFF336699),
  );
  return recorder.endRecording().toImage(60, 40);
}

PhotoEntity _photo(String radical, {bool unreadable = false}) {
  const stream = PreviewStream(
    offset: 4096,
    length: 20000,
    kind: PreviewStreamKind.jpegStrips,
    width: 1620,
    height: 1080,
  );
  return PhotoEntity(
    radical: radical,
    folder: '100LEICA',
    key: StableKey.fromExif(
      dcfRadical: '100LEICA/$radical',
      captureTime: DateTime.utc(2026, 3, 14, 9, 26, 53),
      bodySerial: '1234567',
    ),
    files: [
      PhotoFile(
        name: '$radical.DNG',
        path: '/nowhere/$radical.DNG',
        kind: PhotoFileKind.raw,
        sizeBytes: 84000000,
        modified: DateTime.utc(2026, 3, 14),
      ),
    ],
    gridPreview: unreadable ? null : stream,
    viewerPreview: unreadable ? null : stream,
    settings: const CaptureSettings(
      model: 'LEICA Q3',
      exposureSeconds: 1 / 250,
      aperture: 1.7,
      iso: 400,
      focalLengthMm: 28,
      focalLength35mm: 35,
    ),
  );
}
