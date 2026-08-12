import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../infra/geometry/view_transform.dart';
import 'handles.dart';
import 'layer_controller.dart';
import 'layer_painter.dart';
import 'layer_placement.dart';

/// The guides over the photograph, and the pointer that moves them.
///
/// Interactive only while the panel is open, and then only where a guide
/// actually is: [_LayerHitArea] refuses the hit everywhere else, so the drag
/// falls through to the viewer's own pan and zoom. Without that, opening the
/// panel would quietly take away the ability to move around the picture you are
/// composing on — which is when you most want it.
class LayerCanvas extends ConsumerStatefulWidget {
  const LayerCanvas({
    super.key,
    required this.transform,
    required this.interactive,
  });

  final ViewTransform transform;

  /// True while the layers panel is open.
  final bool interactive;

  @override
  ConsumerState<LayerCanvas> createState() => _LayerCanvasState();
}

class _LayerCanvasState extends ConsumerState<LayerCanvas> {
  /// What the pointer went down on, recorded before any gesture is recognised.
  (LayerPlacement, GuideHandle)? _pressed;

  GuideHandle? _grabbed;

  /// The layer as it was when the drag started, and where the pointer was.
  ///
  /// Every update is computed from these rather than from the layer's current
  /// state. Feeding each frame's result back in looks equivalent and is not: a
  /// corner drag maps the pointer through the layer's own frame, so a layer
  /// that has already moved maps it differently, and the guide walks away from
  /// the pointer a little more with every frame.
  LayerPlacement? _origin;
  Offset _from = Offset.zero;

  /// The topmost layer under [point], and what part of it.
  ///
  /// Topmost, so the guide you can see is the one you grab: the list is in
  /// paint order and the last one drawn is the one on top.
  (LayerPlacement, GuideHandle)? _under(Offset point) {
    final layers = ref.read(layerBoardProvider).layers;
    for (final placement in layers.reversed) {
      final frame = LayerFrame(placement: placement, transform: widget.transform);
      final handle = frame.hitTest(point, slop: ObscuraStrokes.handleHitSize * 1.6);
      if (handle != null) return (placement, handle);
    }
    return null;
  }

  void _down(TapDownDetails details) {
    final hit = _pressed ?? _under(details.localPosition);
    ref.read(layerBoardProvider.notifier).select(hit?.$1.localId);
  }

  void _start(DragStartDetails details) {
    // What was under the pointer when it went down, not where the gesture was
    // recognised: a pan is not recognised until the pointer has travelled the
    // touch slop, by which time it is twenty pixels off the handle it was
    // pressed on, and every corner drag would come out as a move.
    final hit = _pressed ?? _under(details.localPosition);
    if (hit == null) return;
    final (placement, handle) = hit;
    ref.read(layerBoardProvider.notifier)
      ..select(placement.localId)
      ..beginChange();
    _grabbed = handle;
    _origin = placement;
    _from = details.localPosition;
  }

  void _update(DragUpdateDetails details) {
    final origin = _origin;
    final handle = _grabbed;
    if (origin == null || handle == null || origin.locked) return;

    final frame = LayerFrame(placement: origin, transform: widget.transform);
    final next = handle.isCorner
        ? frame.resized(handle, details.localPosition, free: _freeScale)
        : frame.moved(_from, details.localPosition);
    ref.read(layerBoardProvider.notifier).apply(next);
  }

  void _end() {
    if (_origin != null) ref.read(layerBoardProvider.notifier).commit();
    _grabbed = null;
    _origin = null;
    _pressed = null;
  }

  /// Shift frees the two axes. Without it a corner scales both together, which
  /// is what a construction wants: a golden spiral stretched on one axis is not
  /// a golden spiral any more.
  bool get _freeScale => HardwareKeyboard.instance.logicalKeysPressed
      .any((key) =>
          key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight ||
          key == LogicalKeyboardKey.shift);

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(layerBoardProvider);

    final painted = CustomPaint(
      key: const Key('layer-canvas'),
      size: Size.infinite,
      painter: LayerPainter(
        layers: board.layers,
        transform: widget.transform,
        selected: board.selected,
        showHandles: widget.interactive,
      ),
    );

    if (!widget.interactive || board.layers.isEmpty) {
      return IgnorePointer(child: painted);
    }

    return _LayerHitArea(
      hits: (point) => _under(point) != null,
      child: Listener(
        onPointerDown: (event) => _pressed = _under(event.localPosition),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _down,
          onPanStart: _start,
          onPanUpdate: _update,
          onPanEnd: (_) => _end(),
          onPanCancel: _end,
          child: painted,
        ),
      ),
    );
  }
}

/// A box that is only there where [hits] says it is.
///
/// The alternative was a full-canvas gesture detector, which wins the arena for
/// every drag on the photograph and would have made panning impossible with the
/// panel open. Refusing the hit test — rather than accepting it and doing
/// nothing — is what lets the event reach the `InteractiveViewer` underneath.
class _LayerHitArea extends SingleChildRenderObjectWidget {
  const _LayerHitArea({required this.hits, required super.child});

  final bool Function(Offset local) hits;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayerHitArea(hits);

  @override
  void updateRenderObject(BuildContext context, _RenderLayerHitArea render) {
    render.hits = hits;
  }
}

class _RenderLayerHitArea extends RenderProxyBox {
  _RenderLayerHitArea(this.hits);

  bool Function(Offset local) hits;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!hits(position)) return false;
    return super.hitTest(result, position: position);
  }
}
