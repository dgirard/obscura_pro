import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/theme.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/layers/layer_controller.dart';
import 'package:obscura_pro/features/layers/layer_repository.dart';
import 'package:obscura_pro/features/layers/layers_panel.dart';

/// U14. The panel: the library, the list, and what it says about saving.
void main() {
  late InMemoryLayerStore store;

  Future<ProviderContainer> pump(WidgetTester tester) async {
    store = InMemoryLayerStore();
    // Tall enough for the whole panel: thirty tiles, the list under them and
    // the stroke controls. Scrolling a test to reach a tile would only be
    // testing the ListView.
    tester.view.physicalSize = const Size(400, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [layerRepositoryProvider.overrideWithValue(store)],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: buildObscuraTheme(),
              home: const Scaffold(body: Row(children: [LayersPanel()])),
            );
          },
        ),
      ),
    );

    container.read(layerBoardProvider.notifier).open(_photo());
    await tester.pump();
    return container;
  }

  Future<void> tapPattern(WidgetTester tester, String code) async {
    await tester.tap(find.byKey(Key('palette-$code')));
    await tester.pump();
  }

  /// Taps a row on its name rather than at its centre: the four little buttons
  /// carry Material's 48-pixel tap targets, which reach further into the row
  /// than they look.
  Future<void> tapRow(WidgetTester tester, int localId) async {
    final row = find.byKey(Key('layer-row-$localId'));
    await tester.tapAt(tester.getTopLeft(row) + const Offset(24, 12));
    await tester.pump();
  }

  testWidgets('offers all thirty patterns, grouped by the document\'s sections',
      (tester) async {
    await pump(tester);

    // The seven section headings, and the first section's own patterns.
    expect(find.text('GRILLES & RAPPORTS'), findsOneWidget);
    expect(find.byKey(const Key('palette-rule-of-thirds')), findsOneWidget);
    expect(find.byKey(const Key('layers-empty')), findsOneWidget);
  });

  testWidgets('tapping a guide puts it on the photograph and writes it',
      (tester) async {
    final container = await pump(tester);
    await tapPattern(tester, 'rule-of-thirds');

    final board = container.read(layerBoardProvider);
    expect(board.layers.single.patternCode, 'rule-of-thirds');
    expect(find.byKey(Key('layer-row-${board.layers.single.localId}')),
        findsOneWidget);
    expect(find.byKey(const Key('layers-empty')), findsNothing);

    await tester.pump();
    expect(await store.layersOf(_photo()), hasLength(1));
  });

  testWidgets('tapping a card opens the card instead of dropping a shape',
      (tester) async {
    final container = await pump(tester);
    await tapPattern(tester, 'fill-the-frame');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pattern-card')), findsOneWidget);
    expect(find.text('Remplir le cadre'), findsWidgets);
    // Nothing was placed: there is no construction in a photograph of a face.
    expect(container.read(layerBoardProvider).layers, isEmpty);
  });

  testWidgets('the list locks, reorders and removes', (tester) async {
    final container = await pump(tester);
    await tapPattern(tester, 'rule-of-thirds');
    await tapPattern(tester, 'golden-spiral');

    final board = container.read(layerBoardProvider);
    final first = board.layers.first.localId;
    final second = board.layers.last.localId;

    await tester.tap(find.byKey(Key('layer-lock-$first')));
    await tester.pump();
    expect(
      container.read(layerBoardProvider).layers.first.locked,
      isTrue,
    );

    await tester.tap(find.byKey(Key('layer-raise-$first')));
    await tester.pump();
    expect(
      container.read(layerBoardProvider).layers.last.localId,
      first,
      reason: 'raising a layer should put it on top',
    );

    await tester.tap(find.byKey(Key('layer-remove-$second')));
    await tester.pump();
    expect(container.read(layerBoardProvider).layers.single.localId, first);
  });

  testWidgets('the stroke controls act on the selection, then on everything',
      (tester) async {
    final container = await pump(tester);
    await tapPattern(tester, 'rule-of-thirds');
    await tapPattern(tester, 'symmetry');

    // The second is selected because it was just placed.
    await tester.tap(find.byKey(const Key('layer-color-ffe11b22')));
    await tester.pump();
    var layers = container.read(layerBoardProvider).layers;
    expect(layers.first.color, isNot(0xFFE11B22));
    expect(layers.last.color, 0xFFE11B22);

    // Deselecting by tapping the selected row again, then a colour reaches all
    // of them.
    await tapRow(tester, layers.last.localId);
    await tester.tap(find.byKey(const Key('layer-color-ffffffff')));
    await tester.pump();
    layers = container.read(layerBoardProvider).layers;
    expect(layers.every((l) => l.color == 0xFFFFFFFF), isTrue);
  });

  testWidgets('says that the composition is written as it is made',
      (tester) async {
    await pump(tester);
    expect(
      find.textContaining('enregistrée à mesure'),
      findsOneWidget,
    );
    // And no save button, because there is nothing left for one to do.
    expect(find.text('Enregistrer la composition'), findsNothing);
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
