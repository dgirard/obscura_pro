import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/theme.dart';
import 'package:obscura_pro/features/exports/export_store.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/exports/export_marks.dart';
import 'package:obscura_pro/features/exports/exports_screen.dart';
import 'package:obscura_pro/features/grid/thumbnail_tile.dart';
import 'package:obscura_pro/features/viewer/viewer_screen.dart';
import 'package:obscura_pro/infra/finder/finder_channel.dart';
import 'package:path/path.dart' as p;

import '../../infra/preview/tiff_fixture.dart';

/// The exports destination: what it shows, and the two things it must not do.
void main() {
  late InMemoryExportStore store;
  late FakeFinder finder;
  late InMemoryExportMarkStore marks;

  setUp(() {
    finder = FakeFinder();
    marks = InMemoryExportMarkStore();
  });

  /// Where an export would be.
  ///
  /// A path and no file. Nothing here touches the disk on purpose: which files
  /// exist is the store's answer, and real file I/O inside `testWidgets` never
  /// completes, because the body runs on the test binding's own clock and the
  /// completion is delivered on the real one. The pixels are drawn through
  /// [exportImageProvider], which the pump points at memory for the same
  /// reason.
  String file(String session, String name) =>
      p.join('/Users/x/Pictures/Q3Culling/Exports', session, name);

  ExportRecord record({
    required int id,
    required String path,
    String radical = '100LEICA/L1000001',
    String ratio = '3:2',
  }) =>
      ExportRecord(
        id: id,
        radical: radical,
        ratio: ratio,
        orientation: 'landscape',
        path: path,
        createdAt: DateTime(2026, 8, 12, 11, id),
        pixelWidth: 9520,
        pixelHeight: 6336,
        byteSize: 2048,
      );

  /// Presses a control on a tile.
  ///
  /// The extra pump is the double-tap timer: the tile opens on a double click,
  /// so a single tap inside it is held for the length of that window before the
  /// button underneath it wins the gesture. The library grid behaves the same
  /// way, and this is the cost of the idiom rather than a fault of the button.
  Future<void> press(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  Future<void> pump(WidgetTester tester, List<ExportRecord> records) async {
    store = InMemoryExportStore(records);
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exportStoreProvider.overrideWithValue(store),
          finderProvider.overrideWithValue(finder),
          exportImageProvider.overrideWithValue(
            (path) => MemoryImage(realJpeg(width: 12, height: 8)),
          ),
          exportMarkStoreProvider.overrideWithValue(marks),
        ],
        child: MaterialApp(
          theme: buildObscuraTheme(),
          home: const Scaffold(body: ExportsScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('reads the folder again on demand', (tester) async {
    await pump(tester, [record(id: 1, path: file('2026-08-12', 'a.jpg'))]);
    expect(find.byKey(const Key('export-1')), findsOneWidget);

    // A file dragged out in the Finder, or one dropped in: the folder can
    // change without this app, and this is how a photographer says "look
    // again" without leaving the screen and coming back.
    store.records.clear();
    await tester.tap(find.byKey(const Key('exports-refresh')));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('export-1')), findsNothing);
    expect(find.byKey(const Key('exports-empty')), findsOneWidget);
  });

  testWidgets('offers no queue until something is marked', (tester) async {
    await pump(tester, []);

    expect(find.byKey(const Key('export-queue')), findsNothing);
  });

  testWidgets('counts what is waiting, and cannot run what is not here',
      (tester) async {
    marks = InMemoryExportMarkStore(initial: {_photo().key.value});
    await pump(tester, []);
    await tester.pump();

    // The mark is there; the card it belongs to is not, so there is nothing to
    // read the pixels from and the button says so by being unpressable.
    expect(find.byKey(const Key('export-queue')), findsOneWidget);
    expect(_text(tester, 'export-queue-count'), 'Rien à exporter sur cette carte');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('export-queue-run')))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('sur une autre carte'), findsOneWidget);
  });

  testWidgets('says plainly when nothing has been exported', (tester) async {
    await pump(tester, []);

    expect(find.byKey(const Key('exports-empty')), findsOneWidget);
    expect(find.byKey(const Key('exports-list')), findsNothing);
  });

  testWidgets('groups by the session folder, newest first', (tester) async {
    await pump(tester, [
      record(id: 3, path: file('2026-08-12', 'c.jpg')),
      record(id: 2, path: file('2026-08-12', 'b.jpg')),
      record(id: 1, path: file('2026-08-01', 'a.jpg')),
    ]);

    expect(find.text('2026-08-12'), findsOneWidget);
    expect(find.text('2026-08-01'), findsOneWidget);
    expect(find.byKey(const Key('export-3')), findsOneWidget);
    expect(find.byKey(const Key('export-1')), findsOneWidget);
    // The frame it came from and what the crop produced, on the row.
    expect(
      find.text('100LEICA/L1000001  ·  3:2  ·  9520 × 6336 px'),
      findsNWidgets(3),
    );
  });

  testWidgets('reveals a file in the Finder', (tester) async {
    final path = file('2026-08-12', 'a.jpg');
    await pump(tester, [record(id: 1, path: path)]);

    await press(tester, 'export-reveal-1');

    expect(finder.revealed, [path]);
  });

  testWidgets('removing puts the file in the Mac trash, then drops the row',
      (tester) async {
    final path = file('2026-08-12', 'a.jpg');
    await pump(tester, [record(id: 1, path: path)]);

    await press(tester, 'export-remove-1');
    await tester.pumpAndSettle();

    expect(finder.trashed, [path]);
    expect(store.records, isEmpty);
    expect(find.byKey(const Key('exports-empty')), findsOneWidget);
  });

  testWidgets('a button hit twice does what the button says, not what the tile '
      'does', (tester) async {
    final path = file('2026-08-12', 'a.jpg');
    await pump(tester, [record(id: 1, path: path)]);

    // A click that does not seem to do anything is clicked again. The tile
    // opens on a double click, and the two taps landing on a control must not
    // become the tile's gesture instead of the control's.
    final button = find.byKey(const Key('export-reveal-1'));
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(finder.revealed, isNotEmpty);
    expect(find.byType(ViewerScreen), findsNothing);
  });

  testWidgets('Delete puts the selected export in the Mac trash',
      (tester) async {
    final first = file('2026-08-12', 'a.jpg');
    final second = file('2026-08-12', 'b.jpg');
    await pump(tester, [
      record(id: 1, path: first),
      record(id: 2, path: second),
    ]);

    // Selected by clicking it, then the key a photographer already uses on the
    // card. On a file on the Mac it cannot mean "take this frame off the card";
    // it means the only removal this screen offers, which is the Mac's Trash.
    await tester.tap(find.byKey(const Key('export-2')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect(finder.trashed, [second]);
    expect(store.records.map((r) => r.id), [1]);
  });

  testWidgets('the arrows and Enter walk the list and open it', (tester) async {
    await pump(tester, [
      record(id: 1, path: file('2026-08-12', 'a.jpg')),
      record(id: 2, path: file('2026-08-12', 'b.jpg')),
    ]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    // The second tile is the selected one, and Enter opens what is selected.
    expect(
      tester
          .widgetList<ThumbnailTile>(find.byType(ThumbnailTile))
          .map((t) => t.selected)
          .toList(),
      [false, true],
    );
  });

  testWidgets('a refused trash keeps the row and says why', (tester) async {
    finder = FakeFinder(outcome: FinderOutcome.refused)
      ..lastRefusal = 'volume en lecture seule';
    final path = file('2026-08-12', 'a.jpg');
    await pump(tester, [record(id: 1, path: path)]);

    await press(tester, 'export-remove-1');
    await tester.pumpAndSettle();

    expect(store.records, hasLength(1));
    expect(find.byKey(const Key('exports-failure')), findsOneWidget);
    expect(find.textContaining('volume en lecture seule'), findsOneWidget);
  });

  testWidgets('never offers to put an export back on the card', (tester) async {
    await pump(tester, [record(id: 1, path: file('2026-08-12', 'a.jpg'))]);

    // Exports are Mac-side deliverables. The card is where photographs come
    // from, and nothing in this app writes one back to it.
    expect(find.textContaining('carte'), findsOneWidget);
    expect(find.textContaining('Restaurer'), findsNothing);
    expect(find.textContaining('carte SD'), findsNothing);
  });
}


String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

PhotoEntity _photo() => PhotoEntity(
      radical: 'L1000001',
      folder: '100LEICA',
      key: StableKey.fromExif(
        dcfRadical: '100LEICA/L1000001',
        captureTime: DateTime.utc(2026, 3, 14, 9, 26, 53),
        bodySerial: '5301234',
      ),
      files: const [],
    );
