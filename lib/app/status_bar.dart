import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/catalog/photo_entity.dart';
import '../features/grid/grid_screen.dart';
import '../features/trash/trash_providers.dart';
import '../features/volume_select/card_selection.dart';
import '../features/viewer/viewer_screen.dart' show viewerOpenProvider;
import '../features/volume_select/volume_screen.dart' show formatBytes;
import 'theme.dart';

/// The strip along the bottom of the window.
///
/// Stateless and fed by its arguments so it can be checked without a card, a
/// database or a scan; [LibraryStatusBar] is the one that reads the session.
class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    required this.photoCount,
    this.markedCount = 0,
    this.markedBytes = 0,
    this.marksAreDurable = true,
    this.cardFreeBytes,
    this.cardName,
    this.hints,
  });

  final int photoCount;

  /// How many photographs are marked for deletion, and what emptying the trash
  /// would reclaim.
  ///
  /// Quoted in bytes because that is the question a photographer is actually
  /// asking of a full card, and because a count alone hides the difference
  /// between marking twelve JPEGs and marking twelve RAW+JPG pairs.
  final int markedCount;
  final int markedBytes;

  /// Whether those marks are reaching the disk.
  ///
  /// False is rare and worth a line of the strip: the decisions still stand for
  /// this session, but they will not be there after a relaunch, and a
  /// photographer three hundred frames into a pass should learn that now rather
  /// than by starting again.
  final bool marksAreDurable;

  /// Null when the file system reported no capacity, which is normal for some
  /// mounts and is distinct from a card with no room left.
  final int? cardFreeBytes;
  final String? cardName;

  /// The keyboard bindings that apply where the user is.
  final String? hints;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(
        horizontal: ObscuraSpacing.overlayPadding,
      ),
      color: ObscuraColors.canvas,
      child: Row(
        children: [
          _Field(
            key: const Key('status-photo-count'),
            child: Text(
              photoCount == 1 ? '1 photographie' : '$photoCount photographies',
            ),
          ),
          if (markedCount > 0)
            _Field(
              key: const Key('status-marked'),
              tone: ObscuraColors.statusDelete,
              child: Text(
                '$markedCount à supprimer · ${formatBytes(markedBytes)}',
              ),
            ),
          if (!marksAreDurable)
            _Field(
              key: const Key('status-marks-volatile'),
              tone: ObscuraColors.leicaRed,
              child: const Text('marques non enregistrées'),
            ),
          if (cardFreeBytes != null)
            _Field(
              key: const Key('status-card-free'),
              child: Text('Carte : ${formatBytes(cardFreeBytes!)} libres'),
            ),
          const Spacer(),
          // The keyboard map, stated rather than assumed. Everything here is
          // also reachable by pointer, but a culling session is a keyboard
          // activity and a photographer cannot use a binding they were never
          // told about.
          _Field(
            key: const Key('status-keys'),
            child: Text(hints ?? ''),
          ),
          if (cardName != null)
            _Field(
              key: const Key('status-card-name'),
              child: Text(cardName!),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({super.key, required this.child, this.tone});

  final Widget child;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: ObscuraSpacing.overlayPadding),
      child: DefaultTextStyle(
        style: ObscuraTypography.bodySmall.copyWith(
          color: tone ?? ObscuraColors.textSecondary,
        ),
        child: child,
      ),
    );
  }
}

/// The status bar filled from the open session.
class LibraryStatusBar extends ConsumerWidget {
  const LibraryStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos =
        ref.watch(cardCatalogProvider).value?.photos ?? const <PhotoEntity>[];
    final marked = ref.watch(markedForDeletionProvider);
    final selection = ref.watch(cardSelectionProvider);
    final cardPath = selection is CardSelectionOpened ? selection.path : null;

    final volumes = ref.watch(availableCardsProvider).value;
    final volume = cardPath == null || volumes == null
        ? null
        : volumes.where((v) => v.path == cardPath).firstOrNull;

    // Counted over the open card rather than off [Marks.length]. Marks are
    // durable and the set spans every card this Mac has ever culled, so a fresh
    // card would otherwise report a dozen photographs waiting to be deleted and
    // no bytes to reclaim from them.
    var markedCount = 0;
    var markedBytes = 0;
    for (final photo in photos) {
      if (!marked.contains(photo.key.value)) continue;
      markedCount++;
      markedBytes += photo.totalBytes;
    }

    return StatusBar(
      photoCount: photos.length,
      markedCount: markedCount,
      markedBytes: markedBytes,
      marksAreDurable: marked.durable,
      // Where the user is decides which map applies: Enter opens from the grid
      // and returns from the viewer, and stating the wrong one is worse than
      // stating none.
      hints: ref.watch(viewerOpenProvider)
          ? '←→ naviguer   O obscura   ⌘+/⌘− zoom   ⏎ retour   ⌫ marquer'
          : '↑↓←→ naviguer   ⏎ ouvrir   ⌫ marquer à supprimer',
      cardFreeBytes: volume?.freeBytes,
      // The volume list can lag a freshly opened card; the path's last segment
      // is the same name, and a status bar that goes briefly blank reads as a
      // card that has gone away.
      cardName: volume?.name ?? cardPath?.split('/').last,
    );
  }
}
