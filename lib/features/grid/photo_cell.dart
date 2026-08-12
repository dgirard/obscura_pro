import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../catalog/photo_entity.dart';
import 'thumbnail_provider.dart';
import 'thumbnail_tile.dart';

/// What a cell asks the pipeline for: one photograph at one size.
///
/// A record rather than a class so the provider family gets value equality for
/// free — two cells asking for the same photograph at the same size are the
/// same request, and must not decode twice.
typedef ThumbnailRequestFor = ({PhotoEntity photo, int shortSide});

/// One cell's image.
///
/// Auto-disposing on purpose: when a cell scrolls out of the viewport its
/// provider is torn down, and the teardown withdraws the request. On a card
/// where a fast scroll can fly past hundreds of cells, that is the difference
/// between a decode queue that tracks the viewport and one that spends minutes
/// catching up on frames nobody is looking at any more.
final gridThumbnailProvider = FutureProvider.autoDispose
    .family<GridThumbnail, ThumbnailRequestFor>((ref, request) async {
  final service = await ref.watch(thumbnailServiceProvider.future);
  ref.onDispose(() => service.cancel(request.photo));
  return service.gridThumbnail(
    request.photo,
    targetShortSide: request.shortSide,
  );
});

/// One photograph in the library grid.
///
/// The tile itself is [ThumbnailTile], shared with the exports grid: two
/// screens showing pictures in a grid have no reason to look like two different
/// applications. What is particular to a photograph on a card lives here — the
/// decode request, the format badge, the mark.
class PhotoCell extends ConsumerStatefulWidget {
  const PhotoCell({
    super.key,
    required this.photo,
    required this.targetShortSide,
    required this.selected,
    required this.marked,
    this.wanted = false,
    this.placeholderColor,
    this.onToggleMark,
    this.onToggleWanted,
  });

  final PhotoEntity photo;

  /// Short side to decode to, in device pixels.
  final int targetShortSide;

  final bool selected;

  /// Marked for deletion. Nothing has been written to the card — marking is
  /// recorded on the Mac and only acted on when the trash is emptied.
  final bool marked;

  /// Marked for export: the other decision of a culling pass. Nothing is
  /// written to the card for this one either.
  final bool wanted;

  /// Mean colour of this photograph's thumbnail, when a previous session left
  /// one in the cache index. Null on a cold cache, where there is nothing
  /// truthful to paint and a neutral surface is shown instead.
  final int? placeholderColor;

  /// Marks or unmarks the photograph. Given a visible control because a
  /// keyboard shortcut with nothing on screen to announce it is not a feature
  /// the user has — it is one they have to be told about.
  final VoidCallback? onToggleMark;

  /// Marks or unmarks the photograph as one to export.
  final VoidCallback? onToggleWanted;

  @override
  ConsumerState<PhotoCell> createState() => _PhotoCellState();
}

class _PhotoCellState extends ConsumerState<PhotoCell> {
  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final marked = widget.marked;
    final placeholderColor = widget.placeholderColor;

    final thumbnail = photo.isUnreadable
        ? const AsyncValue<GridThumbnail>.loading()
        : ref.watch(
            gridThumbnailProvider(
              (photo: photo, shortSide: widget.targetShortSide),
            ),
          );

    return ThumbnailTile(
      semanticLabel: '${photo.radical}, ${photo.formatBadge}',
      selected: widget.selected,
      fill: placeholderColor == null ? null : Color(placeholderColor),
      image: _Image(photo: photo, thumbnail: thumbnail),
      wash: marked
          ? ObscuraColors.statusDelete.withValues(alpha: 0.34)
          : null,
      badge: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          TileBadge(key: Key('badge-${photo.dcfPath}'), text: photo.formatBadge),
          if (widget.wanted) ...[
            const SizedBox(height: ObscuraSpacing.controlGap / 2),
            TileBadge(
              key: Key('wanted-${photo.dcfPath}'),
              text: 'EXPORT',
              color: ObscuraColors.statusExport,
            ),
          ],
        ],
      ),
      // Shown when marked, and offered on hover when not: the control and the
      // state are the same thing in the same place, so seeing one teaches the
      // other.
      cornerOnHover: !marked && !widget.wanted,
      corner: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TrashButton(
            key: marked ? Key('marked-${photo.dcfPath}') : null,
            buttonKey: Key('mark-${photo.dcfPath}'),
            marked: marked,
            onPressed: widget.onToggleMark,
          ),
          const SizedBox(width: ObscuraSpacing.controlGap / 2),
          _WantedButton(
            buttonKey: Key('want-${photo.dcfPath}'),
            wanted: widget.wanted,
            onPressed: widget.onToggleWanted,
          ),
        ],
      ),
    );
  }
}

class _Image extends StatelessWidget {
  const _Image({required this.photo, required this.thumbnail});

  final PhotoEntity photo;
  final AsyncValue<GridThumbnail> thumbnail;

  @override
  Widget build(BuildContext context) {
    if (photo.isUnreadable) return _Unreadable(photo: photo);

    return thumbnail.when(
      // Nothing is drawn while waiting: the tile is already filled with the
      // photograph's own average colour, which says more about what is coming
      // than a spinner would.
      loading: () => const SizedBox.expand(),
      error: (_, _) => _Unreadable(photo: photo),
      data: (image) => Image.memory(
        image.jpeg,
        key: Key('thumb-${photo.dcfPath}'),
        fit: BoxFit.contain,
        // The bytes are already sized for this cell; letting the framework
        // resize them again would blur the result and cost a second decode.
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
    );
  }
}

/// The tile for a photograph the app cannot render.
///
/// It still shows its radical and its badge, and it is still selectable and
/// deletable: a frame the camera mangled is exactly one the user may want gone
/// (spec §9).
class _Unreadable extends StatelessWidget {
  const _Unreadable({required this.photo});

  final PhotoEntity photo;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('unreadable-${photo.dcfPath}'),
      alignment: Alignment.center,
      color: ObscuraColors.surfaceContainerLowest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            size: 20,
            color: ObscuraColors.textSecondary,
          ),
          const SizedBox(height: ObscuraSpacing.controlGap / 2),
          Text(
            photo.radical,
            style: ObscuraTypography.bodySmall
                .copyWith(color: ObscuraColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The mark, and the way to set it.
class _TrashButton extends StatelessWidget {
  const _TrashButton({
    super.key,
    required this.buttonKey,
    required this.marked,
    required this.onPressed,
  });

  final Key buttonKey;
  final bool marked;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: marked ? 'Ne plus supprimer (⌫)' : 'Marquer à supprimer (⌫)',
      child: GestureDetector(
        key: buttonKey,
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: marked
                  ? ObscuraColors.statusDelete
                  : ObscuraColors.canvas.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(ObscuraRadii.sm),
            ),
            child: Icon(
              marked ? Icons.delete : Icons.delete_outline,
              size: 13,
              color: ObscuraColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The other decision, and the way to make it.
///
/// Beside the trash and built the same way: a photographer looking at a frame
/// is deciding between the two, and putting one control on the cell and the
/// other behind a keystroke would make one of them the real one.
class _WantedButton extends StatelessWidget {
  const _WantedButton({
    required this.buttonKey,
    required this.wanted,
    required this.onPressed,
  });

  final Key buttonKey;
  final bool wanted;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: wanted ? 'Ne plus exporter (E)' : 'Marquer à exporter (E)',
      child: GestureDetector(
        key: buttonKey,
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: wanted
                  ? ObscuraColors.statusExport
                  : ObscuraColors.canvas.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(ObscuraRadii.sm),
            ),
            child: Icon(
              wanted ? Icons.ios_share : Icons.ios_share_outlined,
              size: 13,
              color: ObscuraColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
