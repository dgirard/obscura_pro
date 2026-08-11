import 'package:flutter/material.dart';

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

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ObscuraSpacing.sidebarWidth,
      color: ObscuraColors.canvas,
      padding: const EdgeInsets.all(ObscuraSpacing.overlayPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Obscura Pro', style: ObscuraTypography.headlineMedium.copyWith(color: ObscuraColors.leicaRed)),
          const SizedBox(height: ObscuraSpacing.controlGap),
          Text(
            'Aucune carte sélectionnée',
            style: ObscuraTypography.bodySmall.copyWith(color: ObscuraColors.textSecondary),
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
