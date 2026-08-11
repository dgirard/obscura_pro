import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'app/status_bar.dart';
import 'app/theme.dart';
import 'features/grid/grid_screen.dart';
import 'features/volume_select/card_selection.dart';
import 'features/volume_select/volume_screen.dart';

void main() {
  runApp(const ProviderScope(child: ObscuraProApp()));
}

class ObscuraProApp extends StatelessWidget {
  const ObscuraProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Obscura Pro',
      debugShowCheckedModeBanner: false,
      theme: buildObscuraTheme(),
      home: const _Session(),
    );
  }
}

/// The window: the volume picker until a card is open, the grid afterwards.
class _Session extends ConsumerWidget {
  const _Session();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(cardSelectionProvider) is CardSelectionOpened;

    return AppShell(
      content: open ? const LibraryScreen() : const VolumeScreen(),
      statusBar: open ? const LibraryStatusBar() : null,
    );
  }
}
