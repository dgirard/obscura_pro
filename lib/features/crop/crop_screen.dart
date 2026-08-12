import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shortcuts.dart';
import '../../app/theme.dart';
import '../../infra/geometry/view_transform.dart';
import '../catalog/photo_entity.dart';
import '../exports/export_store.dart';
import '../viewer/obscura.dart';
import '../viewer/viewer_screen.dart';
import '../settings/settings_store.dart';
import 'export_service.dart';
import 'ratio.dart';

/// Whether crop mode is showing.
class CropModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() => state = true;
  void leave() => state = false;
}

final cropModeProvider =
    NotifierProvider<CropModeNotifier, bool>(CropModeNotifier.new);

/// The crop currently being composed.
///
/// Held per session rather than per photograph, and reset when the frame
/// changes: carrying one picture's rectangle onto the next would be applying a
/// decision to a composition it was never made about.
class CropRectNotifier extends Notifier<CropRect?> {
  @override
  CropRect? build() => null;

  void reset(double frameAspect) {
    state = CropRect.largestIn(
      frameAspect: frameAspect,
      ratio: CropRatio.threeTwo,
    );
  }

  void chooseRatio(CropRatio ratio, double frameAspect) {
    final current = state;
    state = current == null
        ? CropRect.largestIn(frameAspect: frameAspect, ratio: ratio)
        : current.withRatio(ratio, frameAspect: frameAspect);
  }

  void turn(double frameAspect) {
    final current = state;
    if (current != null) state = current.turned(frameAspect: frameAspect);
  }

  void straighten(double degrees, double frameAspect) {
    final current = state;
    if (current == null) return;
    state = current.straightenedTo(degrees, frameAspect: frameAspect);
  }

  void resize(CropCorner corner, Offset pointer, double frameAspect) {
    final current = state;
    if (current == null) return;
    state = current.resizedFrom(
      corner: corner,
      pointer: pointer,
      frameAspect: frameAspect,
    );
  }

  /// Slides the rectangle without changing anything else about it.
  ///
  /// [frameAspect] is not optional and the angle is carried across: rebuilding
  /// a [CropRect] and leaving `angleDegrees` to its default silently threw away
  /// a straightening the user had just made, and clamping without the frame's
  /// aspect let the crop drift into the empty corners a turn leaves behind.
  void moveTo(Offset topLeft, double frameAspect) {
    final current = state;
    if (current == null) return;
    state = CropRect(
      rect: Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        current.rect.width,
        current.rect.height,
      ),
      ratio: current.ratio,
      orientation: current.orientation,
      angleDegrees: current.angleDegrees,
    ).clampedToFrame(frameAspect: frameAspect);
  }
}

final cropRectProvider =
    NotifierProvider<CropRectNotifier, CropRect?>(CropRectNotifier.new);

/// Where exports go.
final exportFolderProvider = FutureProvider<Directory>((ref) async {
  final chosen = ref.watch(settingsProvider).value?.exportFolder;
  return chosen == null ? defaultExportFolder() : Directory(chosen);
});

/// Crop mode over the open photograph.
///
/// The rectangle is composed here and exported from the full-resolution
/// preview, never from what this screen is displaying. That separation is the
/// unit's whole point: the widget shows a picture sized for the window, and
/// exporting what the widget holds would silently throw away eleven twelfths of
/// the photograph.
class CropScreen extends ConsumerStatefulWidget {
  const CropScreen({super.key, required this.photo});

  final PhotoEntity photo;

  @override
  ConsumerState<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends ConsumerState<CropScreen> {
  Size _viewport = Size.zero;
  String? _lastExport;
  String? _failure;
  bool _busy = false;

  /// Whether the frame has been applied to the picture on screen.
  ///
  /// The screen used to show the whole photograph under a veil from the moment
  /// it opened until the file was written, which left the crop looking like a
  /// decoration: nothing on screen ever became the picture being made. Applying
  /// it is not a step in the export — the rectangle was always what got cut —
  /// it is the step that lets a photographer see what they are about to get.
  bool _applied = false;

  /// The corner being dragged, or null while the whole rectangle is moving.
  CropCorner? _grabbed;

  double get _frameAspect {
    final stream = widget.photo.viewerPreview ?? widget.photo.gridPreview;
    final width = (stream?.width ?? 3).toDouble();
    final height = (stream?.height ?? 2).toDouble();
    if (width <= 0 || height <= 0) return 3 / 2;
    return widget.photo.isPortrait ? height / width : width / height;
  }

  /// What the export will actually be, in pixels.
  ///
  /// Computed from the full-resolution preview rather than from what is on
  /// screen — which is the whole point of the export path, and the number a
  /// photographer needs before pressing the button rather than after. Null when
  /// the frame has no readable preview to cut from.
  String? _pixelSize(CropRect? crop) {
    final source = widget.photo.viewerPreview;
    if (crop == null || source == null) return null;
    final stored = Size(
      (source.width ?? 0).toDouble(),
      (source.height ?? 0).toDouble(),
    );
    if (stored.isEmpty) return null;
    final upright =
        widget.photo.isPortrait ? stored.flipped : stored;
    // The straightened canvas is what the rectangle lives in, so the source is
    // measured the same way before the fraction is taken off it.
    final canvas = Size(
      upright.height *
          CropRect.straightenedAspect(_frameAspect, crop.angleDegrees),
      upright.height,
    );
    final width = (crop.rect.width * canvas.width).round();
    final height = (crop.rect.height * canvas.height).round();
    return '$width × $height px';
  }

  /// The mapping between screen and crop coordinates, for a given angle.
  ///
  /// Built on the *straightened* canvas, because that is the space
  /// [CropRect.rect] is documented to live in. Building it on the unrotated
  /// frame instead — which is what this used to do — left the overlay, the
  /// corner hit-testing and the export each working in a slightly different
  /// space the moment the horizon was pulled off zero.
  ViewTransform _transformFor(double angleDegrees) => ViewTransform(
        imageSize: Size(
          CropRect.straightenedAspect(_frameAspect, angleDegrees) * 1000,
          1000,
        ),
        viewport: _viewport,
      );

  @override
  void initState() {
    super.initState();
    // After the first frame, so the notifier is not written during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(cropRectProvider.notifier).reset(_frameAspect);
    });
  }

  Future<void> _export() async {
    final crop = ref.read(cropRectProvider);
    if (crop == null || _busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });

    // Everything from here is guarded. `export` reports the failures it can
    // name, but the folder lookup and the decoder can both throw something it
    // does not, and an escaping exception used to leave `_busy` true for ever:
    // the button stayed disabled with no message, and the only way out was to
    // leave crop mode.
    final ExportOutcome outcome;
    try {
      final folder = await ref.read(exportFolderProvider.future);
      outcome = await const ExportService().export(
        photo: widget.photo,
        crop: crop,
        folder: folder,
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = 'export impossible : $error';
        });
      }
      return;
    }
    if (!mounted) return;

    setState(() {
      _busy = false;
      switch (outcome) {
        case ExportWritten(:final path, :final pixelWidth, :final pixelHeight):
          _lastExport = '${path.split('/').last}  ·  '
              '$pixelWidth × $pixelHeight px';
        case ExportFailed(:final reason):
          _failure = reason;
      }
    });

    // Recorded after the file is on disk, never before: `crop_export` is a
    // record of what was written, and a row for a file that failed to be
    // written would be the exports list inventing a deliverable. A refused
    // write leaves the file — which is the half that matters — and says so.
    if (outcome case final ExportWritten written) {
      try {
        await ref.read(exportStoreProvider).record(
              photo: widget.photo,
              crop: crop,
              written: written,
            );
      } on Object catch (error) {
        if (mounted) {
          setState(() => _failure =
              'Exporté, mais non consigné dans la liste des exports : $error');
        }
      }
    }
  }

  /// Whether the pointer went down on a corner, and which.
  ///
  /// The hit area is larger than the drawn handle, per the design system: a
  /// crop is adjusted by feel, and demanding precise pointing to start a
  /// precise adjustment is the wrong way round.
  void _grab(DragStartDetails details) {
    final crop = ref.read(cropRectProvider);
    if (crop == null || _applied) return;
    const slop = ObscuraStrokes.handleHitSize * 2.5;
    final transform = _transformFor(crop.angleDegrees);

    _grabbed = null;
    for (final corner in CropCorner.values) {
      final at = transform.normalizedToScreen(corner.of(crop.rect));
      if ((at - details.localPosition).distance <= slop) {
        _grabbed = corner;
        break;
      }
    }
    setState(() {});
  }

  void _drag(DragUpdateDetails details) {
    final crop = ref.read(cropRectProvider);
    if (crop == null || _applied) return;
    final transform = _transformFor(crop.angleDegrees);
    final rect = transform.fittedRect;
    if (rect.width <= 0 || rect.height <= 0) return;

    final corner = _grabbed;
    if (corner != null) {
      ref.read(cropRectProvider.notifier).resize(
            corner,
            transform.screenToNormalized(details.localPosition),
            _frameAspect,
          );
      return;
    }

    ref.read(cropRectProvider.notifier).moveTo(
          Offset(
            crop.rect.left + details.delta.dx / rect.width,
            crop.rect.top + details.delta.dy / rect.height,
          ),
          _frameAspect,
        );
  }

  void _release(DragEndDetails details) => setState(() => _grabbed = null);

  @override
  Widget build(BuildContext context) {
    final crop = ref.watch(cropRectProvider);
    final obscura = ref.watch(obscuraProvider);

    return Shortcuts(
      shortcuts: shortcutMapFor(ShortcutScope.crop),
      child: Actions(
        actions: {
          SelectCropRatioIntent: CallbackAction<SelectCropRatioIntent>(
            onInvoke: (intent) {
              final ratio = CropRatio.forKeyIndex(intent.ratioIndex);
              if (ratio != null) {
                ref
                    .read(cropRectProvider.notifier)
                    .chooseRatio(ratio, _frameAspect);
              }
              return null;
            },
          ),
          ToggleCropOrientationIntent:
              CallbackAction<ToggleCropOrientationIntent>(
            onInvoke: (_) => ref.read(cropRectProvider.notifier).turn(_frameAspect),
          ),
          ExportCropIntent:
              CallbackAction<ExportCropIntent>(onInvoke: (_) => _export()),
          CloseViewerIntent: CallbackAction<CloseViewerIntent>(
            onInvoke: (_) => ref.read(cropModeProvider.notifier).leave(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _viewport = constraints.biggest;
                    final frame = _Frame(
                      photo: widget.photo,
                      obscura: obscura,
                      angleDegrees: crop?.angleDegrees ?? 0,
                      frameAspect: _frameAspect,
                      fitted: _transformFor(crop?.angleDegrees ?? 0).fittedRect,
                    );

                    return GestureDetector(
                      onPanStart: _grab,
                      onPanUpdate: _drag,
                      onPanEnd: _release,
                      child: _applied && crop != null
                          ? _Cropped(
                              key: const Key('crop-applied'),
                              rect: _transformFor(crop.angleDegrees)
                                  .screenRectOf(crop.rect),
                              viewport: _viewport,
                              child: frame,
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                frame,
                                if (crop != null)
                                  CustomPaint(
                                    painter: _CropOverlayPainter(
                                      crop: crop,
                                      transform:
                                          _transformFor(crop.angleDegrees),
                                      grabbed: _grabbed,
                                    ),
                                  ),
                              ],
                            ),
                    );
                  },
                ),
              ),
              _Controls(
                crop: crop,
                busy: _busy,
                applied: _applied,
                lastExport: _lastExport,
                failure: _failure,
                frameAspect: _frameAspect,
                pixelSize: _pixelSize(crop),
                onApply: () => setState(() => _applied = !_applied),
                onExport: _export,
                onClose: () => ref.read(cropModeProvider.notifier).leave(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The photograph, turned, laid out so its turned bounding box is [fitted].
///
/// [fitted] comes from the same [ViewTransform] the overlay and the hit-testing
/// use, which is the point: the picture, the rectangle drawn over it and the
/// pixels the export will cut all have to agree about where the frame is once
/// the horizon has been pulled off zero.
class _Frame extends ConsumerWidget {
  const _Frame({
    required this.photo,
    required this.obscura,
    required this.angleDegrees,
    required this.frameAspect,
    required this.fitted,
  });

  final PhotoEntity photo;
  final bool obscura;
  final double angleDegrees;
  final double frameAspect;
  final Rect fitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Display-sized on purpose: a 60 Mpx image inside a widget janks, and this
    // is the selection surface, not the export path.
    final image = ref.watch(
      fullPreviewProvider((photo: photo, targetWidth: 1600)),
    );

    // Turning a rectangle grows its bounding box, so the picture has to be
    // drawn smaller than the box it ends up occupying. Solving
    // `w·|cos| + h·|sin| = fitted.width` for the unrotated width is what keeps
    // the turned frame exactly inside the canvas the crop is measured against.
    final radians = angleDegrees * math.pi / 180;
    final spread =
        frameAspect * math.cos(radians).abs() + math.sin(radians).abs();
    // The unrotated height; the width is that times the frame's own aspect.
    final unit = spread <= 0 ? fitted.height : fitted.width / spread;

    return image.when(
      // The turn is a canvas transform on the screen and a real rotation only
      // at export. Rotating pixels to preview a one-degree correction would
      // cost a full re-encode per drag of the slider.
      data: (decoded) => Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fromRect(
            rect: fitted,
            child: Center(
              child: Transform.rotate(
                angle: radians,
                child: SizedBox(
                  width: unit * frameAspect,
                  height: unit,
                  child: OrientedImage(
                    key: const Key('crop-image'),
                    image: decoded,
                    orientation: DisplayOrientation.of(
                      photo.orientation,
                      obscura: obscura,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      error: (_, _) => const SizedBox.expand(),
      loading: () => const SizedBox.expand(),
    );
  }
}

/// The picture with the frame applied: only what was kept, filling the canvas.
///
/// A transform of the same widget the editing view draws rather than a second
/// rendering path — the pixels on screen are the ones the rectangle was
/// measured against, so what is shown here cannot disagree with what the export
/// will cut. It is still a preview: the file is written from the
/// full-resolution frame, not from this.
class _Cropped extends StatelessWidget {
  const _Cropped({
    super.key,
    required this.rect,
    required this.viewport,
    required this.child,
  });

  /// The crop, in the screen coordinates [child] is laid out in.
  final Rect rect;
  final Size viewport;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (rect.isEmpty || viewport.isEmpty) return child;
    final scale = math.min(
      viewport.width / rect.width,
      viewport.height / rect.height,
    );

    return ClipRect(
      child: Transform(
        transform: Matrix4.identity()
          ..translateByDouble(viewport.width / 2, viewport.height / 2, 0, 1)
          ..scaleByDouble(scale, scale, 1, 1)
          ..translateByDouble(-rect.center.dx, -rect.center.dy, 0, 1),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

/// Everything outside the crop, dimmed; the crop itself, outlined.
///
/// Dimmed rather than hidden: a photographer choosing a frame is choosing what
/// to leave out as much as what to keep, and hiding the rest would take away
/// the very comparison they are making.
class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({
    required this.crop,
    required this.transform,
    this.grabbed,
  });

  final CropRect crop;
  final ViewTransform transform;
  final CropCorner? grabbed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = transform.screenRectOf(crop.rect);

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = ObscuraColors.canvas.withValues(alpha: 0.66),
    );
    canvas.drawRect(rect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ObscuraStrokes.selection
        ..color = ObscuraColors.textPrimary,
    );

    // Thirds inside the crop: the one guide that belongs here rather than in
    // the layers panel, because it is about the frame being chosen.
    final thirds = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ObscuraStrokes.hairline
      ..color = ObscuraColors.textPrimary.withValues(alpha: 0.35);
    for (var i = 1; i < 3; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), thirds);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), thirds);
    }

    // Corner handles. Drawn small and grabbed large: the hit area in [_grab] is
    // several times this, because a crop is adjusted by feel.
    for (final corner in CropCorner.values) {
      final at = corner.of(rect);
      canvas.drawRect(
        Rect.fromCenter(center: at, width: 12, height: 12),
        Paint()
          ..color = corner == grabbed
              ? ObscuraColors.leicaRed
              : ObscuraColors.textPrimary,
      );
    }
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) =>
      old.crop != crop ||
      old.grabbed != grabbed ||
      old.transform.viewport != transform.viewport;
}

/// The ratio selector, built to feel like a switch on a camera body.
class _Controls extends ConsumerWidget {
  const _Controls({
    required this.crop,
    required this.busy,
    required this.applied,
    required this.lastExport,
    required this.failure,
    required this.frameAspect,
    required this.pixelSize,
    required this.onApply,
    required this.onExport,
    required this.onClose,
  });

  final CropRect? crop;
  final bool busy;
  final bool applied;
  final String? lastExport;
  final String? failure;
  final double frameAspect;

  /// What the export will be, in pixels of the full-resolution frame.
  final String? pixelSize;

  final VoidCallback onApply;
  final VoidCallback onExport;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ObscuraSpacing.overlayPadding),
      decoration: const BoxDecoration(
        color: ObscuraColors.elevated,
        border: Border(top: BorderSide(color: ObscuraColors.border)),
      ),
      // Three groups on one line while there is room for them, and stacked
      // when there is not. A single row cannot do that: the bar carries six
      // ratios, a slider and three buttons, and on a narrow window the flex
      // that gave way was whichever child happened to be last -- which is how
      // the export button ends up off the edge of the screen.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: ObscuraSpacing.overlayPadding,
        runSpacing: ObscuraSpacing.controlGap,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < CropRatio.values.length; i++)
                _RatioButton(
                  ratio: CropRatio.values[i],
                  index: i,
                  selected: crop?.ratio == CropRatio.values[i],
                  onPressed: () {
                    ref
                        .read(cropRectProvider.notifier)
                        .chooseRatio(CropRatio.values[i], frameAspect);
                    if (applied) onApply();
                  },
                ),
              const SizedBox(width: ObscuraSpacing.controlGap),
              _Straighten(
                degrees: crop?.angleDegrees ?? 0,
                onChanged: (value) {
                  ref
                      .read(cropRectProvider.notifier)
                      .straighten(value, frameAspect);
                  if (applied) onApply();
                },
              ),
              IconButton(
                key: const Key('crop-turn'),
                tooltip: 'Portrait / paysage (R)',
                // A square has no second orientation, so the control is
                // disabled rather than present and inert.
                onPressed: crop == null || !crop!.ratio.hasOrientations
                    ? null
                    : () {
                        ref.read(cropRectProvider.notifier).turn(frameAspect);
                        if (applied) onApply();
                      },
                icon: const Icon(Icons.screen_rotation_outlined, size: 18),
                color: ObscuraColors.textSecondary,
              ),
            ],
          ),
          if (crop != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  applied
                      ? 'Cadre appliqué · l\'export écrira cette image'
                      : 'Glissez le cadre · tirez un coin pour resserrer',
                  key: const Key('crop-hint'),
                  maxLines: 2,
                  style: ObscuraTypography.bodySmall
                      .copyWith(color: ObscuraColors.textSecondary),
                ),
                if (pixelSize != null) ...[
                  const SizedBox(width: ObscuraSpacing.overlayPadding),
                  // What the file will be, taken from the full-resolution
                  // frame. The one number that answers "is it really going to
                  // cut anything" before the button is pressed.
                  Text(
                    pixelSize!,
                    key: const Key('crop-size'),
                    style: ObscuraTypography.monoData
                        .copyWith(color: ObscuraColors.textPrimary),
                  ),
                ],
              ],
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (failure != null)
                Padding(
                  padding:
                      const EdgeInsets.only(right: ObscuraSpacing.controlGap),
                  child: Text(
                    failure!,
                    key: const Key('crop-failure'),
                    maxLines: 2,
                    style: ObscuraTypography.bodySmall
                        .copyWith(color: ObscuraColors.leicaRed),
                  ),
                )
              else if (lastExport != null)
                Padding(
                  padding:
                      const EdgeInsets.only(right: ObscuraSpacing.controlGap),
                  child: Text(
                    'Exporté : $lastExport',
                    key: const Key('crop-exported'),
                    maxLines: 2,
                    style: ObscuraTypography.monoData
                        .copyWith(color: ObscuraColors.textSecondary),
                  ),
                ),
              TextButton(onPressed: onClose, child: const Text('Fermer')),
              const SizedBox(width: ObscuraSpacing.controlGap),
              // The step the screen was missing. It changes nothing about what
              // gets written -- the rectangle was always what was cut -- and
              // everything about whether the photographer can see it first.
              FilledButton.icon(
                key: const Key('crop-apply'),
                onPressed: crop == null ? null : onApply,
                icon: Icon(
                  applied ? Icons.edit_outlined : Icons.crop_free,
                  size: 16,
                ),
                label: Text(applied ? 'Modifier' : 'Recadrer'),
              ),
              const SizedBox(width: ObscuraSpacing.controlGap),
              Tooltip(
                message: 'Exporter le recadrage (⌘E)',
                child: FilledButton.icon(
                  key: const Key('crop-export'),
                  onPressed: busy || crop == null ? null : onExport,
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: Text(busy ? 'Export…' : 'Exporter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The horizon slider.
///
/// Capped at fifteen degrees each way, and it says so: beyond that the usable
/// area collapses faster than the correction helps, and what the photographer
/// wanted was a different frame rather than a straighter one.
class _Straighten extends StatelessWidget {
  const _Straighten({required this.degrees, required this.onChanged});

  final double degrees;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.straighten, size: 16, color: ObscuraColors.textSecondary),
        SizedBox(
          width: 110,
          child: Slider(
            key: const Key('crop-straighten'),
            value: degrees.clamp(
              -CropRect.maxAngleDegrees,
              CropRect.maxAngleDegrees,
            ),
            min: -CropRect.maxAngleDegrees,
            max: CropRect.maxAngleDegrees,
            // A tenth of a degree: finer than that is beyond what the eye can
            // judge on a horizon, and coarser leaves it visibly off.
            divisions: (CropRect.maxAngleDegrees * 20).round(),
            activeColor: ObscuraColors.leicaRed,
            onChanged: onChanged,
          ),
        ),
        GestureDetector(
          key: const Key('crop-straighten-reset'),
          onTap: () => onChanged(0),
          child: SizedBox(
            width: 46,
            child: Text(
              '${degrees >= 0 ? '+' : ''}${degrees.toStringAsFixed(1)}°',
              style: ObscuraTypography.monoData.copyWith(
                color: degrees == 0
                    ? ObscuraColors.textSecondary
                    : ObscuraColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RatioButton extends StatelessWidget {
  const _RatioButton({
    required this.ratio,
    required this.index,
    required this.selected,
    required this.onPressed,
  });

  final CropRatio ratio;
  final int index;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ratio ${ratio.label}  (${index + 1})',
      child: GestureDetector(
        key: Key('ratio-${ratio.slug}'),
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            margin: const EdgeInsets.only(right: ObscuraSpacing.controlGap / 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? ObscuraColors.surfaceContainerHigh
                  : ObscuraColors.surfaceContainerLowest,
              border: Border.all(
                color: selected ? ObscuraColors.leicaRed : ObscuraColors.border,
              ),
              borderRadius: BorderRadius.circular(ObscuraRadii.base),
            ),
            child: Text(
              ratio.label,
              style: ObscuraTypography.monoData.copyWith(
                color: selected
                    ? ObscuraColors.textPrimary
                    : ObscuraColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
