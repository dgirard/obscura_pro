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
  Future<void> openViaPanel() async {
    state = const CardSelectionBusy();
    try {
      final check = await _service.chooseCard();
      if (check == null) {
        state = const CardSelectionIdle();
        return;
      }
      if (check is CardMissingDcim) {
        state = CardSelectionRejected(check);
        return;
      }
      final path = switch (check) {
        CardAccepted(:final dcimPath) => _parentOf(dcimPath),
        CardEmpty(:final dcimPath) => _parentOf(dcimPath),
        _ => '',
      };
      state = CardSelectionOpened(path, check);
    } catch (_) {
      state = const CardSelectionIdle();
      rethrow;
    }
  }

  void reset() => state = const CardSelectionIdle();

  static String _parentOf(String dcimPath) {
    final index = dcimPath.lastIndexOf('/DCIM');
    return index <= 0 ? dcimPath : dcimPath.substring(0, index);
  }
}

final cardSelectionProvider =
    NotifierProvider<CardSelectionNotifier, CardSelection>(
  CardSelectionNotifier.new,
);
