import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../infra/card_access/models.dart';
import 'card_selection.dart';

/// Where a session starts: pick the card to work on.
class VolumeScreen extends ConsumerWidget {
  const VolumeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(availableCardsProvider);
    final selection = ref.watch(cardSelectionProvider);

    return Padding(
      padding: const EdgeInsets.all(ObscuraSpacing.viewerMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sélection de la carte', style: ObscuraTypography.headlineLarge),
          const SizedBox(height: ObscuraSpacing.controlGap),
          Text(
            'Choisissez le volume à ouvrir. Obscura Pro travaille directement '
            'sur la carte, en lecture seule, sans import.',
            style: ObscuraTypography.bodyMedium
                .copyWith(color: ObscuraColors.textSecondary),
          ),
          const SizedBox(height: ObscuraSpacing.overlayPadding * 2),
          Expanded(
            child: cards.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Message(
                key: const Key('volume-list-error'),
                title: 'Impossible de lister les volumes',
                detail: '$e',
              ),
              data: (volumes) => volumes.isEmpty
                  ? const _NoVolumes()
                  : _VolumeList(
                      volumes: volumes,
                      onChoose: (volume) => ref
                          .read(cardSelectionProvider.notifier)
                          .openViaPanel(startAt: volume.path),
                    ),
            ),
          ),
          if (selection is CardSelectionRejected)
            _Message(
              key: const Key('not-a-card'),
              title: 'Aucun dossier DCIM trouvé',
              detail:
                  'Ce dossier ne ressemble pas à une carte d\'appareil photo. '
                  'Choisissez la racine du volume, pas un sous-dossier.',
              tone: ObscuraColors.leicaRed,
            ),
          const SizedBox(height: ObscuraSpacing.overlayPadding),
          Row(
            children: [
              FilledButton.icon(
                key: const Key('open-panel'),
                onPressed: selection is CardSelectionBusy
                    ? null
                    : () => ref.read(cardSelectionProvider.notifier).openViaPanel(),
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Ouvrir la carte…'),
              ),
              const SizedBox(width: ObscuraSpacing.controlGap),
              Expanded(
                child: Text(
                  // The picker is not optional chrome: the sandbox grants access
                  // to the volume only through the user's own selection.
                  'macOS demande votre accord une fois par carte.',
                  style: ObscuraTypography.bodySmall
                      .copyWith(color: ObscuraColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VolumeList extends StatelessWidget {
  const _VolumeList({required this.volumes, required this.onChoose});

  final List<MountedVolume> volumes;
  final void Function(MountedVolume volume) onChoose;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('volume-list'),
      itemCount: volumes.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: ObscuraSpacing.controlGap),
      itemBuilder: (context, i) => _VolumeTile(
        volume: volumes[i],
        onTap: () => onChoose(volumes[i]),
      ),
    );
  }
}

/// One mounted volume, offered as a choice.
///
/// It looks like a button and behaves like one. Before it did neither: it
/// listed the user's card and ignored every click, because the only way in was
/// a separate button lower down the screen. A row that names the thing you want
/// and does nothing when you press it does not read as "inert" — it reads as
/// broken.
///
/// Choosing one still opens the system panel. Under the sandbox that panel is
/// where the grant is made and it cannot be skipped; what a tap does is open it
/// already inside the chosen volume, so the confirmation is one click rather
/// than a hunt.
class _VolumeTile extends StatefulWidget {
  const _VolumeTile({required this.volume, required this.onTap});

  final MountedVolume volume;
  final VoidCallback onTap;

  @override
  State<_VolumeTile> createState() => _VolumeTileState();
}

class _VolumeTileState extends State<_VolumeTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final volume = widget.volume;

    return Semantics(
      button: true,
      label: 'Ouvrir ${volume.name}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            key: Key('volume-tile-${volume.path}'),
            padding: const EdgeInsets.all(ObscuraSpacing.overlayPadding),
            decoration: BoxDecoration(
              // "Subtle dark gray backgrounds that brighten on hover."
              color: _hovered
                  ? ObscuraColors.surfaceContainerHigh
                  : ObscuraColors.elevated,
              border: Border.all(
                color:
                    _hovered ? ObscuraColors.textSecondary : ObscuraColors.border,
              ),
              borderRadius: BorderRadius.circular(ObscuraRadii.base),
            ),
            child: Row(
              children: [
                const Icon(Icons.sd_card,
                    size: 20, color: ObscuraColors.textSecondary),
                const SizedBox(width: ObscuraSpacing.overlayPadding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(volume.name, style: ObscuraTypography.bodyMedium),
                      Text(
                        volume.path,
                        style: ObscuraTypography.bodySmall
                            .copyWith(color: ObscuraColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (volume.freeBytes != null)
                  Text(
                    '${formatBytes(volume.freeBytes!)} libres',
                    style: ObscuraTypography.monoData
                        .copyWith(color: ObscuraColors.textSecondary),
                  ),
                const SizedBox(width: ObscuraSpacing.overlayPadding),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: _hovered
                      ? ObscuraColors.textPrimary
                      : ObscuraColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoVolumes extends StatelessWidget {
  const _NoVolumes();

  @override
  Widget build(BuildContext context) => const _Message(
        key: Key('no-volumes'),
        title: 'Aucune carte détectée',
        detail: 'Insérez la carte SD du Leica Q3, ou ouvrez un dossier '
            'manuellement.',
      );
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.title, required this.detail, this.tone});

  final String title;
  final String detail;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: ObscuraTypography.headlineMedium
              .copyWith(color: tone ?? ObscuraColors.textPrimary),
        ),
        const SizedBox(height: ObscuraSpacing.controlGap / 2),
        Text(
          detail,
          style: ObscuraTypography.bodyMedium
              .copyWith(color: ObscuraColors.textSecondary),
        ),
      ],
    );
  }
}

/// Card capacities are quoted in decimal gigabytes on the packaging and by the
/// camera, so the picker uses the same base rather than binary units.
String formatBytes(int bytes) {
  const units = ['o', 'Ko', 'Mo', 'Go', 'To'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  // A decimal only earns its place below ten, where it still says something:
  // "45.0 Go" of card space is false precision.
  return value >= 10 || unit == 0
      ? '${value.round()} ${units[unit]}'
      : '${value.toStringAsFixed(1)} ${units[unit]}';
}
