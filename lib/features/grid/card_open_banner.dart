import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../infra/safety/parasite_guard.dart';
import '../volume_select/volume_screen.dart' show formatBytes;

/// Reports the card has already been read and put away.
///
/// Keyed by the report itself rather than by a flag, so dismissing one card's
/// findings does not silence the next card's: a new card produces a report that
/// is not in this set, and the banner comes back.
class DismissedReportsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void dismiss(CardOpenReport report) => state = {...state, cardReportToken(report)};
}

/// Two reports that say the same thing about the same card are the same report,
/// whichever scan produced them.
int cardReportToken(CardOpenReport report) => Object.hash(
      report.writable,
      report.reconciled,
      Object.hashAll(report.losses),
      Object.hashAll(report.parasites.map((p) => p.relativePath)),
      Object.hashAll(report.debrisRemoved),
    );

final dismissedReportsProvider =
    NotifierProvider<DismissedReportsNotifier, Set<int>>(
  DismissedReportsNotifier.new,
);

/// What the app did and found when it opened the card, said out loud.
///
/// All of it was already computed and none of it was shown. Every line here is
/// something a photographer is entitled to know before they start deleting: a
/// read-only card means the trash cannot be emptied, a foreign parasite means
/// the card is not going back to the camera clean, and a loss is the one
/// outcome this app admits it cannot repair.
class CardOpenBanner extends ConsumerWidget {
  const CardOpenBanner({super.key, required this.report});

  final CardOpenReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = _lines(report);
    if (lines.isEmpty) return const SizedBox.shrink();
    if (ref.watch(dismissedReportsProvider).contains(cardReportToken(report))) {
      return const SizedBox.shrink();
    }

    // The worst line sets the colour of the whole strip. A loss shown in the
    // same grey as a housekeeping note is a loss nobody reads.
    final tone = lines.first.tone;

    return Container(
      key: const Key('card-open-report'),
      margin: const EdgeInsets.fromLTRB(
        ObscuraSpacing.gridGutter,
        ObscuraSpacing.gridGutter,
        ObscuraSpacing.gridGutter,
        0,
      ),
      padding: const EdgeInsets.all(ObscuraSpacing.overlayPadding),
      decoration: BoxDecoration(
        color: ObscuraColors.elevated,
        border: Border(left: BorderSide(color: tone, width: 2)),
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(ObscuraRadii.base),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      line.text,
                      key: Key('card-open-${line.id}'),
                      style: ObscuraTypography.bodySmall.copyWith(color: line.tone),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            key: const Key('card-open-dismiss'),
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            tooltip: 'Masquer',
            onPressed: () =>
                ref.read(dismissedReportsProvider.notifier).dismiss(report),
            icon: const Icon(Icons.close, color: ObscuraColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// One thing the report has to say, and how loudly.
class _Line {
  const _Line(this.id, this.text, this.tone);

  final String id;
  final String text;
  final Color tone;
}

/// Worst first, and nothing said about a card that had nothing wrong with it.
List<_Line> _lines(CardOpenReport report) {
  final lines = <_Line>[];

  if (report.losses.isNotEmpty) {
    lines.add(_Line(
      'losses',
      '${report.losses.length} fichier${report.losses.length > 1 ? 's' : ''} '
          'ont disparu de la carte sans copie vérifiée sur le Mac : '
          '${_names(report.losses)}. C\'est le seul cas que l\'application ne '
          'sait pas réparer.',
      ObscuraColors.leicaRed,
    ));
  }

  if (!report.writable) {
    lines.add(const _Line(
      'read-only',
      'La carte est protégée en écriture : la corbeille ne pourra pas être '
          'vidée, et rien ne pourra être remis dessus. Le tri, lui, fonctionne.',
      ObscuraColors.statusDelete,
    ));
  }

  if (report.parasites.isNotEmpty) {
    final bytes = report.parasites.fold<int>(0, (sum, p) => sum + p.bytes);
    lines.add(_Line(
      'parasites',
      '${report.parasites.length} fichier${report.parasites.length > 1 ? 's' : ''} '
          'laissé${report.parasites.length > 1 ? 's' : ''} par le système sur la '
          'carte (${formatBytes(bytes)}) : '
          '${_names(report.parasites.map((p) => p.relativePath).toList())}. '
          'Ils ne sont pas retirés : les supprimer serait une écriture sur '
          'votre carte, et c\'est votre décision.',
      ObscuraColors.textPrimary,
    ));
  }

  if (report.reconciled > 0) {
    lines.add(_Line(
      'reconciled',
      '${report.reconciled} opération${report.reconciled > 1 ? 's' : ''} '
          'interrompue${report.reconciled > 1 ? 's' : ''} '
          '${report.reconciled > 1 ? 'ont' : 'a'} été résolue'
          '${report.reconciled > 1 ? 's' : ''} en regardant la carte.',
      ObscuraColors.textSecondary,
    ));
  }

  if (report.debrisRemoved.isNotEmpty) {
    lines.add(_Line(
      'debris',
      '${report.debrisRemoved.length} fichier'
          '${report.debrisRemoved.length > 1 ? 's' : ''} temporaire'
          '${report.debrisRemoved.length > 1 ? 's' : ''} de l\'application '
          '${report.debrisRemoved.length > 1 ? 'ont' : 'a'} été nettoyé'
          '${report.debrisRemoved.length > 1 ? 's' : ''}.',
      ObscuraColors.textSecondary,
    ));
  }

  return lines;
}

/// Names them, up to the point where a list stops being readable.
String _names(List<String> paths) {
  const shown = 4;
  if (paths.length <= shown) return paths.join(', ');
  return '${paths.take(shown).join(', ')} et ${paths.length - shown} autres';
}
