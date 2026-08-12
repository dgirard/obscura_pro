import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/theme.dart';
import 'package:obscura_pro/features/exports/export_store.dart';
import 'package:obscura_pro/features/exports/exports_screen.dart';
import 'package:obscura_pro/infra/finder/finder_channel.dart';
import 'package:path/path.dart' as p;

import '../../infra/preview/tiff_fixture.dart';

/// The exports destination: what it shows, and the two things it must not do.
void main() {
  late InMemoryExportStore store;
  late FakeFinder finder;

  setUp(() => finder = FakeFinder());

  /// Where an export would be.
  ///
  /// A path and no file. Nothing here touches the disk on purpose: whether the
  /// file is there is the store's answer — [ExportRecord.missing], faked below
  /// — and real file I/O inside `testWidgets` never completes, because the body
  /// runs on the test binding's own clock and the completion is delivered on
  /// the real one. The pixels are drawn through [exportImageProvider], which
  /// the pump points at memory for the same reason.
  String file(String session, String name) =>
      p.join('/Users/x/Pictures/Q3Culling/Exports', session, name);

  ExportRecord record({
    required int id,
    required String path,
    String radical = '100LEICA/L1000001',
    String ratio = '3:2',
    bool missing = false,
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
        byteSize: missing ? null : 2048,
        missing: missing,
      );

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
        ],
        child: MaterialApp(
          theme: buildObscuraTheme(),
          home: const Scaffold(body: ExportsScreen()),
        ),
      ),
    );
    await tester.pump();
  }

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

  testWidgets('shows an export the user has moved as moved', (tester) async {
    await pump(tester, [
      record(id: 1, path: file('2026-08-01', 'gone.jpg'), missing: true),
    ]);

    expect(find.byKey(const Key('export-missing-1')), findsOneWidget);
    // Nothing to open and nothing to reveal: the file is not there, and
    // offering either would be the app pretending otherwise.
    expect(find.byKey(const Key('export-open-1')), findsNothing);
    expect(find.byKey(const Key('export-reveal-1')), findsNothing);
    // Taking the row off the list is still offered, and is all it does.
    expect(find.byKey(const Key('export-remove-1')), findsOneWidget);
  });

  testWidgets('reveals a file in the Finder', (tester) async {
    final path = file('2026-08-12', 'a.jpg');
    await pump(tester, [record(id: 1, path: path)]);

    await tester.tap(find.byKey(const Key('export-reveal-1')));
    await tester.pump();

    expect(finder.revealed, [path]);
  });

  testWidgets('removing puts the file in the Mac trash, then drops the row',
      (tester) async {
    final path = file('2026-08-12', 'a.jpg');
    await pump(tester, [record(id: 1, path: path)]);

    await tester.tap(find.byKey(const Key('export-remove-1')));
    await tester.pumpAndSettle();

    expect(finder.trashed, [path]);
    expect(store.records, isEmpty);
    expect(find.byKey(const Key('exports-empty')), findsOneWidget);
  });

  testWidgets('a refused trash keeps the row and says why', (tester) async {
    finder = FakeFinder(outcome: FinderOutcome.refused)
      ..lastRefusal = 'volume en lecture seule';
    final path = file('2026-08-12', 'a.jpg');
    await pump(tester, [record(id: 1, path: path)]);

    await tester.tap(find.byKey(const Key('export-remove-1')));
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

