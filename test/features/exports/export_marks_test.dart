import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/exports/export_marks.dart';
import 'package:obscura_pro/infra/db/database.dart';

/// The other decision of a culling pass: which frames are wanted.
void main() {
  group('on disk', () {
    late AppDatabase db;
    late DriftExportMarkStore store;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      store = DriftExportMarkStore(db);
    });

    tearDown(() => db.close());

    test('remembers a photograph the app had never seen before', () async {
      await store.mark(_photo());

      expect(await store.markedKeys(), {_photo().key.value});
      // The photo row is created by the mark, the same way a deletion mark
      // creates it: a decision about a frame is the first thing this app knows
      // about most frames.
      expect(await db.catalogDao.allPhotos(), hasLength(1));
    });

    test('marking twice is one decision, not two', () async {
      await store.mark(_photo());
      await store.mark(_photo());

      expect(await store.markedKeys(), hasLength(1));
    });

    test('unmarking takes it off, and unmarking a stranger does nothing',
        () async {
      await store.mark(_photo());
      await store.unmark(_photo());
      await store.unmark(_photo(radical: 'L1009999'));

      expect(await store.markedKeys(), isEmpty);
    });

    test('finds the mark through the stable key, not the path', () async {
      await store.mark(_photo(mountedAt: '/Volumes/Q3'));

      // Same card, another reader: the same photograph, so the same mark.
      expect(
        await store.markedKeys(),
        contains(_photo(mountedAt: '/Volumes/NO NAME').key.value),
      );
    });

    test('forgetting a photograph takes its mark with it', () async {
      await store.mark(_photo());
      final row = await db.catalogDao.photoByStableKey(_photo().key.value);

      await db.catalogDao.purgePhoto(row!.id);

      expect(await store.markedKeys(), isEmpty);
    });
  });

  group('in the session', () {
    late InMemoryExportMarkStore store;
    late ProviderContainer container;

    setUp(() {
      store = InMemoryExportMarkStore();
      container = ProviderContainer(
        overrides: [exportMarkStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
    });

    test('the badge arrives on the keystroke, not on the write', () async {
      final notifier = container.read(exportMarksProvider.notifier);
      final future = notifier.toggle(_photo());

      // Culling is a keyboard activity: the mark is true the moment it is made.
      expect(container.read(exportMarksProvider).length, 1);
      await future;
      expect(await store.markedKeys(), hasLength(1));
    });

    test('toggles back off', () async {
      final notifier = container.read(exportMarksProvider.notifier);
      await notifier.toggle(_photo());
      await notifier.toggle(_photo());

      expect(container.read(exportMarksProvider).isEmpty, isTrue);
      expect(await store.markedKeys(), isEmpty);
    });

    test('reads back what an earlier session marked', () async {
      final store = InMemoryExportMarkStore(initial: {_photo().key.value});
      final container = ProviderContainer(
        overrides: [exportMarkStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      container.read(exportMarksProvider);
      await pumpEventQueue();

      expect(container.read(exportMarksProvider).length, 1);
    });

    test('a store that refuses keeps the mark and says so', () async {
      final container = ProviderContainer(
        overrides: [exportMarkStoreProvider.overrideWithValue(_BrokenStore())],
      );
      addTearDown(container.dispose);

      await container.read(exportMarksProvider.notifier).toggle(_photo());

      final queue = container.read(exportMarksProvider);
      // The decision stands; what is lost is its survival, and the interface
      // says which.
      expect(queue.length, 1);
      expect(queue.durable, isFalse);
      expect(queue.failure, contains('disque'));
    });
  });
}

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

class _BrokenStore implements ExportMarkStore {
  @override
  Future<Set<String>> markedKeys() async => const {};

  @override
  Future<void> mark(PhotoEntity photo) async =>
      throw StateError('le disque a refusé l\'écriture');

  @override
  Future<void> unmark(PhotoEntity photo) async => throw StateError('idem');
}
