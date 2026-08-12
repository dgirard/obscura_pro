import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// One picture in a grid, whatever the picture is.
///
/// The library grid and the exports grid show different things — photographs
/// still on the card, files already written to the Mac — and there is no reason
/// for them to look different while doing it. Everything that makes a tile a
/// tile lives here: the fill behind the image, the selection border, the badge,
/// the corner control, the strip along the bottom.
///
/// The image is drawn *whole* inside the tile rather than cropped to fill it.
/// That is the departure from the maquette the library grid made deliberately —
/// a grid that crops is showing a composition the photographer did not shoot —
/// and it is just as true of a crop they exported.
class ThumbnailTile extends StatefulWidget {
  const ThumbnailTile({
    super.key,
    required this.image,
    this.fill,
    this.selected = false,
    this.badge,
    this.corner,
    this.cornerOnHover = false,
    this.footer,
    this.wash,
    this.semanticLabel,
  });

  final Widget image;

  /// Behind the image. A photograph's own average colour where one is known,
  /// so a row reads as a row of blocks rather than of floating rectangles.
  final Color? fill;

  final bool selected;

  /// Top right: what kind of thing this is — `RAW+JPG`, a crop ratio.
  final Widget? badge;

  /// Top left: the one action the tile carries.
  final Widget? corner;

  /// Whether [corner] is only offered while the pointer is over the tile.
  final bool cornerOnHover;

  /// Along the bottom, over the image: a name, a size, the controls that act on
  /// the file.
  final Widget? footer;

  /// A cast over the whole tile — deletion, on the library grid.
  final Color? wash;

  final String? semanticLabel;

  @override
  State<ThumbnailTile> createState() => _ThumbnailTileState();
}

class _ThumbnailTileState extends State<ThumbnailTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final corner = widget.corner;
    final showCorner =
        corner != null && (!widget.cornerOnHover || _hovered);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        label: widget.semanticLabel,
        selected: widget.selected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.fill ?? ObscuraColors.surfaceContainer,
            borderRadius: BorderRadius.circular(ObscuraRadii.base),
            border: Border.all(
              color: widget.selected
                  ? ObscuraColors.leicaRed
                  : ObscuraColors.border,
              width: widget.selected
                  ? ObscuraStrokes.selection
                  : ObscuraStrokes.hairline,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ObscuraRadii.base),
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.image,
                if (widget.wash != null) ColoredBox(color: widget.wash!),
                if (widget.badge != null)
                  Positioned(
                    top: ObscuraSpacing.controlGap / 2,
                    right: ObscuraSpacing.controlGap / 2,
                    child: widget.badge!,
                  ),
                if (showCorner)
                  Positioned(
                    top: ObscuraSpacing.controlGap / 2,
                    left: ObscuraSpacing.controlGap / 2,
                    child: corner,
                  ),
                if (widget.footer != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: widget.footer!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The opaque label a tile's badge is made of.
///
/// Opaque rather than translucent: it sits over unknown pixels, and a label
/// that is only legible over dark frames is not a label.
class TileBadge extends StatelessWidget {
  const TileBadge({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ObscuraColors.canvas.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(ObscuraRadii.sm),
        ),
        child: Text(
          text,
          style: ObscuraTypography.metadataLabel
              .copyWith(color: color ?? ObscuraColors.textPrimary),
        ),
      );
}
