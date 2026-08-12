import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../infra/db/database.dart';
import '../catalog/photo_entity.dart';
import '../grid/grid_screen.dart';
import '../volume_select/card_selection.dart';
import '../volume_select/volume_screen.dart' show formatBytes;
import 'trash_providers.dart';

/// The trash, and the one irreversible button in the application.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(trashSummaryProvider).value ?? TrashSummary.empty;
    final photos = ref.watch(cardCatalogProvider).value?.photos ?? const <PhotoEntity>[];
    final marked = ref.watch(markedForDeletionProvider);
    final doomed = photos.where((p) => marked.contains(p.key.value)).toList();
    final selection = ref.watch(cardSelectionProvider);
    final cardOpen = selection is CardSelectionOpened;

    return Padding(
      padding: const EdgeInsets.all(ObscuraSpacing.viewerMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Corbeille', style: ObscuraTypography.headlineLarge),
          const SizedBox(height: ObscuraSpacing.controlGap),
          Text(
            doomed.isEmpty
                ? 'Rien n\'est marqué. Les photographies restent sur la carte '
                    'jusqu\'à ce que vous vidiez la corbeille.'
                : 'Marquer n\'écrit rien sur la carte. Rien n\'est supprimé '
                    'tant que vous ne videz pas la corbeille.',
            style: ObscuraTypography.bodyMedium
                .copyWith(color: ObscuraColors.textSecondary),
          ),
          if (!marked.durable) ...[
            const SizedBox(height: ObscuraSpacing.controlGap),
            Text(
              // The one thing this screen must not do is imply a decision is
              // safe when it is only remembered.
              'Les marques de cette session ne sont pas enregistrées et '
              'disparaîtront à la fermeture : ${marked.failure}',
              key: const Key('trash-not-durable'),
              style: ObscuraTypography.bodySmall
                  .copyWith(color: ObscuraColors.leicaRed),
            ),
          ],
          const SizedBox(height: ObscuraSpacing.overlayPadding * 2),
          Row(
            children: [
              // Counted over the open card, because that is what the button at
              // the bottom of this screen will act on. Marks are durable now
              // and the table spans every card this Mac has culled, so the
              // summary's own totals would promise a deletion that the
              // confirmation dialog then contradicts.
              _Counter(
                key: const Key('trash-photo-count'),
                label: 'Photographies',
                value: '${doomed.length}',
              ),
              _Counter(
                key: const Key('trash-file-count'),
                label: 'Fichiers',
                value: '${doomed.fold<int>(0, (n, p) => n + p.files.length)}',
              ),
              _Counter(
                key: const Key('trash-bytes'),
                label: 'À récupérer',
                value: formatBytes(
                  doomed.fold<int>(0, (n, p) => n + p.totalBytes),
                ),
              ),
            ],
          ),
          if (summary.photoCount > doomed.length)
            Padding(
              padding: const EdgeInsets.only(top: ObscuraSpacing.controlGap),
              child: Text(
                // Rows this card cannot account for: marks made on another
                // card, and originals rescued to the Mac in immediate mode.
                // Nothing on this screen can act on them, which is a reason to
                // say where they are rather than a reason to hide them.
                _elsewhere(summary.photoCount - doomed.length),
                key: const Key('trash-elsewhere'),
                style: ObscuraTypography.bodySmall
                    .copyWith(color: ObscuraColors.textSecondary),
              ),
            ),
          const SizedBox(height: ObscuraSpacing.overlayPadding * 2),
          Expanded(
            child: doomed.isEmpty
                ? const _Empty()
                : _MarkedList(photos: doomed),
          ),
          const Divider(height: ObscuraSpacing.overlayPadding * 2),
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('trash-restore-all'),
                onPressed: doomed.isEmpty
                    ? null
                    : () => ref
                        .read(markedForDeletionProvider.notifier)
                        .unmark(doomed),
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('Tout restaurer'),
              ),
              const SizedBox(width: ObscuraSpacing.controlGap),
              FilledButton.icon(
                key: const Key('trash-empty'),
                // Disabled without a card rather than failing at the first
                // unlink: a destructive button that cannot do its job must not
                // look as though it can (spec section 9).
                onPressed: doomed.isEmpty || !cardOpen
                    ? null
                    : () => _confirmAndEmpty(context, ref, doomed),
                style: FilledButton.styleFrom(
                  backgroundColor: ObscuraColors.statusDelete,
                  foregroundColor: ObscuraColors.textPrimary,
                ),
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text('Vider la corbeille'),
              ),
              const SizedBox(width: ObscuraSpacing.overlayPadding),
              Expanded(
                child: Text(
                  'La suppression est définitive et n\'est pas annulable.',
                  style: ObscuraTypography.bodySmall
                      .copyWith(color: ObscuraColors.statusDelete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Names every file before removing any of them (FONC-DEL-1).
  ///
  /// A count is not a confirmation. "12 photographs" tells a photographer
  /// nothing they can check; a list of file names is something they can read
  /// and recognise, which is the only way this dialog can be more than a
  /// formality.
  Future<void> _confirmAndEmpty(
    BuildContext context,
    WidgetRef ref,
    List<PhotoEntity> photos,
  ) async {
    final files = [for (final photo in photos) ...photo.files.map((f) => f.name)]
      ..sort();
    final bytes = photos.fold<int>(0, (sum, p) => sum + p.totalBytes);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('empty-trash-confirm'),
        backgroundColor: ObscuraColors.elevated,
        title: Text(
          'Supprimer définitivement ${photos.length} photographie'
          '${photos.length > 1 ? 's' : ''} ?',
          style: ObscuraTypography.headlineMedium,
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${files.length} fichiers seront retirés de la carte '
                '(${formatBytes(bytes)}). Cette opération ne peut pas être '
                'annulée.',
                style: ObscuraTypography.bodyMedium,
              ),
              const SizedBox(height: ObscuraSpacing.overlayPadding),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    files.join('\n'),
                    key: const Key('empty-trash-file-list'),
                    style: ObscuraTypography.monoData
                        .copyWith(color: ObscuraColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const Key('empty-trash-confirmed'),
            style: FilledButton.styleFrom(
              backgroundColor: ObscuraColors.statusDelete,
              foregroundColor: ObscuraColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final service = await ref.read(trashServiceProvider.future);
    // Re-asserted rather than assumed. Marking normally writes these rows at
    // the moment the decision is made, but a session whose writes were failing
    // has marks that exist only in memory, and emptying a trash the database
    // has never heard of would delete nothing while reporting success.
    for (final photo in photos) {
      await service.mark(photo);
    }
    final report = await service.emptyTrash(photos);

    // Forgotten, not unmarked: every row involved is now `deleted` or
    // `uncertain`, and writing `onCard` over them would undo the record of what
    // just happened.
    ref
        .read(markedForDeletionProvider.notifier)
        .forget(photos.map((p) => p.key.value));
    ref.invalidate(cardCatalogProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          report.isClean
              ? '${report.deleted.length} photographies supprimées, '
                  '${formatBytes(report.bytesFreed)} récupérés.'
              : '${report.deleted.length} supprimées, '
                  '${report.skipped.length + report.uncertain.length} non traitées.',
        ),
      ),
    );
  }
}

/// Says how much of the trash belongs to a card that is not the open one.
String _elsewhere(int count) => count == 1
    ? 'Une autre photographie attend une décision et n\'est pas sur cette carte.'
    : '$count autres photographies attendent une décision et ne sont pas sur '
        'cette carte.';

class _Counter extends StatelessWidget {
  const _Counter({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: ObscuraSpacing.viewerMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: ObscuraTypography.metadataLabel
                .copyWith(color: ObscuraColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(value, style: ObscuraTypography.headlineMedium),
        ],
      ),
    );
  }
}

class _MarkedList extends StatelessWidget {
  const _MarkedList({required this.photos});

  final List<PhotoEntity> photos;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('trash-list'),
      itemCount: photos.length,
      itemBuilder: (context, i) {
        final photo = photos[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: ObscuraSpacing.controlGap),
          child: Row(
            children: [
              const Icon(Icons.delete_outline,
                  size: 16, color: ObscuraColors.statusDelete),
              const SizedBox(width: ObscuraSpacing.controlGap),
              Expanded(
                child: Text(
                  // Every file, named. The entity is what gets deleted, and a
                  // photographer should see both halves of a RAW+JPG pair.
                  photo.files.map((f) => f.name).join('  ·  '),
                  style: ObscuraTypography.monoData,
                ),
              ),
              Text(
                formatBytes(photo.totalBytes),
                style: ObscuraTypography.monoData
                    .copyWith(color: ObscuraColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
        key: const Key('trash-empty-state'),
        child: Text(
          'La corbeille est vide.',
          style: ObscuraTypography.bodyMedium
              .copyWith(color: ObscuraColors.textSecondary),
        ),
      );
}
