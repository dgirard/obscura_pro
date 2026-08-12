import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infra/card_access/bookmark_store.dart';
import '../../infra/card_access/card_access_service.dart';
import '../../infra/card_access/models.dart';
import '../../infra/card_access/volume_channel.dart';

final volumeChannelProvider = Provider<VolumeChannel>((ref) => VolumeChannel());

final bookmarkStoreProvider = Provider<BookmarkStore>(
  (ref) => BookmarkStore(bridge: PlatformSecureBookmarkBridge()),
);

final cardAccessServiceProvider = Provider<CardAccessService>(
  (ref) => CardAccessService(
    channel: ref.watch(volumeChannelProvider),
    bookmarks: ref.watch(bookmarkStoreProvider),
  ),
);

/// Removable volumes currently mounted.
///
/// Re-read whenever a volume appears or disappears, so pulling a card out
/// updates the picker without the user doing anything.
final availableCardsProvider = FutureProvider<List<MountedVolume>>((ref) async {
  ref.watch(volumeEventsProvider);
  return ref.watch(cardAccessServiceProvider).availableCards();
});

final volumeEventsProvider = StreamProvider<VolumeEvent>(
  (ref) => ref.watch(cardAccessServiceProvider).watchVolumes(),
);

/// Where the user is in the act of opening a card.
sealed class CardSelection {
  const CardSelection();
}

class CardSelectionIdle extends CardSelection {
  const CardSelectionIdle();
}

class CardSelectionBusy extends CardSelection {
  const CardSelectionBusy();
}

/// The chosen folder is not a camera card. Reported rather than silently
/// scanned, so picking the wrong folder does not look like an empty card.
class CardSelectionRejected extends CardSelection {
  const CardSelectionRejected(this.check);
  final CardMissingDcim check;
}

class CardSelectionOpened extends CardSelection {
  const CardSelectionOpened(this.path, this.check);
  final String path;
  final CardCheck check;
}

class CardSelectionNotifier extends Notifier<CardSelection> {
  @override
  CardSelection build() => const CardSelectionIdle();

  CardAccessService get _service => ref.read(cardAccessServiceProvider);

  /// Opens a volume the user picked from the list.
  ///
  /// Still goes through the open panel: under the sandbox the app has no
  /// standing access to a mounted volume just because it can see it in the
  /// list. Seeing and reading are different grants.
  Future<void> openViaPanel({String? startAt}) async {
    state = const CardSelectionBusy();
    try {
      final check = await _service.chooseCard(startAt: startAt);
      if (check == null) {
        state = const CardSelectionIdle();
        return;
      }
      if (check is CardMissingDcim) {
        state = CardSelectionRejected(check);
        return;
      }
      state = CardSelectionOpened(_rootOf(check), check);
    } catch (_) {
      state = const CardSelectionIdle();
      rethrow;
    }
  }

  /// Re-opens last session's card, if it is still in the reader.
  ///
  /// The bookmark minted when the user chose it is the whole point of a
  /// security-scoped bookmark: the grant survives the relaunch, so a
  /// photographer who is still working on the same card does not have to answer
  /// the same panel every morning. Nothing is written and nothing is scanned
  /// that would not have been scanned anyway.
  ///
  /// Silent when it cannot. A card that is not there is the ordinary case and
  /// the picker is already the answer to it; so is a bookmark that no longer
  /// resolves, which is what a reformatted card looks like from here. Failing
  /// loudly at launch over either would be shouting about the normal state of
  /// the world.
  Future<void> reopenLast() async {
    if (state is! CardSelectionIdle) return;
    state = const CardSelectionBusy();
    try {
      final check = await _service.reopenLastCard();
      state = check == null || check is CardMissingDcim
          ? const CardSelectionIdle()
          : CardSelectionOpened(_rootOf(check), check);
    } on Object {
      state = const CardSelectionIdle();
    }
  }

  /// Opens a card that is in the reader and has been granted before.
  ///
  /// Called at launch after [reopenLast], and again whenever a volume appears
  /// while the app is running. A photographer who puts a card in expects to see
  /// their photographs, not a panel asking permission they have already given.
  Future<void> openKnown() async {
    if (state is! CardSelectionIdle) return;
    final cards = await ref.read(cardAccessServiceProvider).availableCards();
    if (cards.isEmpty) return;
    if (state is! CardSelectionIdle) return;

    state = const CardSelectionBusy();
    try {
      final check = await _service.reopenKnownCard(cards.map((c) => c.path));
      state = check == null || check is CardMissingDcim
          ? const CardSelectionIdle()
          : CardSelectionOpened(_rootOf(check), check);
    } on Object {
      state = const CardSelectionIdle();
    }
  }

  void reset() => state = const CardSelectionIdle();

  static String _rootOf(CardCheck check) => switch (check) {
        CardAccepted(:final dcimPath) => _parentOf(dcimPath),
        CardEmpty(:final dcimPath) => _parentOf(dcimPath),
        _ => '',
      };

  static String _parentOf(String dcimPath) {
    final index = dcimPath.lastIndexOf('/DCIM');
    return index <= 0 ? dcimPath : dcimPath.substring(0, index);
  }
}

final cardSelectionProvider =
    NotifierProvider<CardSelectionNotifier, CardSelection>(
  CardSelectionNotifier.new,
);
