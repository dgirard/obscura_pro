import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/volume_select/card_selection.dart';
import 'package:obscura_pro/infra/card_access/bookmark_store.dart';
import 'package:obscura_pro/infra/card_access/card_access_service.dart';

import '../../infra/card_access/fakes.dart';

/// Reopening last session's card without asking again.
///
/// `reopenLastCard` was written, tested and never called: every launch put the
/// open panel in front of a photographer whose card had not left the reader
/// since yesterday. The bookmark exists precisely so that panel is asked once
/// per card rather than once per morning.
void main() {
  late Directory storage;
  late RecordingBridge bridge;
  late BookmarkStore bookmarks;
  late FakeVolumeChannel channel;

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('obscura_reopen');
    bridge = RecordingBridge();
    bookmarks =
        BookmarkStore(bridge: bridge, storageDirectory: () async => storage);
    channel = FakeVolumeChannel();
  });

  tearDown(() async {
    if (await storage.exists()) await storage.delete(recursive: true);
  });

  /// A container wired to a service that picks [picks] when the panel opens.
  ProviderContainer containerFor({String? picks}) {
    final container = ProviderContainer(
      overrides: [
        cardAccessServiceProvider.overrideWith(
          (ref) => CardAccessService(
            channel: channel,
            bookmarks: bookmarks,
            directoryPicker: ({String? startAt}) async => picks,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('reopens the card the last session was working on', () async {
    final card = await makeCardTree();
    addTearDown(() => card.delete(recursive: true));

    // Yesterday: the user chose the card, which is what mints the bookmark.
    final yesterday = containerFor(picks: card.path);
    await yesterday.read(cardSelectionProvider.notifier).openViaPanel();
    expect(yesterday.read(cardSelectionProvider), isA<CardSelectionOpened>());

    // Today: a new process, a new container, and no panel at all.
    final today = containerFor(picks: null);
    await today.read(cardSelectionProvider.notifier).reopenLast();

    final state = today.read(cardSelectionProvider);
    expect(state, isA<CardSelectionOpened>());
    expect((state as CardSelectionOpened).path, card.path);
    final encodes = bridge.calls.where((c) => c.startsWith('encode')).toList();
    // One trip through the panel, and every bookmark it wrote is for the card
    // it granted: one under `last_card`, one under this card's own key so that
    // it reopens by itself even after another card has been in.
    expect(encodes, hasLength(2));
    expect(encodes.every((c) => c.endsWith(card.path)), isTrue);
  });

  test('falls back to the picker when no card was ever chosen', () async {
    final container = containerFor();

    await container.read(cardSelectionProvider.notifier).reopenLast();

    // The ordinary first launch. Idle is what puts the volume list on screen.
    expect(container.read(cardSelectionProvider), isA<CardSelectionIdle>());
  });

  test('falls back to the picker when the card is not in the reader', () async {
    final card = await makeCardTree();
    final chosen = containerFor(picks: card.path);
    await chosen.read(cardSelectionProvider.notifier).openViaPanel();
    // The card leaves with its DCIM tree, which is what an absent volume looks
    // like to `inspect`.
    await card.delete(recursive: true);

    final container = containerFor();
    await container.read(cardSelectionProvider.notifier).reopenLast();

    expect(container.read(cardSelectionProvider), isA<CardSelectionIdle>());
  });

  test('a bookmark that no longer resolves is not an error the user sees',
      () async {
    final card = await makeCardTree();
    addTearDown(() => card.delete(recursive: true));
    final chosen = containerFor(picks: card.path);
    await chosen.read(cardSelectionProvider.notifier).openViaPanel();

    // What a reformatted card does to a stored bookmark.
    bridge.decodeThrows = StateError('bookmark is stale');
    final container = containerFor();

    await container.read(cardSelectionProvider.notifier).reopenLast();

    expect(container.read(cardSelectionProvider), isA<CardSelectionIdle>());
  });

  test('does not reach for the last card once one is already open', () async {
    final card = await makeCardTree();
    addTearDown(() => card.delete(recursive: true));
    final container = containerFor(picks: card.path);
    await container.read(cardSelectionProvider.notifier).openViaPanel();

    await container.read(cardSelectionProvider.notifier).reopenLast();

    // A launch-time reopen that fired late must not close over a card the user
    // has already chosen by hand in the meantime.
    final state = container.read(cardSelectionProvider);
    expect((state as CardSelectionOpened).path, card.path);
  });
}
