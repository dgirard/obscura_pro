import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/infra/card_access/bookmark_store.dart';
import 'package:obscura_pro/infra/card_access/card_access_service.dart';
import 'package:obscura_pro/infra/card_access/models.dart';

import 'fakes.dart';

void main() {
  late Directory storage;
  late RecordingBridge bridge;
  late BookmarkStore bookmarks;
  late FakeVolumeChannel channel;

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('obscura_service');
    bridge = RecordingBridge();
    bookmarks =
        BookmarkStore(bridge: bridge, storageDirectory: () async => storage);
    channel = FakeVolumeChannel();
  });

  tearDown(() async {
    if (await storage.exists()) await storage.delete(recursive: true);
  });

  CardAccessService serviceFor({String? picks}) => CardAccessService(
        channel: channel,
        bookmarks: bookmarks,
        directoryPicker: ({String? startAt}) async => picks,
      );

  group('offering volumes', () {
    test('offers only the volumes that could be a card', () async {
      channel.volumes = [
        fakeVolume('Macintosh HD', path: '/', removable: false, ejectable: false, internal: true),
        fakeVolume('LEICA Q3'),
      ];

      final offered = await serviceFor().availableCards();

      expect(offered.map((v) => v.name), ['LEICA Q3']);
    });
  });

  group('inspecting a folder', () {
    test('accepts a folder holding DCIM/100LEICA', () async {
      final card = await makeCardTree();
      addTearDown(() => card.delete(recursive: true));

      final check = await serviceFor().inspect(card.path);

      expect(check, isA<CardAccepted>());
      expect((check as CardAccepted).cameraFolders, ['100LEICA']);
    });

    test('orders the image folders so 100LEICA precedes 101LEICA', () async {
      final card = await makeCardTree(imageFolders: ['101LEICA', '100LEICA']);
      addTearDown(() => card.delete(recursive: true));

      final check = await serviceFor().inspect(card.path) as CardAccepted;

      expect(check.cameraFolders, ['100LEICA', '101LEICA']);
    });

    test('rejects a folder with no DCIM at all', () async {
      final plain = await Directory.systemTemp.createTemp('obscura_plain');
      addTearDown(() => plain.delete(recursive: true));

      expect(await serviceFor().inspect(plain.path), isA<CardMissingDcim>());
    });

    test('treats a DCIM holding nothing DCF-shaped as an empty card', () async {
      final card = await makeCardTree(imageFolders: const []);
      addTearDown(() => card.delete(recursive: true));
      await Directory('${card.path}/DCIM/notes').create();

      // An empty card is readable and ordinary; only a missing DCIM means the
      // user picked the wrong folder.
      expect(await serviceFor().inspect(card.path), isA<CardEmpty>());
    });

    test('rejects a folder that does not exist rather than throwing', () async {
      expect(
        await serviceFor().inspect('/nowhere/at/all'),
        isA<CardMissingDcim>(),
      );
    });
  });

  group('choosing a card', () {
    test('remembers an accepted card for the next session', () async {
      final card = await makeCardTree();
      addTearDown(() => card.delete(recursive: true));
      final service = serviceFor(picks: card.path);

      final check = await service.chooseCard();
      addTearDown(service.dispose);

      expect(check, isA<CardAccepted>());
      expect(await bookmarks.resolve(CardAccessService.lastCardKey),
          isA<BookmarkResolved>());
    });

    test('takes the sandbox grant when the card opens', () async {
      final card = await makeCardTree();
      addTearDown(() => card.delete(recursive: true));
      final service = serviceFor(picks: card.path);

      await service.chooseCard();
      addTearDown(service.dispose);

      expect(bridge.started, 1);
      expect(service.openCardPath, card.path);
    });

    test('does not remember a folder that is not a card', () async {
      final plain = await Directory.systemTemp.createTemp('obscura_plain');
      addTearDown(() => plain.delete(recursive: true));

      final check = await serviceFor(picks: plain.path).chooseCard();

      expect(check, isA<CardMissingDcim>());
      // Remembering the wrong folder would reopen it on the next launch and
      // present the user with the same dead end.
      expect(await bookmarks.resolve(CardAccessService.lastCardKey),
          isA<BookmarkAbsent>());
    });

    test('treats a dismissed open panel as a cancellation', () async {
      expect(await serviceFor(picks: null).chooseCard(), isNull);
      expect(bridge.started, 0);
    });

    test('resolves the bookmark before taking the scope', () async {
      final card = await makeCardTree();
      addTearDown(() => card.delete(recursive: true));
      final service = serviceFor(picks: card.path);

      await service.chooseCard();
      addTearDown(service.dispose);

      // The order is the whole point. Apple's
      // startAccessingSecurityScopedResource accepts only the URL that came out
      // of resolving a bookmark, so taking the scope before the resolve fails —
      // and fails with a message about a malformed argument, which sends anyone
      // reading it looking in the wrong place.
      final encode = bridge.calls.indexWhere((c) => c.startsWith('encode:'));
      final decode = bridge.calls.indexWhere((c) => c.startsWith('decode:'));
      final start = bridge.calls.indexWhere((c) => c.startsWith('start:'));

      expect(encode, lessThan(decode));
      expect(decode, lessThan(start));
      expect(service.cardSurvivesRelaunch, isTrue);
    });

    test('opens the card even when the scope cannot be taken', () async {
      final card = await makeCardTree();
      addTearDown(() => card.delete(recursive: true));
      bridge.startAccessThrows = StateError('no scope for you');
      final service = serviceFor(picks: card.path);

      final check = await service.chooseCard();
      addTearDown(service.dispose);

      // The panel already granted this process access; the scope only makes it
      // survive a relaunch. Losing the session over it would show the user
      // nothing at all in exchange for strictness.
      expect(check, isA<CardAccepted>());
      expect(service.openCardPath, card.path);
      expect(service.cardSurvivesRelaunch, isFalse);
      expect(service.scopeFailure, contains('no scope for you'));
    });

    test('does not release a scope it never took', () async {
      final card = await makeCardTree();
      addTearDown(() => card.delete(recursive: true));
      bridge.startAccessThrows = StateError('no scope for you');
      final service = serviceFor(picks: card.path);
      await service.chooseCard();

      await service.closeCard();

      // Apple is as explicit about stopping a scope that never started as about
      // never stopping one.
      expect(bridge.stopped, 0);
    });
  });

  group('losing the card', () {
    test('announces the card going away while it is open', () async {
      final card = await makeCardTree();
      addTearDown(() => card.delete(recursive: true));
      final service = serviceFor(picks: card.path);
      await service.chooseCard();
      addTearDown(service.dispose);

      final lost = service.cardLost.first;
      channel.events.add(VolumeEvent(VolumeEventKind.unmounted, card.path));

      expect(await lost, card.path);
    });

    test('announces a warning before the volume goes, not only after', () async {
      final card = await makeCardTree();
      addTearDown(() => card.delete(recursive: true));
      final service = serviceFor(picks: card.path);
      await service.chooseCard();
      addTearDown(service.dispose);

      final lost = service.cardLost.first;
      // willUnmount is the last moment an operation in flight can still stop.
      channel.events.add(VolumeEvent(VolumeEventKind.willUnmount, card.path));

      expect(await lost, card.path);
    });

    test('ignores another volume being unmounted', () async {
      final card = await makeCardTree();
      addTearDown(() => card.delete(recursive: true));
      final service = serviceFor(picks: card.path);
      await service.chooseCard();
      addTearDown(service.dispose);

      var announced = false;
      service.cardLost.listen((_) => announced = true);
      channel.events.add(
        const VolumeEvent(VolumeEventKind.unmounted, '/Volumes/Something Else'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(announced, isFalse);
    });
  });

  group('ejecting', () {
    test('releases the grant once the card is out', () async {
      final card = await makeCardTree();
      addTearDown(() => card.delete(recursive: true));
      final service = serviceFor(picks: card.path);
      await service.chooseCard();

      final outcome = await service.eject(card.path);

      expect(outcome, isA<EjectSucceeded>());
      expect(bridge.stopped, 1, reason: 'an unbalanced grant leaks kernel resources');
      expect(service.openCardPath, isNull);
    });

    test('keeps holding the card when the system refuses', () async {
      final card = await makeCardTree();
      addTearDown(() => card.delete(recursive: true));
      channel.ejectOutcome =
          const EjectRefused(code: 'busy', message: 'La carte est occupée.');
      final service = serviceFor(picks: card.path);
      await service.chooseCard();
      addTearDown(service.dispose);

      await service.eject(card.path);

      // The card is still mounted and still ours; dropping the grant here would
      // leave the session unable to read a card that never went anywhere.
      expect(service.openCardPath, card.path);
      expect(bridge.stopped, 0);
    });
  });
}
