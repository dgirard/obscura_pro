import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shortcuts.dart';
import '../../app/theme.dart';
import '../../infra/geometry/view_transform.dart';
import '../catalog/photo_entity.dart';
import '../grid/grid_screen.dart';
import '../grid/photo_cell.dart';
import '../grid/thumbnail_provider.dart';
import '../crop/crop_screen.dart';
import '../layers/layer_canvas.dart';
import '../layers/layer_controller.dart';
import '../layers/layers_panel.dart';
import '../trash/trash_providers.dart';
import 'exif_overlay.dart';
import 'obscura.dart';

/// Whether the viewer is showing, rather than the grid.
///
/// The two share [gridCursorProvider]: opening the viewer shows the cell the
/// keyboard was on, arrows move the same cursor, and closing returns to the
/// grid with the selection where the viewer left it. A separate index would let
/// the two disagree, which in a culling pass means marking the wrong frame.
class ViewerOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void open() => state = true;
  void close() => state = false;
}

final viewerOpenProvider =
    NotifierProvider<ViewerOpenNotifier, bool>(ViewerOpenNotifier.new);

/// One decoded full-size preview, at one decode width.
///
/// Auto-disposing: what comes back from the service is a clone the caller owns,
/// and the teardown is what gives it back. The bytes behind it stay in the
/// MEM-1 budget for the next request.
final fullPreviewProvider = FutureProvider.autoDispose
    .family<ui.Image, ({PhotoEntity photo, int targetWidth})>((ref, request) async {
  final service = await ref.watch(thumbnailServiceProvider.future);
  final image = await service.fullPreview(
    request.photo,
    targetWidth: request.targetWidth,
  );
  ref.onDispose(image.dispose);
  return image;
});

/// How many frames either side of the current one are decoded ahead.
///
/// Two, not more: a photographer moving through a session goes one frame at a
/// time in one direction, so the frame after next is already speculative, and
/// each one held costs the MEM-1 budget.
const int kPreloadRadius = 2;

/// Full-frame review.
class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({super.key, required this.photos});

  final List<PhotoEntity> photos;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  final _controller = TransformationController();
  final _focus = FocusNode(debugLabel: 'viewer');

  Size _viewport = Size.zero;
  Offset _lastTap = Offset.zero;
  int _preloadedAround = -1;

  /// The index the last build settled on.
  ///
  /// Held as a field so the keyboard actions can read it: they run outside
  /// build, where watching a provider would register a listener from a place
  /// Riverpod cannot tie to a rebuild.
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_followTransform);
  }

  @override
  void dispose() {
    _controller.removeListener(_followTransform);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Repaints while a pan or a pinch is in progress, but only when something is
  /// laid over the photograph.
  ///
  /// The guides are drawn beside the `InteractiveViewer` rather than inside it
  /// — inside, the zoom would thicken their strokes — so they follow the picture
  /// only if this screen rebuilds as the matrix changes. With no layer placed
  /// the viewer still settles once at the end of the gesture, which is what
  /// keeps the ordinary case at PERF-3's sixty frames.
  void _followTransform() {
    if (!mounted || ref.read(layerBoardProvider).layers.isEmpty) return;
    setState(() {});
  }

  PhotoEntity get _photo => widget.photos[_current.clamp(0, widget.photos.length - 1)];

  double get _devicePixelRatio => MediaQuery.devicePixelRatioOf(context);

  /// Upright pixel size of the frame the viewer is showing.
  Size _uprightSize(PhotoEntity photo) {
    final stream = photo.viewerPreview ?? photo.gridPreview;
    final width = (stream?.width ?? 0).toDouble();
    final height = (stream?.height ?? 0).toDouble();
    if (width <= 0 || height <= 0) return const Size(3, 2);
    return photo.isPortrait ? Size(height, width) : Size(width, height);
  }

  ViewTransform get _transform => ViewTransform(
        imageSize: _uprightSize(_photo),
        viewport: _viewport,
        matrix: _controller.value,
        obscura: ref.read(obscuraProvider),
      );

  /// Decode width for the current zoom.
  ///
  /// Quantized to powers of two, and only ever growing with zoom: without that
  /// a pinch would ask for a different width on every frame it passed through,
  /// and each one is a fresh decode and a fresh cache entry.
  int _decodeWidth(double zoom) {
    if (_viewport.width <= 0) return 1600;
    final wanted = _viewport.width * _devicePixelRatio * math.max(1, zoom);
    final steps = math.max(0, (math.log(wanted / 512) / math.ln2).ceil());
    final quantized = 512 * math.pow(2, steps).toInt();
    final source = _photo.viewerPreview?.width ?? quantized;
    return math.min(quantized, math.max(512, source));
  }

  void _move(int delta) {
    final next = (_current + delta).clamp(0, widget.photos.length - 1);
    if (next == _current) return;
    ref.read(gridCursorProvider.notifier).moveTo(next);
    // Fit again on every new frame: carrying one photograph's zoom onto the
    // next would drop the user into a corner of a picture they have not seen.
    _controller.value = Matrix4.identity();
    setState(() {});
  }

  /// Trims the MEM-1 byte budget down to the preload window.
  ///
  /// The decoding itself is [_PreloadWindow]'s job. This is the other half:
  /// without it the budget fills with frames the user walked past ten
  /// photographs ago, and the eviction that eventually happens takes the ones
  /// they are about to come back to.
  Future<void> _retainWindow(int around) async {
    if (around == _preloadedAround) return;
    _preloadedAround = around;

    final service = await ref.read(thumbnailServiceProvider.future);
    if (!mounted) return;

    service.memory.retain({
      for (var offset = -kPreloadRadius; offset <= kPreloadRadius; offset++)
        if (around + offset >= 0 && around + offset < widget.photos.length)
          widget.photos[around + offset].key.value,
    });
  }

  void _zoomBy(double factor) {
    final t = _transform;
    final target = (t.zoom * factor).clamp(1.0, _maxZoom(t));
    _controller.value =
        t.zoomedAround(_viewport.center(Offset.zero), target);
    setState(() {});
  }

  void _resetZoom() {
    _controller.value = Matrix4.identity();
    setState(() {});
  }

  /// Double-click toggles between the whole frame and actual pixels, around the
  /// point that was clicked rather than the middle of the window.
  void _toggleActualPixels() {
    final t = _transform;
    final actual = t.zoomForActualPixels(_devicePixelRatio);
    final zoomedIn = t.zoom > 1.01;
    _controller.value = zoomedIn
        ? Matrix4.identity()
        : t.zoomedAround(_lastTap, actual.clamp(1.0, _maxZoom(t)));
    setState(() {});
  }

  double _maxZoom(ViewTransform t) =>
      math.max(2, t.zoomForActualPixels(_devicePixelRatio) * 2);

  void _close() => ref.read(viewerOpenProvider.notifier).close();

  void _toggleMark() {
    ref.read(markedForDeletionProvider.notifier).toggle(_photo).then((report) {
      final detail = report?.detail;
      if (detail == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return const SizedBox.shrink();

    // Watched here and nowhere else: the cursor is shared with the grid, and a
    // viewer that sampled it once would keep showing the frame it opened on.
    final index =
        ref.watch(gridCursorProvider).clamp(0, widget.photos.length - 1);
    _current = index;
    final photo = widget.photos[index];
    final obscura = ref.watch(obscuraProvider);
    final showExif = ref.watch(exifOverlayVisibleProvider);
    final marked = ref.watch(markedForDeletionProvider).contains(photo.key.value);
    final layersOpen = ref.watch(layersPanelProvider);

    // Crop mode replaces the viewer rather than floating over it: choosing a
    // frame is a different activity from reviewing one, and the chrome of the
    // second would only get in the way of the first.
    if (ref.watch(cropModeProvider)) return CropScreen(photo: photo);

    return Shortcuts(
      shortcuts: shortcutMapFor(ShortcutScope.viewer),
      child: Actions(
        actions: {
          PreviousPhotoIntent:
              CallbackAction<PreviousPhotoIntent>(onInvoke: (_) => _move(-1)),
          NextPhotoIntent:
              CallbackAction<NextPhotoIntent>(onInvoke: (_) => _move(1)),
          CloseViewerIntent:
              CallbackAction<CloseViewerIntent>(onInvoke: (_) => _close()),
          ToggleObscuraIntent: CallbackAction<ToggleObscuraIntent>(
            onInvoke: (_) => ref.read(obscuraProvider.notifier).toggle(),
          ),
          ZoomInIntent:
              CallbackAction<ZoomInIntent>(onInvoke: (_) => _zoomBy(1.4)),
          ZoomOutIntent:
              CallbackAction<ZoomOutIntent>(onInvoke: (_) => _zoomBy(1 / 1.4)),
          ZoomResetIntent:
              CallbackAction<ZoomResetIntent>(onInvoke: (_) => _resetZoom()),
          ToggleMarkForDeletionIntent:
              CallbackAction<ToggleMarkForDeletionIntent>(
            onInvoke: (_) => _toggleMark(),
          ),
          EnterCropModeIntent: CallbackAction<EnterCropModeIntent>(
            onInvoke: (_) => ref.read(cropModeProvider.notifier).enter(),
          ),
          ToggleLayersPanelIntent: CallbackAction<ToggleLayersPanelIntent>(
            onInvoke: (_) => ref.read(layersPanelProvider.notifier).toggle(),
          ),
          // Undo is global in the keyboard table and reaches the composition
          // here. Marking has no undo yet — that is U9's half of this binding,
          // and it is not built — so on a photograph with no layers on it ⌘Z
          // does nothing rather than something surprising.
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) => ref.read(layerBoardProvider.notifier).undo(),
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) => ref.read(layerBoardProvider.notifier).redo(),
          ),
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          child: Row(
            children: [
              Expanded(
                child: _canvas(
                  photo: photo,
                  index: index,
                  obscura: obscura,
                  showExif: showExif,
                  marked: marked,
                  layersOpen: layersOpen,
                ),
              ),
              // Beside the photograph and never over it: the panel is where a
              // guide is chosen and the picture is where it is judged, and a
              // floating palette would cover the corner of the frame the
              // composition is usually about.
              if (layersOpen) const LayersPanel(),
            ],
          ),
        ),
      ),
    );
  }

  /// The photograph, its overlays and its chrome.
  Widget _canvas({
    required PhotoEntity photo,
    required int index,
    required bool obscura,
    required bool showExif,
    required bool marked,
    required bool layersOpen,
  }) {
    return ColoredBox(
      color: ObscuraColors.canvas,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = constraints.biggest;
          final width = _decodeWidth(_transform.zoom);
          // Scheduled rather than called: preloading during build would
          // mutate providers mid-frame, and so would pointing the
          // composition at this photograph.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _retainWindow(index);
            if (mounted) ref.read(layerBoardProvider.notifier).open(photo);
          });

          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onDoubleTapDown: (d) => _lastTap = d.localPosition,
                onDoubleTap: _toggleActualPixels,
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: 1,
                  maxScale: _maxZoom(_transform),
                  // Spec caveat 3: on a Mac the natural gesture over a
                  // photograph is a trackpad pinch, which arrives as a
                  // scroll unless this is on.
                  trackpadScrollCausesScale: true,
                  onInteractionEnd: (_) => setState(() {}),
                  child: _Frame(
                    photo: photo,
                    targetWidth: width,
                    obscura: obscura,
                  ),
                ),
              ),
              _PreloadWindow(
                photos: widget.photos,
                index: index,
                targetWidth: width,
              ),
              // Above the picture and below the chrome: a guide belongs
              // on the photograph, and the position counter and the
              // buttons belong on top of both.
              LayerCanvas(transform: _transform, interactive: layersOpen),
              if (marked) const _MarkedBanner(),
              if (showExif)
                IgnorePointer(child: ExifOverlay(photo: photo)),
              _Chrome(
                photo: photo,
                position: '${index + 1} / ${widget.photos.length}',
                obscura: obscura,
                showExif: showExif,
                marked: marked,
                onToggleMark: _toggleMark,
                onClose: _close,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Keeps the frames either side of the current one decoded and ready.
///
/// It watches their providers rather than firing decodes and forgetting them,
/// which is what makes the window exact: Riverpod holds precisely what is
/// watched and tears down what leaves the window, and each teardown gives its
/// clone back. Fire-and-forget would leak a reference per frame walked past.
///
/// Draws nothing.
class _PreloadWindow extends ConsumerWidget {
  const _PreloadWindow({
    required this.photos,
    required this.index,
    required this.targetWidth,
  });

  final List<PhotoEntity> photos;
  final int index;
  final int targetWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    for (var offset = -kPreloadRadius; offset <= kPreloadRadius; offset++) {
      final i = index + offset;
      if (i < 0 || i >= photos.length) continue;
      final photo = photos[i];
      if (photo.viewerPreview == null) continue;
      ref.watch(fullPreviewProvider((photo: photo, targetWidth: targetWidth)));
    }
    return const SizedBox.shrink();
  }
}

/// The photograph itself, with the grid thumbnail standing in until the
/// full-size decode lands.
///
/// The stand-in is what makes next/previous feel instant: the thumbnail is
/// already in memory or a millisecond off disk, so the frame changes at once
/// and sharpens a moment later, instead of the window going black while a
/// 13 MB stream is read and decoded (PERF-2).
class _Frame extends ConsumerWidget {
  const _Frame({
    required this.photo,
    required this.targetWidth,
    required this.obscura,
  });

  final PhotoEntity photo;
  final int targetWidth;
  final bool obscura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orientation = DisplayOrientation.of(photo.orientation, obscura: obscura);

    if (photo.viewerPreview == null) {
      return _Unrenderable(photo: photo, key: const Key('viewer-unreadable'));
    }

    final full = ref.watch(
      fullPreviewProvider((photo: photo, targetWidth: targetWidth)),
    );

    return full.when(
      data: (image) => OrientedImage(
        key: const Key('viewer-image'),
        image: image,
        orientation: orientation,
        // The decode was sized for this viewport, so there is nothing to gain
        // from a costlier filter — except while zoomed past it.
        filterQuality: FilterQuality.medium,
      ),
      error: (_, _) => _Unrenderable(photo: photo),
      loading: () => _ThumbnailStandIn(photo: photo, obscura: obscura),
    );
  }
}

class _ThumbnailStandIn extends ConsumerWidget {
  const _ThumbnailStandIn({required this.photo, required this.obscura});

  final PhotoEntity photo;
  final bool obscura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnail = ref.watch(
      gridThumbnailProvider((photo: photo, shortSide: 800)),
    );

    return thumbnail.when(
      // The thumbnail is already upright — the pipeline bakes EXIF rotation in
      // — so only obscura is left to apply here.
      data: (image) => Transform.rotate(
        angle: obscura ? math.pi : 0,
        child: Image.memory(
          image.jpeg,
          key: const Key('viewer-standin'),
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      ),
      error: (_, _) => const SizedBox.expand(),
      loading: () => const SizedBox.expand(),
    );
  }
}

class _Unrenderable extends StatelessWidget {
  const _Unrenderable({super.key, required this.photo});

  final PhotoEntity photo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined,
              size: 32, color: ObscuraColors.textSecondary),
          const SizedBox(height: ObscuraSpacing.controlGap),
          Text(
            '${photo.radical} n\'a pas de preview lisible.',
            style: ObscuraTypography.bodyMedium
                .copyWith(color: ObscuraColors.textSecondary),
          ),
          const SizedBox(height: ObscuraSpacing.controlGap / 2),
          Text(
            'La photographie reste sélectionnable et supprimable.',
            style: ObscuraTypography.bodySmall
                .copyWith(color: ObscuraColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The red edge on a frame marked for deletion.
///
/// A border and not a wash: the viewer is where composition is judged, and
/// tinting the photograph to say something about its filing would corrupt the
/// one thing the screen exists to show.
class _MarkedBanner extends StatelessWidget {
  const _MarkedBanner();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          key: const Key('viewer-marked'),
          decoration: BoxDecoration(
            border: Border.all(
              color: ObscuraColors.statusDelete,
              width: ObscuraStrokes.selection * 2,
            ),
          ),
        ),
      );
}

class _Chrome extends ConsumerWidget {
  const _Chrome({
    required this.photo,
    required this.position,
    required this.obscura,
    required this.showExif,
    required this.marked,
    required this.onToggleMark,
    required this.onClose,
  });

  final PhotoEntity photo;
  final String position;
  final bool obscura;
  final bool showExif;
  final bool marked;
  final VoidCallback onToggleMark;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(ObscuraSpacing.overlayPadding),
      child: Align(
        alignment: Alignment.topRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              position,
              key: const Key('viewer-position'),
              style: ObscuraTypography.monoData
                  .copyWith(color: ObscuraColors.textSecondary),
            ),
            const SizedBox(width: ObscuraSpacing.overlayPadding),
            // The same control as on the grid cell, in the same red, doing the
            // same thing. A photographer decides a frame's fate while looking
            // at it full size at least as often as from the grid, and having to
            // go back to find the button would be the reason they stopped
            // looking properly.
            _ChromeButton(
              tooltip: marked
                  ? 'Ne plus supprimer (⌫)'
                  : 'Marquer à supprimer (⌫)',
              icon: marked ? Icons.delete : Icons.delete_outline,
              active: marked,
              onPressed: onToggleMark,
            ),
            _ChromeButton(
              tooltip: 'Recadrer (C)',
              icon: Icons.crop,
              active: false,
              onPressed: () => ref.read(cropModeProvider.notifier).enter(),
            ),
            _ChromeButton(
              tooltip: 'Vision obscura (O)',
              icon: Icons.flip_camera_android_outlined,
              active: obscura,
              onPressed: () => ref.read(obscuraProvider.notifier).toggle(),
            ),
            _ChromeButton(
              tooltip: 'Informations de prise de vue',
              icon: Icons.info_outline,
              active: showExif,
              onPressed: () =>
                  ref.read(exifOverlayVisibleProvider.notifier).toggle(),
            ),
            _ChromeButton(
              tooltip: 'Retour à la grille (Entrée)',
              icon: Icons.close,
              active: false,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChromeButton extends StatelessWidget {
  const _ChromeButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: Key('viewer-chrome-${icon.codePoint}'),
        onPressed: onPressed,
        iconSize: 18,
        color: active ? ObscuraColors.leicaRed : ObscuraColors.textSecondary,
        icon: Icon(icon),
      ),
    );
  }
}
