import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/infra/card_access/bookmark_store.dart';
import 'package:obscura_pro/infra/card_access/models.dart';

import 'fakes.dart';

void main() {
  late Directory storage;
  late RecordingBridge bridge;
  late BookmarkStore store;

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('obscura_bookmarks');
    bridge = RecordingBridge();
    store = BookmarkStore(bridge: bridge, storageDirectory: () async => storage);
  });

  tearDown(() async {
    if (await storage.exists()) await storage.delete(recursive: true);
  });

  group('remembering a card', () {
    test('gives back the directory that was remembered', () async {
      await store.save('last_card', '/Volumes/LEICA Q3');

      final resolution = await store.resolve('last_card');

      expect(resolution, isA<BookmarkResolved>());
      expect((resolution as BookmarkResolved).path, '/Volumes/LEICA Q3');
    });

    test('survives being rebuilt, so a later session reopens the card', () async {
      await store.save('last_card', '/Volumes/LEICA Q3');

      // A new store over the same directory stands in for the next launch.
      final next =
          BookmarkStore(bridge: bridge, storageDirectory: () async => storage);

      expect(await next.resolve('last_card'), isA<BookmarkResolved>());
    });

    test('reports no bookmark at all as absent, not as stale', () async {
      // The UI reacts differently: absent means first run, stale means the card
      // the user already chose is no longer reachable.
      expect(await store.resolve('last_card'), isA<BookmarkAbsent>());
    });

    test('reports a bookmark the platform cannot resolve as stale', () async {
      await store.save('last_card', '/Volumes/LEICA Q3');
      bridge.decodeThrows = StateError('bookmark data is stale');

      expect(await store.resolve('last_card'), isA<BookmarkStale>());
    });

    test('forgetting brings back the absent outcome', () async {
      await store.save('last_card', '/Volumes/LEICA Q3');
      await store.forget('last_card');

      expect(await store.resolve('last_card'), isA<BookmarkAbsent>());
    });

    test('treats a corrupt store as empty rather than refusing to launch', () async {
      await File('${storage.path}/${BookmarkStore.fileName}')
          .writeAsString('{not json');

      expect(await store.resolve('last_card'), isA<BookmarkAbsent>());
    });
  });

  group('scoped access', () {
    test('releases after the body returns', () async {
      await store.withAccess('/Volumes/LEICA Q3', () async => 'done');

      expect(bridge.started, 1);
      expect(bridge.stopped, 1);
    });

    test('releases when the body throws', () async {
      // The leak Apple warns about lives on this path, and a happy-path test
      // would never see it.
      await expectLater(
        store.withAccess('/Volumes/LEICA Q3', () async => throw StateError('boom')),
        throwsStateError,
      );

      expect(bridge.started, 1);
      expect(bridge.stopped, 1);
    });

    test('pairs a held scope with its release', () async {
      await store.beginAccess('/Volumes/LEICA Q3');
      expect(bridge.stopped, 0, reason: 'the grant must survive the call');

      await store.endAccess('/Volumes/LEICA Q3');
      expect(bridge.started, 1);
      expect(bridge.stopped, 1);
    });
  });
}
