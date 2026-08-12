import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../infra/finder/finder_channel.dart';
import 'export_store.dart';

/// Overridden in tests, which have no Finder.
final finderProvider = Provider<FinderChannel>((ref) => FinderChannel());

/// How a row draws the file it points at.
///
/// A seam in production code, and it earns its place: `Image.file` cannot be
/// rendered under the widget-test binding at all — the decode never completes
/// on its clock and the test hangs rather than failing — so a screen whose
/// whole point is showing exported files would otherwise be untestable. The
/// app passes the file; a test passes something already in memory.
final exportImageProvider = Provider<ImageProvider Function(String path)>(
  (ref) => (path) => FileImage(File(path)),
);

/// What has been exported, newest first.
///
/// The fourth destination, and the answer to a plain complaint: an export
/// landed in a folder and the only sign of it was a filename in the crop bar.
/// A photographer who has just made a decision about a frame should be able to
/// see the result of it without leaving for the Finder.
///
/// Two things this screen does not do. It does not claim a file is still there
/// when it is not — every row is checked against the disk as the list is built,
/// and a file the user moved is shown as moved rather than as an error. And it
/// offers no way to put an export back on the card: exports are Mac-side
/// deliverables, and the card is not their home.
class ExportsScreen extends ConsumerStatefulWidget {
  const ExportsScreen({super.key});

  @override
  ConsumerState<ExportsScreen> createState() => _ExportsScreenState();
}

class _ExportsScreenState extends ConsumerState<ExportsScreen> {
  String? _failure;

  Future<void> _reveal(ExportRecord record) async {
    final outcome = await ref.read(finderProvider).reveal(record.path);
    if (!mounted) return;
    setState(() {
      _failure = switch (outcome) {
        FinderOutcome.done => null,
        FinderOutcome.missing => '${record.fileName} n\'est plus à cet endroit.',
        FinderOutcome.refused =>
          'Le Finder n\'a pas pu l\'afficher : ${ref.read(finderProvider).lastRefusal}',
      };
    });
    if (outcome == FinderOutcome.missing) ref.invalidate(exportsProvider);
  }

  /// The file to the Trash first, the row second.
  ///
  /// That order is the survivable one: a crash between the two leaves a row
  /// pointing at a file that is in the Trash, which this list shows as missing.
  /// The other order would leave a file nothing in the app remembers.
  Future<void> _remove(ExportRecord record) async {
    final finder = ref.read(finderProvider);
    final outcome = await finder.moveToTrash(record.path);
    if (outcome == FinderOutcome.refused) {
      if (!mounted) return;
      setState(() => _failure =
          'Impossible de mettre ${record.fileName} à la corbeille : '
          '${finder.lastRefusal}');
      return;
    }

    await ref.read(exportStoreProvider).forget(record.id);
    if (!mounted) return;
    setState(() => _failure = null);
    ref.invalidate(exportsProvider);
  }

  void _open(ExportRecord record) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        key: const Key('export-preview'),
        backgroundColor: ObscuraColors.canvas,
        insetPadding: const EdgeInsets.all(ObscuraSpacing.viewerMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Image(
                image: ref.read(exportImageProvider)(record.path),
                fit: BoxFit.contain,
                errorBuilder: (context, _, _) => Padding(
                  padding: const EdgeInsets.all(ObscuraSpacing.overlayPadding),
                  child: Text(
                    'Ce fichier n\'est plus lisible.',
                    style: ObscuraTypography.bodyMedium
                        .copyWith(color: ObscuraColors.textSecondary),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(ObscuraSpacing.controlGap),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${record.fileName}  ·  ${record.dimensions}',
                    style: ObscuraTypography.monoData
                        .copyWith(color: ObscuraColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exports = ref.watch(exportsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(count: exports.value?.length ?? 0),
        if (_failure != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ObscuraSpacing.overlayPadding,
            ),
            child: Text(
              _failure!,
              key: const Key('exports-failure'),
              style: ObscuraTypography.bodySmall
                  .copyWith(color: ObscuraColors.leicaRed),
            ),
          ),
        Expanded(
          child: exports.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                'La liste des exports n\'a pas pu être lue.\n$error',
                textAlign: TextAlign.center,
                style: ObscuraTypography.bodyMedium
                    .copyWith(color: ObscuraColors.leicaRed),
              ),
            ),
            data: (records) => records.isEmpty
                ? const _Empty()
                : ListView(
                    key: const Key('exports-list'),
                    padding: const EdgeInsets.all(ObscuraSpacing.overlayPadding),
                    children: [
                      for (final group in _bySession(records)) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: ObscuraSpacing.controlGap,
                            bottom: ObscuraSpacing.controlGap / 2,
                          ),
                          child: Text(
                            group.$1.isEmpty ? 'Ailleurs' : group.$1,
                            style: ObscuraTypography.metadataLabel
                                .copyWith(color: ObscuraColors.textSecondary),
                          ),
                        ),
                        for (final record in group.$2)
                          _ExportRow(
                            record: record,
                            onOpen: () => _open(record),
                            onReveal: () => _reveal(record),
                            onRemove: () => _remove(record),
                          ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  /// Grouped by the dated folder they were written into, which is what a
  /// session is on disk. Order is preserved, so the newest session is first and
  /// so is the newest export inside it.
  static List<(String, List<ExportRecord>)> _bySession(
    List<ExportRecord> records,
  ) {
    final out = <(String, List<ExportRecord>)>[];
    for (final record in records) {
      if (out.isEmpty || out.last.$1 != record.folder) {
        out.add((record.folder, [record]));
      } else {
        out.last.$2.add(record);
      }
    }
    return out;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ObscuraSpacing.overlayPadding,
        ObscuraSpacing.overlayPadding,
        ObscuraSpacing.overlayPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exports', style: ObscuraTypography.headlineLarge),
          Text(
            count == 0
                ? 'Les recadrages exportés sur le Mac.'
                : '$count fichier${count > 1 ? 's' : ''} · sur le Mac, '
                    'jamais sur la carte.',
            style: ObscuraTypography.bodySmall
                .copyWith(color: ObscuraColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
        key: const Key('exports-empty'),
        child: Text(
          'Aucun export pour l\'instant.\n'
          'Recadrez une photographie (C) puis exportez-la (⌘E).',
          textAlign: TextAlign.center,
          style: ObscuraTypography.bodyMedium
              .copyWith(color: ObscuraColors.textSecondary),
        ),
      );
}

class _ExportRow extends StatelessWidget {
  const _ExportRow({
    required this.record,
    required this.onOpen,
    required this.onReveal,
    required this.onRemove,
  });

  final ExportRecord record;
  final VoidCallback onOpen;
  final VoidCallback onReveal;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('export-${record.id}'),
      margin: const EdgeInsets.only(bottom: ObscuraSpacing.controlGap),
      padding: const EdgeInsets.all(ObscuraSpacing.controlGap),
      decoration: BoxDecoration(
        color: ObscuraColors.surfaceContainerLowest,
        border: Border.all(color: ObscuraColors.border),
        borderRadius: BorderRadius.circular(ObscuraRadii.base),
      ),
      child: Row(
        children: [
          _Thumbnail(record: record),
          const SizedBox(width: ObscuraSpacing.overlayPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ObscuraTypography.bodyMedium.copyWith(
                    color: record.missing
                        ? ObscuraColors.textSecondary
                        : ObscuraColors.textPrimary,
                  ),
                ),
                Text(
                  '${record.radical}  ·  ${record.ratio}  ·  ${record.dimensions}',
                  style: ObscuraTypography.monoData
                      .copyWith(color: ObscuraColors.textSecondary),
                ),
                if (record.missing)
                  Text(
                    'Déplacé ou supprimé depuis le Finder.',
                    key: Key('export-missing-${record.id}'),
                    style: ObscuraTypography.bodySmall
                        .copyWith(color: ObscuraColors.leicaRed),
                  ),
              ],
            ),
          ),
          if (!record.missing) ...[
            _RowButton(
              keyName: 'export-open-${record.id}',
              tooltip: 'Voir en grand',
              icon: Icons.open_in_full,
              onPressed: onOpen,
            ),
            _RowButton(
              keyName: 'export-reveal-${record.id}',
              tooltip: 'Afficher dans le Finder',
              icon: Icons.folder_open,
              onPressed: onReveal,
            ),
          ],
          _RowButton(
            keyName: 'export-remove-${record.id}',
            tooltip: record.missing
                ? 'Retirer de la liste'
                : 'Mettre à la corbeille du Mac',
            icon: Icons.delete_outline,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// The exported file itself, small.
///
/// Read from the file rather than from the card's preview: this list is about
/// what was written, and a thumbnail of the uncropped frame would be showing
/// the one thing the export is not.
class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.record});

  final ExportRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const height = 56.0;
    if (record.missing) {
      return const SizedBox(
        width: height * 1.5,
        height: height,
        child: Icon(Icons.image_not_supported_outlined,
            size: 18, color: ObscuraColors.textSecondary),
      );
    }

    return SizedBox(
      width: height * 1.5,
      height: height,
      child: Image(
        // Device-pixel sized: a full-resolution export decoded at its own size
        // would be tens of megabytes per row.
        image: ResizeImage(
          ref.watch(exportImageProvider)(record.path),
          height: (height * MediaQuery.devicePixelRatioOf(context)).round(),
          policy: ResizeImagePolicy.fit,
        ),
        fit: BoxFit.contain,
        errorBuilder: (context, _, _) => const Icon(
          Icons.broken_image_outlined,
          size: 18,
          color: ObscuraColors.textSecondary,
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
  });

  final String keyName;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        key: Key(keyName),
        tooltip: tooltip,
        iconSize: 16,
        visualDensity: VisualDensity.compact,
        color: ObscuraColors.textSecondary,
        onPressed: onPressed,
        icon: Icon(icon),
      );
}
