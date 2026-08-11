import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/catalog/photo_entity.dart';
import '../features/grid/grid_screen.dart';
import '../features/volume_select/card_selection.dart';
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

    var markedBytes = 0;
    for (final photo in photos) {
      if (marked.contains(photo.key.value)) markedBytes += photo.totalBytes;
    }

    return StatusBar(
      photoCount: photos.length,
      markedCount: marked.length,
      markedBytes: markedBytes,
      hints: '↑↓←→ naviguer   ⏎ ouvrir   ⌫ marquer à supprimer',
      cardFreeBytes: volume?.freeBytes,
      // The volume list can lag a freshly opened card; the path's last segment
      // is the same name, and a status bar that goes briefly blank reads as a
      // card that has gone away.
      cardName: volume?.name ?? cardPath?.split('/').last,
    );
  }
}
