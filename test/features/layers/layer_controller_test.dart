import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/layers/layer_controller.dart';
import 'package:obscura_pro/features/layers/layer_placement.dart';
import 'package:obscura_pro/features/layers/layer_repository.dart';

/// U13/U14. Placing, undoing and writing down a composition.
void main() {
  late InMemoryLayerStore store;
  late ProviderContainer container;

  setUp(() {
    store = InMemoryLayerStore();
    container = ProviderContainer(
      overrides: [layerRepositoryProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
  });

  LayerBoardNotifier notifierFor(PhotoEntity photo) {
    final notifier = container.read(layerBoardProvider.notifier);
    notifier.open(photo);
    return notifier;
  }

  LayerBoard board() => container.read(layerBoardProvider);

  group('placing', () {
    test('drops a full-frame guide, on top and selected', () async {
      final notifier = notifierFor(_photo());
      notifier.place('rule-of-thirds');

      final placed = board().layers.single;
      expect(placed.patternCode, 'rule-of-thirds');
      expect(placed.position, const Offset(0.5, 0.5));
      expect(placed.scaleX, 1);
      expect(placed.scaleY, 1);
      expect(board().selected, placed.localId);
    });

    test('records the obscura mode it was placed in', () async {
      final notifier = notifierFor(_photo());
      notifier.place('golden-spiral', obscura: true);

      expect(board().layers.single.obscura, isTrue);
    });

    test('writes the row, and takes its id back', () async {
      final photo = _photo();
      final notifier = notifierFor(photo);
      notifier.place('rule-of-thirds');
      // The guide is on screen before the write finishes: that is the point of
      // writing through rather than waiting.
      expect(board().layers.single.rowId, isNull);

      await pumpEventQueue();
      expect(board().layers.single.rowId, isNotNull);
      expect(await store.layersOf(photo), hasLength(1));
    });

    test('stacks each new guide above the last', () async {
      final notifier = notifierFor(_photo());
      notifier
        ..place('rule-of-thirds')
        ..place('golden-spiral');

      expect(
        board().layers.map((l) => l.patternCode),
        ['rule-of-thirds', 'golden-spiral'],
      );
      expect(board().layers.first.zIndex, lessThan(board().layers.last.zIndex));
    });
  });

  group('reopening a photograph', () {
    test('brings the composition back, whatever the card is mounted at',
        () async {
      final photo = _photo(mountedAt: '/Volumes/Q3');
      final notifier = notifierFor(photo);
      notifier.place('golden-spiral');
      await pumpEventQueue();

      // Same photograph, same stable key, a different mount point -- AE3.
      final remounted = _photo(mountedAt: '/Volumes/Untitled');
      notifier.open(_photo(radical: 'L1000002'));
      notifier.open(remounted);
      await pumpEventQueue();

      expect(board().layers.single.patternCode, 'golden-spiral');
      expect(board().layers.single.rowId, isNotNull);
    });

    test('a guide placed while the read was in flight is not thrown away',
        () async {
      final photo = _photo();
      await store.save(photo, [
        const LayerPlacement(localId: 7, patternCode: 'rule-of-thirds'),
      ]);

      final notifier = notifierFor(photo);
      notifier.place('symmetry');
      await pumpEventQueue();

      expect(
        board().layers.map((l) => l.patternCode).toSet(),
        {'rule-of-thirds', 'symmetry'},
      );
    });
  });

  group('undo', () {
    test('puts a dragged guide back exactly where it was picked up', () async {
      final notifier = notifierFor(_photo());
      notifier.place('rule-of-thirds');
      final before = board().layers.single;

      notifier.beginChange();
      for (final x in [0.55, 0.6, 0.72]) {
        notifier.apply(before.movedTo(Offset(x, 0.5)));
      }
      notifier.commit();
      expect(board().layers.single.position.dx, 0.72);

      notifier.undo();
      // The whole placement, not just its position: a drag that also changed
      // the scale must come back whole.
      expect(board().layers.single, before);
    });

    test('one step per gesture, not one per frame', () async {
      final notifier = notifierFor(_photo());
      notifier.place('rule-of-thirds');
      final placed = board().layers.single;

      notifier.beginChange();
      notifier.apply(placed.movedTo(const Offset(0.6, 0.5)));
      notifier.apply(placed.movedTo(const Offset(0.7, 0.5)));
      notifier.commit();

      notifier.undo();
      expect(board().layers.single.position.dx, 0.5);
      // And once more takes the placement itself back off.
      notifier.undo();
      expect(board().layers, isEmpty);
    });

    test('redo comes forward again, and a new change closes the branch',
        () async {
      final notifier = notifierFor(_photo());
      notifier.place('rule-of-thirds');
      notifier.undo();
      expect(board().layers, isEmpty);

      notifier.redo();
      expect(board().layers, hasLength(1));

      notifier.undo();
      notifier.place('symmetry');
      expect(board().redoDepth, 0);
    });

    test('undoing a deletion writes the row back', () async {
      final photo = _photo();
      final notifier = notifierFor(photo);
      notifier.place('rule-of-thirds');
      await pumpEventQueue();

      notifier.remove(board().layers.single.localId);
      await pumpEventQueue();
      expect(await store.layersOf(photo), isEmpty);

      notifier.undo();
      await pumpEventQueue();
      expect(await store.layersOf(photo), hasLength(1));
    });
  });

  group('the list', () {
    test('deleting one leaves the others alone', () async {
      final photo = _photo();
      final notifier = notifierFor(photo);
      notifier
        ..place('rule-of-thirds')
        ..place('symmetry')
        ..place('golden-spiral');
      await pumpEventQueue();

      notifier.remove(board().layers[1].localId);
      await pumpEventQueue();

      expect(
        board().layers.map((l) => l.patternCode),
        ['rule-of-thirds', 'golden-spiral'],
      );
      expect(
        (await store.layersOf(photo)).map((l) => l.patternCode),
        ['rule-of-thirds', 'golden-spiral'],
      );
    });

    test('reordering swaps two z-indices and nothing else', () async {
      final notifier = notifierFor(_photo());
      notifier
        ..place('rule-of-thirds')
        ..place('symmetry');
      final zs = board().layers.map((l) => l.zIndex).toList();

      notifier.reorder(board().layers.first.localId, up: true);

      expect(board().layers.map((l) => l.patternCode), ['symmetry', 'rule-of-thirds']);
      expect(board().layers.map((l) => l.zIndex).toList(), zs);
    });

    test('reordering past either end does nothing', () async {
      final notifier = notifierFor(_photo());
      notifier.place('rule-of-thirds');
      final before = board().layers.single;

      notifier.reorder(before.localId, up: true);
      notifier.reorder(before.localId, up: false);

      expect(board().layers.single, before);
      expect(board().undoDepth, 1, reason: 'a no-op must not fill the undo stack');
    });

    test('locking is remembered', () async {
      final photo = _photo();
      final notifier = notifierFor(photo);
      notifier.place('rule-of-thirds');
      notifier.toggleLock(board().layers.single.localId);
      await pumpEventQueue();

      expect(board().layers.single.locked, isTrue);
      expect((await store.layersOf(photo)).single.locked, isTrue);
    });
  });

  group('appearance', () {
    test('acts on the selection when there is one', () async {
      final notifier = notifierFor(_photo());
      notifier
        ..place('rule-of-thirds')
        ..place('symmetry');
      notifier.select(board().layers.first.localId);
      notifier.setAppearance(opacity: 0.2);

      expect(board().layers.first.opacity, 0.2);
      expect(board().layers.last.opacity, 0.6);
    });

    test('acts on every layer when there is not', () async {
      final notifier = notifierFor(_photo());
      notifier
        ..place('rule-of-thirds')
        ..place('symmetry')
        ..select(null);
      notifier.setAppearance(color: 0xFFE11B22);

      expect(board().layers.every((l) => l.color == 0xFFE11B22), isTrue);
    });
  });

  test('a store that refuses keeps the guides and says so', () async {
    final container = ProviderContainer(
      overrides: [layerRepositoryProvider.overrideWithValue(_BrokenStore())],
    );
    addTearDown(container.dispose);

    final notifier = container.read(layerBoardProvider.notifier)
      ..open(_photo());
    notifier.place('rule-of-thirds');
    await pumpEventQueue();

    final state = container.read(layerBoardProvider);
    // The decision the user made stands; what is lost is the promise that it
    // will still be there tomorrow, and the panel states it.
    expect(state.layers, hasLength(1));
    expect(state.durable, isFalse);
    expect(state.failure, contains('disque'));
  });
}

/// One photograph, at a given mount point.
///
/// The stable key does not depend on the path, which is the whole of AE3: the
/// same card in a different reader is the same photographs.
PhotoEntity _photo({
  String radical = 'L1000001',
  String mountedAt = '/Volumes/Q3',
}) =>
    PhotoEntity(
      radical: radical,
      folder: '100LEICA',
      key: StableKey.fromExif(
        dcfRadical: '100LEICA/$radical',
        captureTime: DateTime.utc(2026, 3, 14, 9, 26, 53),
        bodySerial: '5301234',
      ),
      files: [
        PhotoFile(
          name: '$radical.DNG',
          path: '$mountedAt/DCIM/100LEICA/$radical.DNG',
          kind: PhotoFileKind.raw,
          sizeBytes: 84000000,
          modified: DateTime.utc(2026, 3, 14),
        ),
      ],
    );

class _BrokenStore implements LayerStore {
  @override
  Future<List<LayerPlacement>> layersOf(PhotoEntity photo) async => const [];

  @override
  Future<List<LayerPlacement>> save(
    PhotoEntity photo,
    List<LayerPlacement> placements,
  ) async =>
      throw StateError('le disque a refusé l\'écriture');
}
