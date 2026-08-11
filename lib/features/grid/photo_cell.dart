import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../catalog/photo_entity.dart';
import 'thumbnail_provider.dart';

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
/// The tile is square whatever the frame's shape, and the photograph is drawn
/// inside it whole. That is a deliberate departure from the maquette's
/// edge-to-edge crops: this grid exists to decide whether a frame works, and a
/// cell that crops is showing the user a composition they did not shoot. The
/// placeholder colour fills the tile behind the image, so a row still reads as
/// a row of blocks rather than of floating rectangles.
class PhotoCell extends ConsumerWidget {
  const PhotoCell({
    super.key,
    required this.photo,
    required this.targetShortSide,
    required this.selected,
    required this.marked,
    this.placeholderColor,
  });

  final PhotoEntity photo;

  /// Short side to decode to, in device pixels.
  final int targetShortSide;

  final bool selected;

  /// Marked for deletion. Nothing has been written to the card — marking is
  /// recorded on the Mac and only acted on when the trash is emptied.
  final bool marked;

  /// Mean colour of this photograph's thumbnail, when a previous session left
  /// one in the cache index. Null on a cold cache, where there is nothing
  /// truthful to paint and a neutral surface is shown instead.
  final int? placeholderColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnail = photo.isUnreadable
        ? const AsyncValue<GridThumbnail>.loading()
        : ref.watch(
            gridThumbnailProvider((photo: photo, shortSide: targetShortSide)),
          );

    final fill = placeholderColor != null
        ? Color(placeholderColor!)
        : ObscuraColors.surfaceContainer;

    return Semantics(
      label: '${photo.radical}, ${photo.formatBadge}',
      selected: selected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(ObscuraRadii.base),
          border: Border.all(
            color: selected ? ObscuraColors.leicaRed : ObscuraColors.border,
            width:
                selected ? ObscuraStrokes.selection : ObscuraStrokes.hairline,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ObscuraRadii.base),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Image(photo: photo, thumbnail: thumbnail),
              if (marked) const _MarkedWash(),
              Positioned(
                top: ObscuraSpacing.controlGap / 2,
                right: ObscuraSpacing.controlGap / 2,
                child: _FormatBadge(photo: photo),
              ),
              if (marked)
                Positioned(
                  top: ObscuraSpacing.controlGap / 2,
                  left: ObscuraSpacing.controlGap / 2,
                  child: _TrashBadge(key: Key('marked-${photo.dcfPath}')),
                ),
            ],
          ),
        ),
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

class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.photo});

  final PhotoEntity photo;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('badge-${photo.dcfPath}'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        // Opaque rather than translucent: the badge sits over unknown pixels,
        // and a label that is only legible over dark frames is not a label.
        color: ObscuraColors.canvas.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(ObscuraRadii.sm),
      ),
      child: Text(
        photo.formatBadge,
        style: ObscuraTypography.metadataLabel
            .copyWith(color: ObscuraColors.textPrimary),
      ),
    );
  }
}

/// The red cast over a photograph marked for deletion.
///
/// A wash rather than a border, because the border is already spoken for by
/// selection: the cell the keyboard is on and the cell that is going to be
/// deleted are different facts and a photographer has to be able to see both at
/// once.
class _MarkedWash extends StatelessWidget {
  const _MarkedWash();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: ObscuraColors.statusDelete.withValues(alpha: 0.34),
      );
}

class _TrashBadge extends StatelessWidget {
  const _TrashBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ObscuraColors.statusDelete,
        borderRadius: BorderRadius.circular(ObscuraRadii.sm),
      ),
      child: const Icon(
        Icons.delete_outline,
        size: 13,
        color: ObscuraColors.textPrimary,
      ),
    );
  }
}
