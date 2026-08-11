import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shortcuts.dart';
import '../../app/theme.dart';
import '../catalog/dcf_scanner.dart';
import '../catalog/photo_entity.dart';
import '../volume_select/card_selection.dart';
import 'photo_cell.dart';
import 'thumbnail_provider.dart';

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

/// Photographs marked for deletion, by stable key.
///
/// In memory for now, and deliberately so: nothing about marking touches the
/// card, and the durable trash — with its own table, its undo and its atomic
/// empty pass — belongs to the deletion unit. What the grid needs today is
/// somewhere to put the fact so it can draw it.
class MarkedForDeletionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String stableKey) {
    final next = {...state};
    if (!next.remove(stableKey)) next.add(stableKey);
    state = next;
  }
}

final markedForDeletionProvider =
    NotifierProvider<MarkedForDeletionNotifier, Set<String>>(
  MarkedForDeletionNotifier.new,
);

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
    final photo = photos[ref.read(gridCursorProvider).clamp(0, photos.length - 1)];
    ref.read(markedForDeletionProvider.notifier).toggle(photo.key.value);
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
          data: (catalog) =>
              LibraryGrid(photos: catalog.photos, onOpen: onOpen),
        );
  }
}
