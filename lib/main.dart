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
class _Session extends ConsumerStatefulWidget {
  const _Session();

  @override
  ConsumerState<_Session> createState() => _SessionState();
}

class _SessionState extends ConsumerState<_Session> {
  @override
  void initState() {
    super.initState();
    // Last session's card, before the picker is offered. The bookmark was taken
    // when the user chose it precisely so this could happen; asking again for a
    // card that never left the reader is a panel with no question in it.
    //
    // Deferred by one turn because it moves provider state, which a widget is
    // not allowed to do while it is being built.
    Future.microtask(() {
      if (mounted) ref.read(cardSelectionProvider.notifier).reopenLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(cardSelectionProvider) is CardSelectionOpened;

    return AppShell(
      content: open ? const LibraryScreen() : const VolumeScreen(),
      statusBar: open ? const LibraryStatusBar() : null,
    );
  }
}
