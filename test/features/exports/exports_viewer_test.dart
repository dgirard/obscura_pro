import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/theme.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/exports/export_store.dart';
import 'package:obscura_pro/features/exports/exports_screen.dart';
import 'package:obscura_pro/features/grid/grid_screen.dart';
import 'package:obscura_pro/features/grid/photo_cell.dart';
import 'package:obscura_pro/features/grid/thumbnail_provider.dart';
import 'package:obscura_pro/features/layers/layer_controller.dart';
import 'package:obscura_pro/features/layers/layer_repository.dart';
import 'package:obscura_pro/features/trash/mark_store.dart';
import 'package:obscura_pro/features/trash/trash_providers.dart';
import 'package:obscura_pro/features/viewer/viewer_screen.dart';
import 'package:obscura_pro/infra/finder/finder_channel.dart';
import 'package:obscura_pro/infra/preview/preview_extractor.dart';

import '../../infra/preview/tiff_fixture.dart';

/// An export, opened as a photograph — and the one thing that must stay
/// impossible while it is open.
void main() {
  late InMemoryMarkStore marks;
  late FakeFinder finder;

  Future<ProviderContainer> pump(WidgetTester tester) async {
    marks = InMemoryMarkStore();
    finder = FakeFinder();
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exportStoreProvider.overrideWithValue(
            InMemoryExportStore([
              _record(1, '2026-08-13', 'a.jpg'),
              _record(2, '2026-08-13', 'b.jpg'),
            ]),
          ),
          // The entities the viewer shows. Built by hand rather than read from
          // disk: real file I/O never completes under the test binding's clock.
          exportPhotosProvider.overrideWith((ref) async => [
                _photo('a'),
                _photo('b'),
              ]),
          exportImageProvider.overrideWithValue(
            (path) => MemoryImage(realJpeg(width: 12, height: 8)),
          ),
          finderProvider.overrideWithValue(finder),
          markStoreProvider.overrideWith((ref) async => marks),
          layerRepositoryProvider.overrideWithValue(InMemoryLayerStore()),
          fullPreviewProvider.overrideWith((ref, request) => _image()),
          gridThumbnailProvider.overrideWith(
            (ref, request) async => GridThumbnail(
              jpeg: realJpeg(width: 8, height: 8),
              width: 8,
              height: 8,
              averageColor: 0xFF888888,
              fromCache: true,
            ),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: buildObscuraTheme(),
              home: const Scaffold(body: ExportsScreen()),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    return container;
  }

  /// Opens through the tile's own control.
  ///
  /// The extra pump is the double-tap window: the tile opens on a double click
  /// too, so a single tap inside it is held for that long before the button
  /// underneath wins the gesture.
  Future<void> open(WidgetTester tester, int id) async {
    await tester.tap(find.byKey(Key('export-open-$id')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('opens an export full-frame', (tester) async {
    final container = await pump(tester);

    await open(tester, 1);

    expect(find.byType(ViewerScreen), findsOneWidget);
    expect(container.read(exportViewerOpenProvider), isTrue);
    // The file that was double-clicked, not the first one in the folder.
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('walks through the exports, leaving the card where it was',
      (tester) async {
    final container = await pump(tester);
    container.read(gridCursorProvider.notifier).moveTo(7);

    await open(tester, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();

    expect(container.read(exportCursorProvider), 1);
    // Browsing exports must not move the selection in the card's own grid;
    // they are two libraries, and one cursor for both would make each move in
    // the other.
    expect(container.read(gridCursorProvider), 7);
  });

  testWidgets('Delete puts the open export in the Mac trash, and marks nothing '
      'on the card', (tester) async {
    final container = await pump(tester);
    await open(tester, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    await tester.pump();

    // The same key as on the card, doing the only thing it can do to a file on
    // the Mac. What must not happen is the other thing: a trash row's path is
    // composed from a DCF folder and a file name, which on a Mac file is
    // fiction, and Empty Trash would act on it.
    expect(finder.trashed,
        ['/Users/x/Pictures/Q3Culling/Exports/2026-08-13/a.jpg']);
    expect(marks.calls, isEmpty);
    expect(container.read(markedForDeletionProvider).length, 0);
  });

  testWidgets('says what the controls do to a file on the Mac', (tester) async {
    await pump(tester);
    await open(tester, 1);

    // The card's wording would be a lie here, and the export mark is a decision
    // about a frame on a card — there is no card behind this picture.
    expect(find.byTooltip('Mettre à la corbeille du Mac (⌫)'), findsOneWidget);
    expect(find.byTooltip('Marquer à supprimer (⌫)'), findsNothing);
    expect(find.byTooltip('Marquer à exporter (E)'), findsNothing);
  });

  testWidgets('remembers a guide laid on an export', (tester) async {
    final container = await pump(tester);
    await open(tester, 1);

    container.read(layerBoardProvider.notifier).place('rule-of-thirds');
    await tester.pump();
    expect(container.read(layerBoardProvider).layers, hasLength(1));

    // Away and back: the composition is keyed by the file's identity, so it is
    // still there.
    container.read(exportViewerOpenProvider.notifier).close();
    await tester.pump();
    await open(tester, 1);

    expect(container.read(layerBoardProvider).layers, hasLength(1));
  });
}

ExportRecord _record(int id, String session, String name) => ExportRecord(
      id: id,
      radical: '100LEICA/L100000$id',
      ratio: '3:2',
      orientation: 'landscape',
      path: '/Users/x/Pictures/Q3Culling/Exports/$session/$name',
      createdAt: DateTime(2026, 8, 13, 10, id),
      pixelWidth: 4000,
      pixelHeight: 2667,
      byteSize: 2048,
    );

/// A photograph read from the Mac: no DCF folder, its own file.
PhotoEntity _photo(String stem) => PhotoEntity(
      radical: stem,
      folder: '',
      key: StableKey.fromMacFile(
        sizeBytes: 2048,
        pixelWidth: 4000,
        pixelHeight: 2667,
        fallbackName: stem,
      ),
      files: [
        PhotoFile(
          name: '$stem.jpg',
          path: '/Users/x/Pictures/Q3Culling/Exports/2026-08-13/$stem.jpg',
          kind: PhotoFileKind.jpeg,
          sizeBytes: 2048,
          modified: DateTime(2026, 8, 13),
        ),
      ],
      gridPreview: const PreviewStream(
        offset: 0,
        length: 2048,
        kind: PreviewStreamKind.wholeFile,
        width: 4000,
        height: 2667,
      ),
      viewerPreview: const PreviewStream(
        offset: 0,
        length: 2048,
        kind: PreviewStreamKind.wholeFile,
        width: 4000,
        height: 2667,
      ),
    );

Future<ui.Image> _image() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 60, 40),
    Paint()..color = const Color(0xFF336699),
  );
  return recorder.endRecording().toImage(60, 40);
}
