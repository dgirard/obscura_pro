import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/volume_select/card_selection.dart';
import 'theme.dart';

/// The window skeleton: a fixed-width sidebar, a fluid content area, and a
/// status strip along the bottom.
///
/// Only the frame lives here. The volume picker fills the content area once a
/// card is chosen, and the library grid replaces it after a scan; both arrive
/// with their own units.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.content, this.statusBar});

  final Widget content;
  final Widget? statusBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ObscuraColors.canvas,
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Sidebar(),
                const VerticalDivider(width: ObscuraStrokes.hairline),
                Expanded(child: content),
              ],
            ),
          ),
          const Divider(height: ObscuraStrokes.hairline),
          statusBar ?? const _StatusBarPlaceholder(),
        ],
      ),
    );
  }
}

/// Which destination the sidebar is on.
class LibrarySectionNotifier extends Notifier<LibrarySection> {
  @override
  LibrarySection build() => LibrarySection.library;

  void go(LibrarySection section) => state = section;
}

final librarySectionProvider =
    NotifierProvider<LibrarySectionNotifier, LibrarySection>(
  LibrarySectionNotifier.new,
);

/// Where the session lives.
///
/// Three destinations, not the maquette's seven. Recents, Favorites, Import and
/// Cloud Sync all describe a library the app keeps; this one keeps none — the
/// photographs stay on the card until the user exports or deletes them, and a
/// menu entry promising otherwise would be the first lie the interface tells.
enum LibrarySection { library, card, trash, settings }

class _Sidebar extends ConsumerWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(cardSelectionProvider);
    final cardPath = selection is CardSelectionOpened ? selection.path : null;
    final current = ref.watch(librarySectionProvider);

    return Container(
      width: ObscuraSpacing.sidebarWidth,
      color: ObscuraColors.canvas,
      padding: const EdgeInsets.all(ObscuraSpacing.overlayPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Obscura Pro', style: ObscuraTypography.headlineMedium.copyWith(color: ObscuraColors.leicaRed)),
          const SizedBox(height: ObscuraSpacing.overlayPadding),
          _CardHeader(cardPath: cardPath),
          const SizedBox(height: ObscuraSpacing.overlayPadding),
          for (final (section, icon, label) in const [
            (LibrarySection.library, Icons.photo_library_outlined, 'Bibliothèque'),
            (LibrarySection.card, Icons.sd_card_outlined, 'Carte SD'),
            (LibrarySection.trash, Icons.delete_outline, 'Corbeille'),
            (LibrarySection.settings, Icons.tune, 'Réglages'),
          ])
            _SectionEntry(
              section: section,
              icon: icon,
              label: label,
              selected: current == section,
              onTap: () => ref.read(librarySectionProvider.notifier).go(section),
            ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.cardPath});

  final String? cardPath;

  @override
  Widget build(BuildContext context) {
    final name = cardPath?.split('/').last;
    return Container(
      key: const Key('sidebar-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(ObscuraSpacing.overlayPadding * 0.75),
      decoration: BoxDecoration(
        color: ObscuraColors.elevated,
        border: Border.all(color: ObscuraColors.border),
        borderRadius: BorderRadius.circular(ObscuraRadii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.photo_camera_outlined,
              size: 18, color: ObscuraColors.textSecondary),
          const SizedBox(width: ObscuraSpacing.controlGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? 'Aucune carte',
                  style: ObscuraTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  // Stated on every screen rather than buried in Settings: the
                  // guarantee is the product, and a user who does not know the
                  // card is untouched cannot rely on it.
                  cardPath == null ? 'Non montée' : 'Lecture seule',
                  style: ObscuraTypography.bodySmall
                      .copyWith(color: ObscuraColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEntry extends StatelessWidget {
  const _SectionEntry({
    required this.section,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final LibrarySection section;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return Container(
      key: Key('sidebar-${section.name}'),
      margin: const EdgeInsets.only(bottom: ObscuraSpacing.controlGap / 2),
      padding: const EdgeInsets.symmetric(
        horizontal: ObscuraSpacing.controlGap,
        vertical: ObscuraSpacing.controlGap,
      ),
      decoration: BoxDecoration(
        color: selected ? ObscuraColors.elevated : null,
        borderRadius: BorderRadius.circular(ObscuraRadii.base),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: selected
                  ? ObscuraColors.textPrimary
                  : ObscuraColors.textSecondary),
          const SizedBox(width: ObscuraSpacing.controlGap),
          Text(
            label,
            style: ObscuraTypography.bodyMedium.copyWith(
              color: selected
                  ? ObscuraColors.textPrimary
                  : ObscuraColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBarPlaceholder extends StatelessWidget {
  const _StatusBarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: ObscuraSpacing.overlayPadding),
      color: ObscuraColors.canvas,
      child: Text(
        'Prêt',
        style: ObscuraTypography.bodySmall.copyWith(color: ObscuraColors.textSecondary),
      ),
    );
  }
}
