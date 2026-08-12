import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/shortcuts.dart';
import '../../app/theme.dart';
import '../catalog/dcf_scanner.dart';
import '../catalog/photo_entity.dart';
import '../volume_select/card_selection.dart';
import '../../app/app_shell.dart';
import '../../infra/safety/io_errors.dart';
import '../../infra/safety/parasite_guard.dart';
import '../settings/settings_screen.dart';
import '../settings/settings_store.dart';
import '../trash/trash_providers.dart';
import '../trash/trash_screen.dart';
import '../viewer/viewer_screen.dart';
import 'card_open_banner.dart';
import 'photo_cell.dart';
import 'thumbnail_provider.dart';

/// Everything that happens between a card being opened and its photographs
/// being shown.
///
/// The order is the plan's and it matters. Our own debris goes first, because
/// a stranded temp file from an interrupted write would otherwise be walked
/// past by the reconciliation that is about to make sense of that very write.
/// Reconciliation comes next, so the trash states describe the card as it is
/// before anything is drawn from them. The foreign-parasite report comes last
/// and changes nothing — removing those is a write to the user's card and
/// therefore the user's decision.
final cardOpenProvider = FutureProvider<CardOpenReport>((ref) async {
  final selection = ref.watch(cardSelectionProvider);
  if (selection is! CardSelectionOpened) return CardOpenReport.none;
  final root = selection.path;

  const guard = ParasiteGuard();
  // One walk of the card, not two. `removeOwnDebris` scans internally, so
  // calling it and then scanning again crossed every directory of a 941-frame
  // card twice before a single thumbnail appeared. Clearing our own leftovers
  // cannot change what is foreign, so one report answers both questions.
  final found = await guard.scan(root);
  final debris = await guard.remove(found.ourOwnDebris.toList());

  final trash = await ref.watch(trashServiceProvider.future);
  final reconciled = await trash.reconcile(cardRoot: root);

  // The only write this app ever makes to a card that is not a deletion, and it
  // happens solely because the user turned it on in Réglages, where the switch
  // says it will and states what it costs. Written only when absent, so an
  // opted-in card is not written to again on every open.
  final settings = await ref.watch(settingsProvider.future);
  if (settings.suppressSpotlight &&
      !await File(p.join(root, SpotlightPolicy.markerName)).exists()) {
    await SpotlightPolicy.optIn(root);
  }

  return CardOpenReport(
    debrisRemoved: debris.removed,
    parasites: found.foreign.toList(),
    writable: await cardAcceptsWrites(root),
    reconciled: reconciled.resolved.length,
    losses: reconciled.unresolvedLosses,
  );
});

/// The photographs on the open card.
///
/// Re-scans whenever the selected card changes, and reports nothing at all when
/// none is open — the grid and the volume picker are then showing the same
/// truth rather than one of them holding a stale list.
final cardCatalogProvider = FutureProvider<CardCatalog>((ref) async {
  final selection = ref.watch(cardSelectionProvider);
  if (selection is! CardSelectionOpened) {
    return const CardCatalog(
      photos: [],
      unsupportedFiles: [],
      scanDuration: Duration.zero,
    );
  }
  // Awaited, not merely started: a library built while an interrupted deletion
  // was still unresolved would be showing the user a guess.
  await ref.watch(cardOpenProvider.future);
  return const DcfScanner().scan(selection.path);
});

/// Average colours left in the cache index by earlier sessions.
///
/// Read once, in one pass over the index, rather than per cell: the point of a
/// placeholder is to be there before anything else is, and a query per tile
/// would arrive at about the same time as the thumbnail it was meant to stand
/// in for.
final placeholderColorsProvider = FutureProvider<Map<String, int>>(
  (ref) async => (await ref.watch(thumbCacheProvider.future)).placeholderColors(),
);

/// Which photograph the keyboard is on, as an index into the catalogue.
class GridCursorNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void moveTo(int index) => state = index < 0 ? 0 : index;
}

final gridCursorProvider =
    NotifierProvider<GridCursorNotifier, int>(GridCursorNotifier.new);

/// A keyboard move within the grid.
enum GridMove { previous, next, previousRow, nextRow }

/// Where [index] lands after [move], given a grid [columns] wide holding
/// [count] photographs.
///
/// Pure, and separated from the widget on purpose: this is the whole of the
/// grid's navigation behaviour, and it can be checked exhaustively without
/// pumping a frame.
///
/// Left and right move linearly, so they wrap across row ends — the
/// photographs are a sequence and the rows are only how they happen to be laid
/// out. Up and down move by a row, and stop rather than wrap: reaching the top
/// of the grid should not silently drop the user at the bottom of it.
int moveCursor(
  int index,
  GridMove move, {
  required int columns,
  required int count,
}) {
  if (count <= 0) return 0;
  final from = index.clamp(0, count - 1);
  final width = math.max(1, columns);

  return switch (move) {
    GridMove.previous => math.max(0, from - 1),
    GridMove.next => math.min(count - 1, from + 1),
    GridMove.previousRow => from - width >= 0 ? from - width : from,
    // Landing past the end of a short last row means the last photograph, not
    // nothing: the row below exists, it is simply not full.
    GridMove.nextRow => from + width < count
        ? from + width
        : (from ~/ width < (count - 1) ~/ width ? count - 1 : from),
  };
}

/// The culling grid.
class LibraryGrid extends ConsumerStatefulWidget {
  const LibraryGrid({super.key, required this.photos, this.onOpen});

  final List<PhotoEntity> photos;

  /// Opens the photograph full-frame. The viewer arrives with its own unit; the
  /// grid's job is to say which photograph and when.
  final void Function(PhotoEntity photo)? onOpen;

  /// Width a cell aims for, in logical pixels. The real width is whatever
  /// dividing the viewport by the resulting column count gives.
  static const double targetCellExtent = 220;

  static int columnsFor(double width) {
    const gutter = ObscuraSpacing.gridGutter;
    final usable = width - gutter;
    if (usable <= 0) return 1;
    return math.max(1, (usable / (targetCellExtent + gutter)).floor());
  }

  @override
  ConsumerState<LibraryGrid> createState() => _LibraryGridState();
}

class _LibraryGridState extends ConsumerState<LibraryGrid> {
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'library-grid');

  int _columns = 1;
  double _tileExtent = LibraryGrid.targetCellExtent;

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _move(GridMove move) {
    final cursor = ref.read(gridCursorProvider);
    final next = moveCursor(
      cursor,
      move,
      columns: _columns,
      count: widget.photos.length,
    );
    ref.read(gridCursorProvider.notifier).moveTo(next);
    _revealRowOf(next);
  }

  /// Scrolls the least amount that brings [index]'s row fully into view.
  ///
  /// Computed from the row number rather than from the cell's own context: in a
  /// virtualized grid the cell the user just moved to may not be built yet, and
  /// `ensureVisible` has nothing to work with until it is.
  void _revealRowOf(int index) {
    if (!_scroll.hasClients) return;
    final stride = _tileExtent + ObscuraSpacing.gridGutter;
    final top = (index ~/ math.max(1, _columns)) * stride;
    final bottom = top + _tileExtent;
    final viewport = _scroll.position.viewportDimension;
    final offset = _scroll.offset;

    final target = top < offset
        ? top
        : (bottom > offset + viewport ? bottom - viewport : null);
    if (target == null) return;

    _scroll.animateTo(
      target.clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  void _open() {
    final photos = widget.photos;
    if (photos.isEmpty || widget.onOpen == null) return;
    widget.onOpen!(photos[ref.read(gridCursorProvider).clamp(0, photos.length - 1)]);
  }

  void _toggleMark() {
    final photos = widget.photos;
    if (photos.isEmpty) return;
    _mark(photos[ref.read(gridCursorProvider).clamp(0, photos.length - 1)]);
  }

  /// Records the decision and reports it only when it did not go as the
  /// deletion mode promised.
  ///
  /// Deferred marking says nothing, because a snack bar per keystroke through a
  /// nine-hundred-frame pass is noise. A refused card write is the one thing
  /// the user cannot see from the badge.
  void _mark(PhotoEntity photo) {
    ref.read(markedForDeletionProvider.notifier).toggle(photo).then((report) {
      final detail = report?.detail;
      if (detail == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) return const _EmptyCard();

    final cursor = ref.watch(gridCursorProvider).clamp(0, photos.length - 1);
    final marked = ref.watch(markedForDeletionProvider);
    final placeholders =
        ref.watch(placeholderColorsProvider).value ?? const {};
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Shortcuts(
      shortcuts: shortcutMapFor(ShortcutScope.grid),
      child: Actions(
        actions: {
          PreviousPhotoIntent: CallbackAction<PreviousPhotoIntent>(
            onInvoke: (_) => _move(GridMove.previous),
          ),
          NextPhotoIntent: CallbackAction<NextPhotoIntent>(
            onInvoke: (_) => _move(GridMove.next),
          ),
          PreviousRowIntent: CallbackAction<PreviousRowIntent>(
            onInvoke: (_) => _move(GridMove.previousRow),
          ),
          NextRowIntent: CallbackAction<NextRowIntent>(
            onInvoke: (_) => _move(GridMove.nextRow),
          ),
          OpenViewerIntent: CallbackAction<OpenViewerIntent>(
            onInvoke: (_) => _open(),
          ),
          ToggleMarkForDeletionIntent:
              CallbackAction<ToggleMarkForDeletionIntent>(
            onInvoke: (_) => _toggleMark(),
          ),
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gutter = ObscuraSpacing.gridGutter;
              _columns = LibraryGrid.columnsFor(constraints.maxWidth);
              _tileExtent =
                  (constraints.maxWidth - gutter * (_columns + 1)) / _columns;

              return GridView.builder(
                key: const Key('library-grid'),
                controller: _scroll,
                padding: const EdgeInsets.all(gutter),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns,
                  mainAxisSpacing: gutter,
                  crossAxisSpacing: gutter,
                ),
                itemCount: photos.length,
                itemBuilder: (context, i) {
                  final photo = photos[i];
                  // Both gestures live here rather than in the cell: a cell
                  // that recognised taps of its own would compete with this one
                  // for the same pointer, and a single click would have to wait
                  // out the double-click timer before it selected anything.
                  return GestureDetector(
                    onTap: () {
                      ref.read(gridCursorProvider.notifier).moveTo(i);
                      _focus.requestFocus();
                    },
                    onDoubleTap: () {
                      ref.read(gridCursorProvider.notifier).moveTo(i);
                      _open();
                    },
                    child: PhotoCell(
                      key: Key('cell-${photo.dcfPath}'),
                      photo: photo,
                      // Device pixels, not logical: a Retina cell drawn from a
                      // logical-sized thumbnail is a soft cell.
                      targetShortSide: (_tileExtent * pixelRatio).round(),
                      selected: i == cursor,
                      marked: marked.contains(photo.key.value),
                      placeholderColor: placeholders[photo.key.value],
                      onToggleMark: () {
                        ref.read(gridCursorProvider.notifier).moveTo(i);
                        _mark(photo);
                        _focus.requestFocus();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// What the card open found, once it has finished finding it.
///
/// Nothing while the scan runs: the report is not what the user came for, and
/// making the grid wait on it would put a spinner in front of their photographs
/// to say the card is fine.
class _CardOpenSlot extends ConsumerWidget {
  const _CardOpenSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(cardOpenProvider).value;
    return report == null
        ? const SizedBox.shrink()
        : CardOpenBanner(report: report);
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('empty-card'),
      child: Text(
        'Aucune photographie sur cette carte.',
        style: ObscuraTypography.bodyMedium
            .copyWith(color: ObscuraColors.textSecondary),
      ),
    );
  }
}

/// The grid, wired to the open card.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, this.onOpen});

  final void Function(PhotoEntity photo)? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (ref.watch(librarySectionProvider)) {
      case LibrarySection.trash:
        return const TrashScreen();
      case LibrarySection.settings:
        return const SettingsScreen();
      case LibrarySection.library:
      case LibrarySection.card:
        break;
    }
    return ref.watch(cardCatalogProvider).when(
          loading: () => const Center(
            key: Key('scanning'),
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => Center(
            key: const Key('scan-failed'),
            child: Text(
              'La carte n\'a pas pu être lue.\n$error',
              textAlign: TextAlign.center,
              style: ObscuraTypography.bodyMedium
                  .copyWith(color: ObscuraColors.leicaRed),
            ),
          ),
          data: (catalog) => ref.watch(viewerOpenProvider)
              ? ViewerScreen(photos: catalog.photos)
              : Column(
                  children: [
                    // Above the grid rather than over it: what the card open
                    // found is context for the photographs, not an interruption
                    // of them, and a modal would be dismissed unread.
                    const _CardOpenSlot(),
                    Expanded(
                      child: LibraryGrid(
                        photos: catalog.photos,
                        onOpen: onOpen ??
                            (_) => ref.read(viewerOpenProvider.notifier).open(),
                      ),
                    ),
                  ],
                ),
        );
  }
}
