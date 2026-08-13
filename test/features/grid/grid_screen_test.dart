import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/app_shell.dart';
import 'package:obscura_pro/app/status_bar.dart';
import 'package:obscura_pro/app/theme.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/grid/grid_screen.dart';
import 'package:obscura_pro/features/grid/photo_cell.dart';
import 'package:obscura_pro/features/exports/export_marks.dart';
import 'package:obscura_pro/features/exports/export_store.dart';
import 'package:obscura_pro/features/exports/exports_screen.dart';
import 'package:obscura_pro/features/grid/thumbnail_provider.dart';
import 'package:obscura_pro/features/settings/settings_screen.dart';
import 'package:obscura_pro/features/settings/settings_store.dart';
import 'package:obscura_pro/features/trash/trash_screen.dart';
import 'package:obscura_pro/features/volume_select/card_selection.dart';
import 'package:obscura_pro/features/volume_select/volume_screen.dart';
import 'package:obscura_pro/features/trash/mark_store.dart';
import 'package:obscura_pro/features/trash/trash_providers.dart';
import 'package:obscura_pro/infra/preview/preview_extractor.dart';

import '../../infra/preview/tiff_fixture.dart';

void main() {
  group('moving the cursor', () {
    // The grid is a sequence laid out in rows, and every one of these cases is
    // a place where those two readings disagree.
    int move(int from, GridMove m, {int columns = 4, int count = 10}) =>
        moveCursor(from, m, columns: columns, count: count);

    test('left and right step through the photographs one at a time', () {
      expect(move(3, GridMove.next), 4);
      expect(move(3, GridMove.previous), 2);
    });

    test('right at the end of a row wraps onto the next row', () {
      // Index 3 is the last cell of row 0 in a four-column grid.
      expect(move(3, GridMove.next), 4);
    });

    test('left at the start of a row wraps back onto the previous one', () {
      expect(move(4, GridMove.previous), 3);
    });

    test('stops at the two ends of the catalogue', () {
      expect(move(0, GridMove.previous), 0);
      expect(move(9, GridMove.next), 9);
    });

    test('up and down move by a whole row', () {
      expect(move(6, GridMove.nextRow), 10 - 1);
      expect(move(6, GridMove.previousRow), 2);
    });

    test('up on the first row stays put rather than wrapping to the bottom', () {
      // Wrapping here would drop a photographer at the far end of a 900-frame
      // session for pressing one key too many.
      expect(move(2, GridMove.previousRow), 2);
    });

    test('down into a short last row lands on the last photograph', () {
      // Row 2 holds only indices 8 and 9; coming from index 7 there is no cell
      // directly below, but the row exists and the move must not be swallowed.
      expect(move(7, GridMove.nextRow), 9);
    });

    test('down on the last row stays put', () {
      expect(move(9, GridMove.nextRow), 9);
    });

    test('survives an empty catalogue and a single column', () {
      expect(moveCursor(0, GridMove.next, columns: 4, count: 0), 0);
      expect(moveCursor(0, GridMove.nextRow, columns: 1, count: 3), 1);
    });

    test('clamps a cursor left behind by a shorter catalogue', () {
      // A card can be re-scanned with fewer photographs under a cursor that was
      // pointing at one of the ones that went.
      expect(moveCursor(40, GridMove.next, columns: 4, count: 3), 2);
    });
  });

  group('the grid', () {
    late List<PhotoEntity> photos;

    setUp(() {
      photos = [
        _photo('L1000001', raw: true, jpeg: true),
        _photo('L1000002', raw: true, jpeg: false),
        _photo('L1000003', raw: false, jpeg: true),
        _photo('L1000004', raw: true, jpeg: true),
        _photo('L1000005', raw: true, jpeg: true),
        _photo('L1000006', raw: true, jpeg: true, unreadable: true),
      ];
    });

    testWidgets('shows one cell per photograph with its format badge',
        (tester) async {
      await _pump(tester, photos);

      expect(find.byType(PhotoCell), findsNWidgets(photos.length));
      expect(_badgeText(tester, 'L1000001'), 'RAW+JPG');
      expect(_badgeText(tester, 'L1000002'), 'RAW');
      expect(_badgeText(tester, 'L1000003'), 'JPG');
    });

    testWidgets('draws the first photograph selected before any key is pressed',
        (tester) async {
      await _pump(tester, photos);

      expect(_isSelected(tester, 'L1000001'), isTrue);
      expect(_isSelected(tester, 'L1000002'), isFalse);
    });

    testWidgets('arrow keys move the selection, including across rows',
        (tester) async {
      // 1000 logical pixels of viewport gives four columns at the target
      // extent, so a row is exactly four photographs wide.
      await _pump(tester, photos, size: const Size(1000, 700));

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_isSelected(tester, 'L1000002'), isTrue);

      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_isSelected(tester, 'L1000006'), isTrue,
          reason: 'index 1 plus four columns is index 5');

      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_isSelected(tester, 'L1000002'), isTrue);

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_isSelected(tester, 'L1000001'), isTrue);
    });

    testWidgets('right at a row end wraps onto the next row', (tester) async {
      await _pump(tester, photos, size: const Size(1000, 700));

      for (var i = 0; i < 4; i++) {
        await _press(tester, LogicalKeyboardKey.arrowRight);
      }

      // Four presses from index 0 lands on index 4 — the first cell of row 1.
      expect(_isSelected(tester, 'L1000005'), isTrue);
    });

    testWidgets('Enter opens the selected photograph', (tester) async {
      final opened = <String>[];
      await _pump(tester, photos, onOpen: (p) => opened.add(p.radical));

      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.enter);

      expect(opened, ['L1000002']);
    });

    testWidgets('Space opens it too', (tester) async {
      final opened = <String>[];
      await _pump(tester, photos, onOpen: (p) => opened.add(p.radical));

      await _press(tester, LogicalKeyboardKey.space);

      expect(opened, ['L1000001']);
    });

    testWidgets('Delete marks the selected photograph, and unmarks it',
        (tester) async {
      await _pump(tester, photos);

      expect(find.byKey(const Key('marked-100LEICA/L1000001')), findsNothing);

      await _press(tester, LogicalKeyboardKey.backspace);
      expect(find.byKey(const Key('marked-100LEICA/L1000001')), findsOneWidget);

      // Same key unmarks: the shortcut table calls it "mark or unmark", and a
      // culling pass with no way back is one a photographer cannot use quickly.
      await _press(tester, LogicalKeyboardKey.backspace);
      expect(find.byKey(const Key('marked-100LEICA/L1000001')), findsNothing);
    });

    testWidgets('PROBE one click on the corner control marks', (tester) async {
      await _pump(tester, photos);

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(
          location: tester.getCenter(find.byKey(const Key('cell-100LEICA/L1000001'))));
      addTearDown(pointer.removePointer);
      await tester.pump();

      await tester.tap(find.byKey(const Key('mark-100LEICA/L1000001')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('marked-100LEICA/L1000001')), findsOneWidget);
    });

    testWidgets('a corner control hit twice stays the control, not the cell',
        (tester) async {
      final opened = <String>[];
      await _pump(tester, photos, onOpen: (p) => opened.add(p.radical));

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(
          location: tester.getCenter(find.byKey(const Key('cell-100LEICA/L1000001'))));
      addTearDown(pointer.removePointer);
      await tester.pump();

      final button = find.byKey(const Key('mark-100LEICA/L1000001'));
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // A click that seems to do nothing is clicked again. The cell opens on a
      // double click, and the pair landing on a button must stay the button's:
      // it marks and unmarks, and the photograph does not open behind it.
      expect(find.byKey(const Key('marked-100LEICA/L1000001')), findsNothing);
      expect(opened, isEmpty);
    });

    testWidgets('marking writes nothing but the mark', (tester) async {
      await _pump(tester, photos);

      await _press(tester, LogicalKeyboardKey.backspace);
      await _press(tester, LogicalKeyboardKey.arrowRight);

      // The mark stays on the photograph the cursor has left, and the new one
      // is untouched: marking and selecting are different facts.
      expect(find.byKey(const Key('marked-100LEICA/L1000001')), findsOneWidget);
      expect(find.byKey(const Key('marked-100LEICA/L1000002')), findsNothing);
    });

    testWidgets('the decision is written down at the moment it is made',
        (tester) async {
      final store = InMemoryMarkStore();
      await _pump(tester, photos, markStore: store);

      await _press(tester, LogicalKeyboardKey.backspace);
      await tester.pump();

      // Not at Empty Trash, not on quit: now. Everything between the keystroke
      // and the write is a window in which nine hundred decisions are only in
      // memory.
      expect(store.calls, ['mark:${photos.first.key.value}']);

      await _press(tester, LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(store.calls.last, 'unmark:${photos.first.key.value}');
    });

    testWidgets('decisions made in an earlier session come back', (tester) async {
      await _pump(
        tester,
        photos,
        markStore: InMemoryMarkStore(initial: {photos[1].key.value}),
      );
      await tester.pump();

      // The point of writing them down. A culling pass interrupted at frame 300
      // resumes at frame 300 rather than at frame 1.
      expect(find.byKey(const Key('marked-100LEICA/L1000002')), findsOneWidget);
      expect(find.byKey(const Key('marked-100LEICA/L1000001')), findsNothing);
    });

    testWidgets('a photograph with no readable preview gets an error tile',
        (tester) async {
      await _pump(tester, photos);

      expect(
        find.byKey(const Key('unreadable-100LEICA/L1000006')),
        findsOneWidget,
      );
      // Still a cell, still badged, still reachable by the keyboard: an
      // unrenderable frame is exactly one a user may want to delete.
      expect(_badgeText(tester, 'L1000006'), 'RAW+JPG');
    });

    testWidgets('paints the cached average colour under a pending cell',
        (tester) async {
      await _pump(
        tester,
        photos,
        placeholders: {photos.first.key.value: 0xFF204080},
        thumbnail: _never,
      );

      final decoration = _tileDecoration(tester, 'L1000001');

      expect(decoration.color, const Color(0xFF204080));
    });

    testWidgets('falls back to a neutral tile when no colour is known',
        (tester) async {
      await _pump(tester, photos, thumbnail: _never);

      final decoration = _tileDecoration(tester, 'L1000001');

      expect(decoration.color, ObscuraColors.surfaceContainer);
    });

    testWidgets('draws the decoded thumbnail once it arrives', (tester) async {
      await _pump(tester, photos);
      await tester.pump();

      expect(find.byKey(const Key('thumb-100LEICA/L1000001')), findsOneWidget);
    });

    testWidgets('clicking a cell moves the selection to it', (tester) async {
      await _pump(tester, photos, size: const Size(900, 700));

      await tester.tap(find.byKey(const Key('cell-100LEICA/L1000003')));
      // Long enough for the double-click window to close, which is when a
      // single click is finally known to be a single click.
      await tester.pump(const Duration(milliseconds: 400));

      expect(_isSelected(tester, 'L1000003'), isTrue);
    });

    testWidgets('says so plainly when the card holds no photographs',
        (tester) async {
      await _pump(tester, const []);

      expect(find.byKey(const Key('empty-card')), findsOneWidget);
    });

    testWidgets('lays out more columns as the window widens', (tester) async {
      expect(LibraryGrid.columnsFor(900), 3);
      expect(LibraryGrid.columnsFor(1500), 6);
      // Never zero, however narrow the window is dragged.
      expect(LibraryGrid.columnsFor(10), 1);
    });
  });

  group('the window without a card', () {
    testWidgets('opens the destinations that do not need one', (tester) async {
      await _pumpSection(tester, LibrarySection.exports);

      // Every one of these screens reads from the Mac. Asking for a card first
      // is the app asking for something it does not need.
      expect(find.byType(ExportsScreen), findsOneWidget);
      expect(find.byType(VolumeScreen), findsNothing);
    });

    testWidgets('offers the picker where a card is the subject', (tester) async {
      await _pumpSection(tester, LibrarySection.library);

      // In the content area rather than over the window, so the sidebar stays
      // usable and the other destinations stay reachable.
      expect(find.byType(VolumeScreen), findsOneWidget);
    });

    testWidgets('reaches the trash and the settings too', (tester) async {
      await _pumpSection(tester, LibrarySection.settings);
      expect(find.byType(SettingsScreen), findsOneWidget);

      await _pumpSection(tester, LibrarySection.trash);
      expect(find.byType(TrashScreen), findsOneWidget);
    });
  });

  group('the status bar', () {
    testWidgets('says there is no card rather than counting zero photographs',
        (tester) async {
      await _pumpBar(tester, const StatusBar(photoCount: null));

      // Zero photographs is a claim about a card. With no card there is no
      // card to make it about.
      expect(find.byKey(const Key('status-photo-count')), findsNothing);
      expect(find.byKey(const Key('status-no-card')), findsOneWidget);
      expect(find.byKey(const Key('status-card-free')), findsNothing);
    });

    testWidgets('counts the photographs on the card', (tester) async {
      await _pumpBar(tester, const StatusBar(photoCount: 941));

      expect(find.text('941 photographies'), findsOneWidget);
      // Nothing is marked, so nothing about deletion is on screen.
      expect(find.byKey(const Key('status-marked')), findsNothing);
    });

    testWidgets('quotes what emptying the trash would reclaim', (tester) async {
      await _pumpBar(
        tester,
        const StatusBar(
          photoCount: 941,
          markedCount: 12,
          markedBytes: 1200000000,
          cardFreeBytes: 45000000000,
        ),
      );

      expect(find.text('12 à supprimer · 1.2 Go'), findsOneWidget);
      expect(find.text('Carte : 45 Go libres'), findsOneWidget);
    });

    testWidgets('omits the free space when the volume did not report it',
        (tester) async {
      await _pumpBar(tester, const StatusBar(photoCount: 3));

      expect(find.byKey(const Key('status-card-free')), findsNothing);
    });

    testWidgets('gets the singular right', (tester) async {
      await _pumpBar(tester, const StatusBar(photoCount: 1));

      expect(find.text('1 photographie'), findsOneWidget);
    });
  });
}

// --- Harness ----------------------------------------------------------------

/// A one-pixel JPEG, which is all a cell needs to have something to draw.
final _pixel = realJpeg(width: 8, height: 8);

/// A thumbnail that never arrives, for the states before one does.
Future<GridThumbnail> _never(PhotoEntity photo) =>
    Completer<GridThumbnail>().future;

Future<GridThumbnail> _instant(PhotoEntity photo) async => GridThumbnail(
      jpeg: _pixel,
      width: 8,
      height: 8,
      averageColor: 0xFF888888,
      fromCache: false,
    );

Future<void> _pump(
  WidgetTester tester,
  List<PhotoEntity> photos, {
  Size size = const Size(1200, 800),
  void Function(PhotoEntity photo)? onOpen,
  Map<String, int> placeholders = const {},
  Future<GridThumbnail> Function(PhotoEntity photo)? thumbnail,
  MarkStore? markStore,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // A widget test has no application-support directory to open a database
        // in, so the durable store is stood in for by one that records.
        markStoreProvider.overrideWith(
          (ref) async => markStore ?? InMemoryMarkStore(),
        ),
        placeholderColorsProvider.overrideWith((ref) async => placeholders),
        gridThumbnailProvider.overrideWith(
          (ref, request) => (thumbnail ?? _instant)(request.photo),
        ),
      ],
      child: MaterialApp(
        theme: buildObscuraTheme(),
        home: Scaffold(body: LibraryGrid(photos: photos, onOpen: onOpen)),
      ),
    ),
  );
  await tester.pump();
}

/// The library screen with no card open, on a given sidebar section.
Future<void> _pumpSection(WidgetTester tester, LibrarySection section) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  late ProviderContainer container;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // No card was ever chosen, which is the ordinary first launch.
        availableCardsProvider.overrideWith((ref) async => const []),
        exportStoreProvider.overrideWithValue(InMemoryExportStore()),
        exportMarkStoreProvider.overrideWithValue(InMemoryExportMarkStore()),
        // No application-support directory in a widget test; the store reads
        // from a temp folder that has no settings file, which is the same
        // answer as a first launch.
        settingsStoreProvider.overrideWithValue(
          SettingsStore(directory: () async => Directory.systemTemp),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(
            theme: buildObscuraTheme(),
            home: const Scaffold(body: LibraryScreen()),
          );
        },
      ),
    ),
  );

  container.read(librarySectionProvider.notifier).go(section);
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpBar(WidgetTester tester, Widget bar) async {
  await tester.pumpWidget(
    MaterialApp(theme: buildObscuraTheme(), home: Scaffold(body: bar)),
  );
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// The cell's own box, which is the outermost one under its key — the badge
/// and the trash marker draw boxes of their own.
BoxDecoration _tileDecoration(WidgetTester tester, String radical) => tester
    .widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(Key('cell-100LEICA/$radical')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    )
    .decoration as BoxDecoration;

bool _isSelected(WidgetTester tester, String radical) =>
    _tileDecoration(tester, radical).border?.top.color ==
    ObscuraColors.leicaRed;

String _badgeText(WidgetTester tester, String radical) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(Key('badge-100LEICA/$radical')),
        matching: find.byType(Text),
      ),
    )
    .data!;

PhotoEntity _photo(
  String radical, {
  required bool raw,
  required bool jpeg,
  bool unreadable = false,
}) {
  const stream = PreviewStream(
    offset: 1024,
    length: 512,
    kind: PreviewStreamKind.jpegStrips,
    width: 128,
    height: 85,
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
      if (raw)
        PhotoFile(
          name: '$radical.DNG',
          path: '/nowhere/$radical.DNG',
          kind: PhotoFileKind.raw,
          sizeBytes: 84000000,
          modified: DateTime.utc(2026, 3, 14),
        ),
      if (jpeg)
        PhotoFile(
          name: '$radical.JPG',
          path: '/nowhere/$radical.JPG',
          kind: PhotoFileKind.jpeg,
          sizeBytes: 12000000,
          modified: DateTime.utc(2026, 3, 14),
        ),
    ],
    gridPreview: unreadable ? null : stream,
    viewerPreview: unreadable ? null : stream,
    orientation: ExifOrientation.normal,
  );
}
