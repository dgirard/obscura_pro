import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'app/status_bar.dart';
import 'app/theme.dart';
import 'features/grid/grid_screen.dart';
import 'infra/card_access/models.dart';
import 'features/volume_select/card_selection.dart';

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
    Future.microtask(() async {
      if (!mounted) return;
      final selection = ref.read(cardSelectionProvider.notifier);
      await selection.reopenLast();
      // Then any other card that is in the reader and has been granted before:
      // a photographer with two cards should not have to answer a panel for the
      // one that was not last in.
      if (mounted) await selection.openKnown();
    });
  }

  @override
  Widget build(BuildContext context) {
    // A card put in while the app is running opens itself, on the same terms:
    // only if this Mac has been given access to it before.
    ref.listen(volumeEventsProvider, (previous, next) {
      if (next.value?.kind != VolumeEventKind.mounted) return;
      if (ref.read(cardSelectionProvider) is! CardSelectionIdle) return;
      ref.read(cardSelectionProvider.notifier).openKnown();
    });

    // The window is the sidebar and whatever the chosen destination shows.
    // Whether a card is in the reader is a question for the destinations that
    // are about a card, and [LibraryScreen] is where it is asked.
    return const AppShell(
      content: LibraryScreen(),
      statusBar: LibraryStatusBar(),
    );
  }
}
