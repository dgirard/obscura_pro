import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/theme.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/grid/grid_screen.dart';
import 'package:obscura_pro/features/trash/mark_store.dart';
import 'package:obscura_pro/features/trash/trash_providers.dart';
import 'package:obscura_pro/features/trash/trash_screen.dart';
import 'package:obscura_pro/infra/db/database.dart';
import 'package:obscura_pro/infra/preview/preview_extractor.dart';

/// The trash screen, now that marks outlive the session.
///
/// Persistence brought a new way for this screen to lie: the trash table spans
/// every card this Mac has ever culled, while the button at the bottom of the
/// screen only ever acts on the card in the reader.
void main() {
  final photos = [
    _photo('L1000001'),
    _photo('L1000002'),
    _photo('L1000003'),
  ];

  testWidgets('counts what the button will actually delete', (tester) async {
    await _pump(
      tester,
      photos: photos,
      marked: {photos[0].key.value, photos[1].key.value},
      // The table says five photographs are pending; two of them are on this
      // card. Emptying the trash here deletes two.
      summary: const TrashSummary(
        fileCount: 10,
        photoCount: 5,
        pendingBytes: 480000000,
      ),
    );

    expect(_counter(tester, 'trash-photo-count'), '2');
    expect(_counter(tester, 'trash-file-count'), '4');
    expect(_counter(tester, 'trash-bytes'), '192 Mo');
  });

  testWidgets('says where the rest of the trash is rather than hiding it',
      (tester) async {
    await _pump(
      tester,
      photos: photos,
      marked: {photos[0].key.value},
      summary: const TrashSummary(
        fileCount: 6,
        photoCount: 3,
        pendingBytes: 100,
      ),
    );

    expect(find.byKey(const Key('trash-elsewhere')), findsOneWidget);
    expect(find.textContaining('2 autres photographies'), findsOneWidget);
  });

  testWidgets('stays quiet when the whole trash is on this card',
      (tester) async {
    await _pump(
      tester,
      photos: photos,
      marked: {photos[0].key.value},
      summary: const TrashSummary(fileCount: 2, photoCount: 1, pendingBytes: 1),
    );

    expect(find.byKey(const Key('trash-elsewhere')), findsNothing);
  });

  testWidgets('admits it when the decisions are not being written down',
      (tester) async {
    await _pump(
      tester,
      photos: photos,
      marked: const {},
      store: (ref) async => throw StateError('base de données illisible'),
    );

    // The marks still stand for this session. What is gone is the promise that
    // they will be there after a relaunch, and this screen is where a
    // photographer decides whether to carry on.
    expect(find.byKey(const Key('trash-not-durable')), findsOneWidget);
    expect(find.textContaining('base de données illisible'), findsOneWidget);
  });

  testWidgets('offers no irreversible button with no card in the reader',
      (tester) async {
    await _pump(
      tester,
      photos: photos,
      marked: {photos[0].key.value},
    );

    final empty =
        tester.widget<FilledButton>(find.byKey(const Key('trash-empty')));
    expect(empty.onPressed, isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required List<PhotoEntity> photos,
  required Set<String> marked,
  TrashSummary summary = TrashSummary.empty,
  Future<MarkStore> Function(Ref ref)? store,
}) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        markStoreProvider.overrideWith(
          store ?? (ref) async => InMemoryMarkStore(initial: marked),
        ),
        trashSummaryProvider.overrideWith((ref) => Stream.value(summary)),
        cardCatalogProvider.overrideWith(
          (ref) async => CardCatalog(
            photos: photos,
            unsupportedFiles: const [],
            scanDuration: Duration.zero,
          ),
        ),
      ],
      child: MaterialApp(
        theme: buildObscuraTheme(),
        home: const Scaffold(body: TrashScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

String _counter(WidgetTester tester, String key) => tester
    .widgetList<Text>(find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(Text),
    ))
    .last
    .data!;

PhotoEntity _photo(String radical) => PhotoEntity(
      radical: radical,
      folder: '100LEICA',
      key: StableKey.fromExif(
        dcfRadical: '100LEICA/$radical',
        captureTime: DateTime.utc(2026, 3, 14, 9, 26, 53),
        bodySerial: radical,
      ),
      files: [
        PhotoFile(
          name: '$radical.DNG',
          path: '/nowhere/$radical.DNG',
          kind: PhotoFileKind.raw,
          sizeBytes: 84000000,
          modified: DateTime.utc(2026, 3, 14),
        ),
        PhotoFile(
          name: '$radical.JPG',
          path: '/nowhere/$radical.JPG',
          kind: PhotoFileKind.jpeg,
          sizeBytes: 12000000,
          modified: DateTime.utc(2026, 3, 14),
        ),
      ],
      gridPreview: null,
      viewerPreview: null,
      orientation: ExifOrientation.normal,
    );
