import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infra/db/database_provider.dart';
import '../catalog/photo_entity.dart';
import 'layer_placement.dart';
import 'layer_repository.dart';

/// Whether the layers panel is showing (L).
class LayersPanelNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void close() => state = false;
}

final layersPanelProvider =
    NotifierProvider<LayersPanelNotifier, bool>(LayersPanelNotifier.new);

/// Overridden in widget tests, which have no database.
final layerRepositoryProvider = Provider<LayerStore>(
  (ref) => LayerRepository(ref.watch(appDatabaseProvider)),
);

/// The composition on the photograph currently open.
///
/// [durable] carries the same meaning it does for marks: the layers on screen
/// are what the user placed, and a failed write costs their survival rather
/// than their existence. The panel says so instead of the app pretending the
/// composition is saved.
@immutable
final class LayerBoard {
  const LayerBoard({
    this.photoKey,
    this.layers = const [],
    this.selected,
    this.loading = false,
    this.durable = true,
    this.failure,
    this.undoDepth = 0,
    this.redoDepth = 0,
  });

  /// Stable key of the photograph these belong to, or null before one is open.
  final String? photoKey;

  /// In paint order: z-index, then placement order for ties.
  final List<LayerPlacement> layers;

  /// [LayerPlacement.localId] of the layer showing its handles.
  final int? selected;

  final bool loading;
  final bool durable;
  final String? failure;

  final int undoDepth;
  final int redoDepth;

  LayerPlacement? get selectedLayer {
    for (final layer in layers) {
      if (layer.localId == selected) return layer;
    }
    return null;
  }

  bool get isEmpty => layers.isEmpty;

  LayerBoard copyWith({
    String? photoKey,
    List<LayerPlacement>? layers,
    int? selected,
    bool clearSelection = false,
    bool? loading,
    bool? durable,
    String? failure,
    bool clearFailure = false,
    int? undoDepth,
    int? redoDepth,
  }) =>
      LayerBoard(
        photoKey: photoKey ?? this.photoKey,
        layers: layers ?? this.layers,
        selected: clearSelection ? null : (selected ?? this.selected),
        loading: loading ?? this.loading,
        durable: durable ?? this.durable,
        failure: clearFailure ? null : (failure ?? this.failure),
        undoDepth: undoDepth ?? this.undoDepth,
        redoDepth: redoDepth ?? this.redoDepth,
      );
}

/// Placing, moving and remembering composition layers.
///
/// The memory is authoritative and the database is written through behind it,
/// for the reason the marking notifier gives: a guide has to follow the pointer
/// on the frame the pointer moved, not on the frame the disk came back. What a
/// failed write costs is stated ([LayerBoard.durable]) rather than swallowed.
///
/// Undo is a stack of whole compositions rather than of inverse operations. A
/// composition is a handful of small records, so a snapshot costs nothing, and
/// the alternative — an inverse per mutation — is a second implementation of
/// every mutation, kept in step by hope.
class LayerBoardNotifier extends Notifier<LayerBoard> {
  /// Deep enough for a session's worth of adjusting, bounded so a long one
  /// cannot grow without limit.
  static const int undoLimit = 64;

  final List<List<LayerPlacement>> _undo = [];
  final List<List<LayerPlacement>> _redo = [];

  PhotoEntity? _photo;
  int _nextLocalId = 1;

  /// Writes are chained rather than fired: two `save` calls in flight would
  /// both see a placement with no row id and both insert it.
  Future<void> _writes = Future<void>.value();

  /// The read of the open photograph's composition, while it is in flight.
  ///
  /// Every write waits on it. Without that wait, placing a guide in the moment
  /// between opening a photograph and its layers arriving writes a composition
  /// consisting of that one guide — and `save` makes the stored set match what
  /// it is given, so the layers still on their way back are deleted. It is a
  /// narrow window and it cost seventeen guides the first time the app was
  /// driven by hand.
  Future<void>? _reading;

  @override
  LayerBoard build() => const LayerBoard();

  /// Points the board at [photo] and loads what was saved on it.
  ///
  /// A no-op when it is already the open photograph, because the viewer calls
  /// this from build.
  void open(PhotoEntity photo) {
    if (_photo?.key.value == photo.key.value) return;
    _photo = photo;
    _undo.clear();
    _redo.clear();
    state = LayerBoard(photoKey: photo.key.value, loading: true);
    _reading = _load(photo);
  }

  Future<void> _load(PhotoEntity photo) async {
    try {
      final loaded = await ref.read(layerRepositoryProvider).layersOf(photo);
      // The user may have moved on, or placed a guide while the read was in
      // flight. Both are theirs; neither is thrown away.
      if (!ref.mounted || _photo?.key.value != photo.key.value) return;
      _nextLocalId = loaded.fold(_nextLocalId, (n, l) => math.max(n, l.localId + 1));
      state = state.copyWith(
        layers: _ordered([...loaded, ...state.layers]),
        loading: false,
      );
    } on Object catch (error) {
      if (!ref.mounted || _photo?.key.value != photo.key.value) return;
      state = state.copyWith(loading: false, durable: false, failure: '$error');
    }
  }

  void select(int? localId) => state = localId == null
      ? state.copyWith(clearSelection: true)
      : state.copyWith(selected: localId);

  /// Drops a guide on the photograph, on top and selected.
  ///
  /// Full-frame by default: a construction of the frame is what the fifteen
  /// are, so the first thing a photographer wants to see is the rule over the
  /// whole picture. Resizing it to a part of the frame is the second thing, and
  /// that is what the handles are for.
  void place(String patternCode, {bool obscura = false}) {
    _record();
    final top = state.layers.fold(0, (z, l) => math.max(z, l.zIndex));
    final placement = LayerPlacement(
      localId: _nextLocalId++,
      patternCode: patternCode,
      zIndex: top + 1,
      obscura: obscura,
    );
    state = state.copyWith(
      layers: _ordered([...state.layers, placement]),
      selected: placement.localId,
    );
    _persist();
  }

  /// Takes a snapshot before a drag or a slider starts moving.
  ///
  /// Called once per gesture rather than once per frame: undoing a drag should
  /// put the guide back where it was picked up, not a pixel back along the way.
  void beginChange() => _record();

  /// Replaces one layer, without touching the undo stack or the disk.
  ///
  /// This is the per-frame call during a drag.
  void apply(LayerPlacement next) {
    state = state.copyWith(
      layers: [
        for (final layer in state.layers)
          if (layer.localId == next.localId) next else layer,
      ],
    );
  }

  /// End of a gesture: what is on screen is now worth writing down.
  void commit() => _persist();

  void remove(int localId) {
    _record();
    state = state.copyWith(
      layers: [
        for (final layer in state.layers)
          if (layer.localId != localId) layer,
      ],
      clearSelection: state.selected == localId,
    );
    _persist();
  }

  /// Takes every guide off this photograph.
  ///
  /// One undo step, not one per layer: clearing a composition is a single
  /// decision, and ⌘Z has to be able to take it back in one press — which is
  /// the whole reason this is offered at all rather than seventeen presses of a
  /// small button.
  void clear() {
    if (state.layers.isEmpty) return;
    _record();
    state = state.copyWith(layers: const [], clearSelection: true);
    _persist();
  }

  void toggleLock(int localId) {
    _record();
    _replace(localId, (layer) => layer.copyWith(locked: !layer.locked));
    _persist();
  }

  /// Moves a layer one place up or down the paint order.
  ///
  /// By swapping z with its neighbour rather than by renumbering everything:
  /// the numbers are the user's order and only two of them changed.
  void reorder(int localId, {required bool up}) {
    final ordered = state.layers;
    final index = ordered.indexWhere((l) => l.localId == localId);
    final other = index + (up ? 1 : -1);
    if (index < 0 || other < 0 || other >= ordered.length) return;

    _record();
    final a = ordered[index];
    final b = ordered[other];
    state = state.copyWith(
      layers: _ordered([
        for (final layer in ordered)
          if (layer.localId == a.localId)
            a.copyWith(zIndex: b.zIndex)
          else if (layer.localId == b.localId)
            b.copyWith(zIndex: a.zIndex)
          else
            layer,
      ]),
    );
    _persist();
  }

  /// Every layer's stroke, or only the selected one's.
  ///
  /// The panel's appearance controls act on the selection when there is one and
  /// on the whole composition when there is not — which is what a photographer
  /// means by "make them lighter" with nothing selected.
  void setAppearance({double? opacity, int? color, bool record = true}) {
    if (record) _record();
    final target = state.selected;
    state = state.copyWith(
      layers: [
        for (final layer in state.layers)
          if (target == null || layer.localId == target)
            layer.copyWith(opacity: opacity, color: color)
          else
            layer,
      ],
    );
  }

  void setRotation(double radians, {bool record = false}) {
    final target = state.selected;
    if (target == null) return;
    if (record) _record();
    _replace(target, (layer) => layer.copyWith(rotation: radians));
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(state.layers);
    state = state.copyWith(
      layers: _undo.removeLast(),
      undoDepth: _undo.length,
      redoDepth: _redo.length,
      clearSelection: true,
    );
    _persist();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(state.layers);
    state = state.copyWith(
      layers: _redo.removeLast(),
      undoDepth: _undo.length,
      redoDepth: _redo.length,
      clearSelection: true,
    );
    _persist();
  }

  void _replace(int localId, LayerPlacement Function(LayerPlacement) change) {
    state = state.copyWith(
      layers: [
        for (final layer in state.layers)
          if (layer.localId == localId) change(layer) else layer,
      ],
    );
  }

  void _record() {
    _undo.add(state.layers);
    if (_undo.length > undoLimit) _undo.removeAt(0);
    _redo.clear();
    state = state.copyWith(undoDepth: _undo.length, redoDepth: 0);
  }

  static List<LayerPlacement> _ordered(List<LayerPlacement> layers) =>
      [...layers]..sort((a, b) {
        final byZ = a.zIndex.compareTo(b.zIndex);
        return byZ != 0 ? byZ : a.localId.compareTo(b.localId);
      });

  void _persist() {
    final photo = _photo;
    if (photo == null) return;
    _writes = _writes.then((_) async {
      try {
        // Never write over rows that have not been read yet.
        await _reading;
        if (!ref.mounted || _photo?.key.value != photo.key.value) return;

        // Taken here rather than when the write was asked for, so that what
        // reaches the disk is the composition as it stands once the read has
        // merged into it — the placement that triggered this *and* everything
        // it was placed on top of.
        final snapshot = state.layers;
        final store = ref.read(layerRepositoryProvider);
        final saved = await store.save(photo, snapshot);
        // The screen may have closed under the write. The row is on disk either
        // way, which is the half that matters; what is gone is the state to
        // report it to.
        if (!ref.mounted || _photo?.key.value != photo.key.value) return;
        // Row ids only: the transforms on screen may have moved on since this
        // write started, and taking the saved copies would drag the guide back
        // to where it was when the pointer passed through.
        final rows = {
          for (final layer in saved)
            if (layer.rowId != null) layer.localId: layer.rowId!,
        };
        state = state.copyWith(
          layers: [
            for (final layer in state.layers)
              if (layer.rowId == null && rows[layer.localId] != null)
                layer.copyWith(rowId: rows[layer.localId])
              else
                layer,
          ],
          durable: true,
          clearFailure: true,
        );
      } on Object catch (error) {
        if (!ref.mounted) return;
        state = state.copyWith(durable: false, failure: '$error');
      }
    });
  }
}

final layerBoardProvider =
    NotifierProvider<LayerBoardNotifier, LayerBoard>(LayerBoardNotifier.new);
