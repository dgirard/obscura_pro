import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../viewer/obscura.dart';
import 'layer_controller.dart';
import 'layer_painter.dart';
import 'layer_placement.dart';
import 'patterns/pattern_library.dart';

/// The composition panel: what is on the photograph, the library under it, and
/// the stroke controls at the bottom.
///
/// It follows the maquette except in one place, and deliberately. The maquette
/// ends with a red "Enregistrer la composition" button; there is nothing for it
/// to do, because a layer is written the moment it is placed — the same rule
/// marking follows, for the same reason. A button that saved what was already
/// saved would be teaching the photographer to distrust everything they had not
/// pressed it for. What is there instead is a line saying whether the writing
/// is working.
class LayersPanel extends ConsumerWidget {
  const LayersPanel({super.key});

  static const double width = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(layerBoardProvider);

    return Container(
      key: const Key('layers-panel'),
      width: width,
      decoration: const BoxDecoration(
        color: ObscuraColors.elevated,
        border: Border(left: BorderSide(color: ObscuraColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: ObscuraSpacing.overlayPadding,
              ),
              children: [
                // What is on the photograph comes before what could be. The
                // palette is thirty tiles tall, and putting it first meant the
                // list of placed layers — the only place a guide can be locked,
                // reordered or taken off — was somewhere below the fold, on a
                // screen whose whole subject was on the other side of it.
                _Placed(board: board),
                const SizedBox(height: ObscuraSpacing.controlGap),
                for (final category in PatternCategory.values)
                  _Section(category: category),
                const SizedBox(height: ObscuraSpacing.overlayPadding),
              ],
            ),
          ),
          _Appearance(board: board),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(ObscuraSpacing.overlayPadding),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calques de composition',
                    style: ObscuraTypography.headlineMedium),
                Text(
                  'Grammaire du cadre · 15 tracés, 15 fiches',
                  style: ObscuraTypography.bodySmall
                      .copyWith(color: ObscuraColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('layers-close'),
            tooltip: 'Fermer le panneau (L)',
            iconSize: 18,
            color: ObscuraColors.textSecondary,
            onPressed: () => ref.read(layersPanelProvider.notifier).close(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// One of the document's seven sections.
class _Section extends StatelessWidget {
  const _Section({required this.category});

  final PatternCategory category;

  @override
  Widget build(BuildContext context) {
    final patterns = patternsByCategory[category] ?? const [];
    if (patterns.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: ObscuraSpacing.overlayPadding),
        Text(
          category.label.toUpperCase(),
          style: ObscuraTypography.metadataLabel
              .copyWith(color: ObscuraColors.textSecondary),
        ),
        const SizedBox(height: ObscuraSpacing.controlGap),
        Wrap(
          spacing: ObscuraSpacing.controlGap,
          runSpacing: ObscuraSpacing.controlGap,
          children: [
            for (final pattern in patterns) _PatternTile(pattern: pattern),
          ],
        ),
      ],
    );
  }
}

/// A guide to drop, or a card to read.
///
/// The two are one tile with two behaviours rather than two lists, because the
/// Grammaire is one document: a photographer looking for "remplir le cadre"
/// should find it where it is in the book, and be told what it says, instead of
/// finding it missing because it cannot be drawn.
class _PatternTile extends ConsumerWidget {
  const _PatternTile({required this.pattern});

  final CompositionPattern pattern;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const size = Size(122, 74);

    return Tooltip(
      // Boxed to the width of two tiles. A tooltip carrying a whole definition
      // lays itself out across the window by default and covers the rows below
      // the one being pointed at — the palette hides itself as you read it.
      richMessage: WidgetSpan(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pattern.nom, style: ObscuraTypography.bodyMedium),
              const SizedBox(height: 2),
              Text(
                pattern.definition,
                style: ObscuraTypography.bodySmall
                    .copyWith(color: ObscuraColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
      child: GestureDetector(
        key: Key('palette-${pattern.code}'),
        onTap: () => pattern.isGuide
            ? ref
                .read(layerBoardProvider.notifier)
                .place(pattern.code, obscura: ref.read(obscuraProvider))
            : _showCard(context, pattern),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: size.width,
            padding: const EdgeInsets.all(ObscuraSpacing.controlGap / 2),
            decoration: BoxDecoration(
              color: ObscuraColors.surfaceContainerLowest,
              border: Border.all(color: ObscuraColors.border),
              borderRadius: BorderRadius.circular(ObscuraRadii.base),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: size.height * 0.55,
                  child: pattern.isGuide
                      ? CustomPaint(
                          painter: GuidePreviewPainter(
                            code: pattern.code,
                            color: ObscuraColors.textSecondary,
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.menu_book_outlined,
                            size: 16,
                            color: ObscuraColors.textSecondary,
                          ),
                        ),
                ),
                const SizedBox(height: ObscuraSpacing.controlGap / 2),
                Text(
                  pattern.nom,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ObscuraTypography.bodySmall.copyWith(
                    color: pattern.isGuide
                        ? ObscuraColors.textPrimary
                        : ObscuraColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The document's own card, for a pattern that cannot be laid over anything.
  static void _showCard(BuildContext context, CompositionPattern pattern) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('pattern-card'),
        backgroundColor: ObscuraColors.elevated,
        title: Text(pattern.nom, style: ObscuraTypography.headlineMedium),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, text) in [
                ('Définition', pattern.definition),
                ('Reconnaître', pattern.recognise),
                ('Effet', pattern.effect),
              ]) ...[
                Text(
                  label.toUpperCase(),
                  style: ObscuraTypography.metadataLabel
                      .copyWith(color: ObscuraColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(text, style: ObscuraTypography.bodyMedium),
                const SizedBox(height: ObscuraSpacing.controlGap),
              ],
              Text(
                'Cette fiche décrit un sujet, pas une construction du cadre : '
                'il n\'y a rien à poser sur la photographie.',
                style: ObscuraTypography.bodySmall
                    .copyWith(color: ObscuraColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

/// What is on this photograph, topmost first.
class _Placed extends ConsumerWidget {
  const _Placed({required this.board});

  final LayerBoard board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(layerBoardProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'SUR CETTE PHOTOGRAPHIE',
                style: ObscuraTypography.metadataLabel
                    .copyWith(color: ObscuraColors.textSecondary),
              ),
            ),
            if (board.layers.length > 1)
              TextButton(
                key: const Key('layers-clear'),
                onPressed: notifier.clear,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  foregroundColor: ObscuraColors.textSecondary,
                ),
                child: Text('Tout retirer', style: ObscuraTypography.bodySmall),
              ),
          ],
        ),
        const SizedBox(height: ObscuraSpacing.controlGap),
        if (board.layers.isEmpty)
          Text(
            board.loading ? 'Lecture…' : 'Aucun calque posé.',
            key: const Key('layers-empty'),
            style: ObscuraTypography.bodySmall
                .copyWith(color: ObscuraColors.textSecondary),
          ),
        for (final layer in board.layers.reversed)
          _PlacedRow(
            layer: layer,
            selected: layer.localId == board.selected,
            onSelect: () => notifier.select(
              layer.localId == board.selected ? null : layer.localId,
            ),
            onLock: () => notifier.toggleLock(layer.localId),
            onRaise: () => notifier.reorder(layer.localId, up: true),
            onLower: () => notifier.reorder(layer.localId, up: false),
            onRemove: () => notifier.remove(layer.localId),
          ),
      ],
    );
  }
}

class _PlacedRow extends StatelessWidget {
  const _PlacedRow({
    required this.layer,
    required this.selected,
    required this.onSelect,
    required this.onLock,
    required this.onRaise,
    required this.onLower,
    required this.onRemove,
  });

  final LayerPlacement layer;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onLock;
  final VoidCallback onRaise;
  final VoidCallback onLower;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final pattern = patternByCode(layer.patternCode);

    return GestureDetector(
      key: Key('layer-row-${layer.localId}'),
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: ObscuraSpacing.controlGap / 2),
        padding: const EdgeInsets.symmetric(
          horizontal: ObscuraSpacing.controlGap,
          vertical: ObscuraSpacing.controlGap / 2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? ObscuraColors.surfaceContainerHigh
              : ObscuraColors.surfaceContainerLowest,
          border: Border.all(
            color: selected ? ObscuraColors.leicaRed : ObscuraColors.border,
          ),
          borderRadius: BorderRadius.circular(ObscuraRadii.base),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                // A saved layer naming a guide this build does not know still
                // has to be listed, and named as what it is.
                pattern?.nom ?? 'Tracé inconnu (${layer.patternCode})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ObscuraTypography.bodySmall.copyWith(
                  color: pattern == null
                      ? ObscuraColors.textSecondary
                      : ObscuraColors.textPrimary,
                ),
              ),
            ),
            _RowButton(
              keyName: 'layer-lower-${layer.localId}',
              tooltip: 'Descendre',
              icon: Icons.arrow_downward,
              onPressed: onLower,
            ),
            _RowButton(
              keyName: 'layer-raise-${layer.localId}',
              tooltip: 'Monter',
              icon: Icons.arrow_upward,
              onPressed: onRaise,
            ),
            _RowButton(
              keyName: 'layer-lock-${layer.localId}',
              tooltip: layer.locked ? 'Déverrouiller' : 'Verrouiller',
              icon: layer.locked ? Icons.lock : Icons.lock_open,
              active: layer.locked,
              onPressed: onLock,
            ),
            _RowButton(
              keyName: 'layer-remove-${layer.localId}',
              tooltip: 'Retirer',
              icon: Icons.delete_outline,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({
    required this.keyName,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String keyName;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) => IconButton(
        key: Key(keyName),
        tooltip: tooltip,
        iconSize: 14,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
        padding: EdgeInsets.zero,
        color: active ? ObscuraColors.leicaRed : ObscuraColors.textSecondary,
        onPressed: onPressed,
        icon: Icon(icon),
      );
}

/// Stroke, opacity, angle — and the line that says whether any of it is being
/// written down.
class _Appearance extends ConsumerWidget {
  const _Appearance({required this.board});

  final LayerBoard board;

  /// The three the maquette offers: light on a dark photograph, red for a
  /// construction being argued about, dark on a bright one.
  static const swatches = [0xFFFFFFFF, 0xFFE11B22, 0xFF101010];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(layerBoardProvider.notifier);
    final selected = board.selectedLayer;
    final reference = selected ?? board.layers.lastOrNull;
    final opacity = reference?.opacity ?? 0.6;

    return Container(
      padding: const EdgeInsets.all(ObscuraSpacing.overlayPadding),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ObscuraColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selected == null ? 'TRAIT · TOUS LES CALQUES' : 'TRAIT · SÉLECTION',
            style: ObscuraTypography.metadataLabel
                .copyWith(color: ObscuraColors.textSecondary),
          ),
          const SizedBox(height: ObscuraSpacing.controlGap / 2),
          Row(
            children: [
              Text('Opacité',
                  style: ObscuraTypography.bodySmall
                      .copyWith(color: ObscuraColors.textSecondary)),
              Expanded(
                child: Slider(
                  key: const Key('layer-opacity'),
                  value: opacity.clamp(0.05, 1),
                  min: 0.05,
                  max: 1,
                  divisions: 19,
                  activeColor: ObscuraColors.leicaRed,
                  onChanged: board.layers.isEmpty
                      ? null
                      : (value) => notifier.setAppearance(
                            opacity: value,
                            // One undo step per drag of the slider, not one per
                            // pixel of it.
                            record: (value * 100).round() % 25 == 0,
                          ),
                  onChangeEnd: (_) => notifier.commit(),
                ),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '${(opacity * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: ObscuraTypography.monoData,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text('Couleur',
                  style: ObscuraTypography.bodySmall
                      .copyWith(color: ObscuraColors.textSecondary)),
              const SizedBox(width: ObscuraSpacing.controlGap),
              for (final swatch in swatches)
                GestureDetector(
                  key: Key('layer-color-${swatch.toRadixString(16)}'),
                  onTap: board.layers.isEmpty
                      ? null
                      : () {
                          notifier.setAppearance(color: swatch);
                          notifier.commit();
                        },
                  child: Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: ObscuraSpacing.controlGap),
                    decoration: BoxDecoration(
                      color: Color(swatch),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: reference?.color == swatch
                            ? ObscuraColors.leicaRed
                            : ObscuraColors.border,
                        width: reference?.color == swatch
                            ? ObscuraStrokes.selection
                            : ObscuraStrokes.hairline,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (selected != null)
            Row(
              children: [
                Text('Angle',
                    style: ObscuraTypography.bodySmall
                        .copyWith(color: ObscuraColors.textSecondary)),
                Expanded(
                  child: Slider(
                    key: const Key('layer-rotation'),
                    value: (selected.rotation * 180 / math.pi).clamp(-180, 180),
                    min: -180,
                    max: 180,
                    divisions: 720,
                    activeColor: ObscuraColors.leicaRed,
                    onChangeStart: (_) => notifier.beginChange(),
                    onChanged: (value) =>
                        notifier.setRotation(value * math.pi / 180),
                    onChangeEnd: (_) => notifier.commit(),
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${(selected.rotation * 180 / math.pi).round()}°',
                    textAlign: TextAlign.right,
                    style: ObscuraTypography.monoData,
                  ),
                ),
              ],
            ),
          const SizedBox(height: ObscuraSpacing.controlGap / 2),
          _SaveState(board: board),
        ],
      ),
    );
  }
}

/// Where the maquette's save button was.
class _SaveState extends StatelessWidget {
  const _SaveState({required this.board});

  final LayerBoard board;

  @override
  Widget build(BuildContext context) {
    final (icon, text, colour) = board.durable
        ? (
            Icons.check,
            board.layers.isEmpty
                ? 'La composition est enregistrée à mesure.'
                : '${board.layers.length} calque'
                    '${board.layers.length > 1 ? 's' : ''} enregistré'
                    '${board.layers.length > 1 ? 's' : ''} sur cette photographie.',
            ObscuraColors.textSecondary,
          )
        : (
            Icons.warning_amber_rounded,
            'Les calques sont à l\'écran mais n\'ont pas pu être enregistrés : '
                '${board.failure}',
            ObscuraColors.leicaRed,
          );

    return Row(
      key: const Key('layers-save-state'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: colour),
        const SizedBox(width: ObscuraSpacing.controlGap / 2),
        Expanded(
          child: Text(
            text,
            style: ObscuraTypography.bodySmall.copyWith(color: colour),
          ),
        ),
      ],
    );
  }
}
