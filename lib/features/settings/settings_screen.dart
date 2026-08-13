import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../infra/safety/parasite_guard.dart';
import '../crop/export_service.dart';
import '../grid/grid_screen.dart';
import '../exports/export_folder.dart';
import '../volume_select/card_selection.dart';
import 'settings_store.dart';

/// How the export folder is chosen.
///
/// A seam because the panel is a platform call: the refusal that guards the
/// card sits directly behind it, and a guard that cannot be exercised is a
/// guard nobody knows is broken.
final directoryPickerProvider = Provider<Future<String?> Function()>(
  (ref) => () => getDirectoryPath(confirmButtonText: 'Choisir'),
);

/// The choices that have nowhere else to live.
///
/// Three of them are real decisions with costs on both sides, so each is stated
/// with its tradeoff rather than presented as a switch with a good side and a
/// bad one. The fourth is not a choice at all — it is what the app does with
/// video — and it is here because a user is entitled to know, and because
/// silence about a card's contents is the one thing this app must never do.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Set when a preference could not be written.
  ///
  /// Shown rather than swallowed: these choices describe what the app will do
  /// to a photographer's card, and one that looks active but was never saved is
  /// the worst of both — it reverts on the next launch without ever saying so.
  String? _failure;

  /// Chooses the export folder, refusing the card and remembering the grant.
  ///
  /// Two things happen here that cannot happen later. The refusal is checked
  /// while the user is still looking at their own choice, and the bookmark is
  /// minted in the same turn as the panel — the ability to create one depends
  /// on the panel's implicit grant still being live, so deferring it to first
  /// use fails and the folder is unreadable on the next launch.
  Future<void> _chooseFolder(Settings settings) async {
    final chosen = await ref.read(directoryPickerProvider)();
    if (chosen == null || !mounted) return;

    final folders = ref.read(exportFoldersProvider);
    if (await folders.isOnRemovableVolume(chosen)) {
      if (!mounted) return;
      setState(() => _failure =
          'Ce dossier est sur une carte. Les exports sont écrits sur le Mac, '
          'jamais sur la carte — le dossier n\'a pas été changé.');
      return;
    }

    try {
      await ref
          .read(bookmarkStoreProvider)
          .save(ExportFolders.bookmarkKey, chosen);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _failure =
          'Ce dossier n\'a pas pu être mémorisé, il serait illisible au '
          'prochain lancement : $error');
      return;
    }
    if (!mounted) return;
    final written = await _save(settings.copyWith(exportFolder: chosen));
    if (written) return;

    // The panel says the previous choice stands, so the grant has to go back
    // too: the folder that is actually read on the next launch is the one the
    // bookmark resolves to, and leaving it here would make the sentence above
    // name a folder nothing writes to.
    await ref.read(bookmarkStoreProvider).forget(ExportFolders.bookmarkKey);
  }

  Future<bool> _save(Settings next) async {
    final written = await ref.read(settingsProvider.notifier).save(next);
    if (!mounted) return written;
    setState(() {
      _failure = written
          ? null
          : 'Réglage non enregistré : le fichier de préférences n\'a pas pu '
              'être écrit. Le choix précédent reste en vigueur.';
    });
    return written;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final catalog = ref.watch(cardCatalogProvider).value;
    final videos = catalog?.unsupportedFiles ?? const <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ObscuraSpacing.viewerMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Réglages', style: ObscuraTypography.headlineLarge),
          if (_failure != null) ...[
            const SizedBox(height: ObscuraSpacing.overlayPadding),
            Text(
              _failure!,
              key: const Key('settings-failure'),
              style: ObscuraTypography.bodySmall
                  .copyWith(color: ObscuraColors.leicaRed),
            ),
          ],
          const SizedBox(height: ObscuraSpacing.overlayPadding * 2),

          _Section(
            title: 'Dossier d\'export',
            explanation:
                'Les recadrages sont écrits ici, dans un sous-dossier par jour. '
                'Jamais sur la carte.',
            child: Row(
              children: [
                Expanded(
                  child: FutureBuilder(
                    future: defaultExportFolder(),
                    builder: (context, snapshot) => Text(
                      settings.exportFolder ?? snapshot.data?.path ?? '…',
                      key: const Key('settings-export-folder'),
                      style: ObscuraTypography.monoData
                          .copyWith(color: ObscuraColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: ObscuraSpacing.controlGap),
                FilledButton(
                  key: const Key('settings-choose-folder'),
                  onPressed: () => _chooseFolder(settings),
                  child: const Text('Choisir…'),
                ),
                if (settings.exportFolder != null) ...[
                  const SizedBox(width: ObscuraSpacing.controlGap),
                  TextButton(
                    onPressed: () =>
                        _save(settings.copyWith(clearExportFolder: true)),
                    child: const Text('Par défaut'),
                  ),
                ],
              ],
            ),
          ),

          _Section(
            title: 'Suppression',
            explanation:
                'Deux façons de retirer une photographie, et le bon choix '
                'dépend de ce que vous faites.',
            child: Column(
              children: [
                _Choice(
                  key: const Key('settings-deferred'),
                  selected: settings.deletionMode == DeletionMode.deferred,
                  title: 'Marquage différé',
                  detail:
                      'Suppr marque, rien ne quitte la carte avant que vous ne '
                      'vidiez la corbeille. La carte peut être retirée à tout '
                      'moment sans conséquence — c\'est ce qu\'il faut pour trier.',
                  onTap: () => _save(
                    settings.copyWith(deletionMode: DeletionMode.deferred),
                  ),
                ),
                _Choice(
                  key: const Key('settings-immediate'),
                  selected: settings.deletionMode == DeletionMode.immediate,
                  title: 'Déplacement immédiat vers le Mac',
                  detail:
                      'Chaque suppression copie les originaux sur le Mac, les '
                      'vérifie par empreinte, puis seulement les retire de la '
                      'carte. Plus lent, et libère la carte au fur et à mesure.',
                  onTap: () => _save(
                    settings.copyWith(deletionMode: DeletionMode.immediate),
                  ),
                ),
              ],
            ),
          ),

          _Section(
            title: 'Indexation Spotlight',
            explanation: SpotlightPolicy.explanation,
            child: Row(
              children: [
                Switch(
                  key: const Key('settings-spotlight'),
                  value: settings.suppressSpotlight,
                  activeThumbColor: ObscuraColors.leicaRed,
                  onChanged: (value) =>
                      _save(settings.copyWith(suppressSpotlight: value)),
                ),
                const SizedBox(width: ObscuraSpacing.controlGap),
                Text(
                  settings.suppressSpotlight
                      ? 'Écrire .metadata_never_index à l\'ouverture de la carte'
                      : 'Ne rien écrire sur la carte (recommandé)',
                  style: ObscuraTypography.bodyMedium,
                ),
              ],
            ),
          ),

          _Section(
            title: 'Vidéos',
            explanation:
                'Les fichiers vidéo sont ignorés : ils ne sont ni affichés, ni '
                'catalogués, ni supprimés. Ils sont comptés ici pour qu\'une '
                'carte annonçant « 0 photographie » ne vous laisse pas croire '
                'qu\'elle est vide.',
            child: Text(
              videos.isEmpty
                  ? 'Aucun fichier ignoré sur cette carte.'
                  : '${videos.length} fichier${videos.length > 1 ? 's' : ''} '
                      'ignoré${videos.length > 1 ? 's' : ''} : '
                      '${videos.take(4).join(', ')}'
                      '${videos.length > 4 ? '…' : ''}',
              key: const Key('settings-ignored-files'),
              style: ObscuraTypography.monoData
                  .copyWith(color: ObscuraColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.explanation,
    required this.child,
  });

  final String title;
  final String explanation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ObscuraSpacing.viewerMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ObscuraTypography.headlineMedium),
          const SizedBox(height: ObscuraSpacing.controlGap / 2),
          SizedBox(
            width: 640,
            child: Text(
              explanation,
              style: ObscuraTypography.bodySmall
                  .copyWith(color: ObscuraColors.textSecondary),
            ),
          ),
          const SizedBox(height: ObscuraSpacing.overlayPadding),
          child,
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.selected,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 640,
          margin: const EdgeInsets.only(bottom: ObscuraSpacing.controlGap),
          padding: const EdgeInsets.all(ObscuraSpacing.overlayPadding),
          decoration: BoxDecoration(
            color: ObscuraColors.elevated,
            border: Border.all(
              color: selected ? ObscuraColors.leicaRed : ObscuraColors.border,
              width: selected ? ObscuraStrokes.selection : ObscuraStrokes.hairline,
            ),
            borderRadius: BorderRadius.circular(ObscuraRadii.base),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 16,
                color: selected
                    ? ObscuraColors.leicaRed
                    : ObscuraColors.textSecondary,
              ),
              const SizedBox(width: ObscuraSpacing.controlGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ObscuraTypography.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: ObscuraTypography.bodySmall
                          .copyWith(color: ObscuraColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
