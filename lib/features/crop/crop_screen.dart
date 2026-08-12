import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shortcuts.dart';
import '../../app/theme.dart';
import '../../infra/geometry/view_transform.dart';
import '../catalog/photo_entity.dart';
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

  void moveTo(Offset topLeft) {
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
    ).clampedToFrame();
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

  /// The corner being dragged, or null while the whole rectangle is moving.
  CropCorner? _grabbed;

  double get _frameAspect {
    final stream = widget.photo.viewerPreview ?? widget.photo.gridPreview;
    final width = (stream?.width ?? 3).toDouble();
    final height = (stream?.height ?? 2).toDouble();
    if (width <= 0 || height <= 0) return 3 / 2;
    return widget.photo.isPortrait ? height / width : width / height;
  }

  ViewTransform get _transform => ViewTransform(
        imageSize: Size(_frameAspect * 1000, 1000),
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

    final folder = await ref.read(exportFolderProvider.future);
    final outcome = await const ExportService().export(
      photo: widget.photo,
      crop: crop,
      folder: folder,
    );
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
  }

  /// Whether the pointer went down on a corner, and which.
  ///
  /// The hit area is larger than the drawn handle, per the design system: a
  /// crop is adjusted by feel, and demanding precise pointing to start a
  /// precise adjustment is the wrong way round.
  void _grab(DragStartDetails details) {
    final crop = ref.read(cropRectProvider);
    if (crop == null) return;
    const slop = ObscuraStrokes.handleHitSize * 2.5;

    _grabbed = null;
    for (final corner in CropCorner.values) {
      final at = _transform.normalizedToScreen(corner.of(crop.rect));
      if ((at - details.localPosition).distance <= slop) {
        _grabbed = corner;
        break;
      }
    }
    setState(() {});
  }

  void _drag(DragUpdateDetails details) {
    final crop = ref.read(cropRectProvider);
    if (crop == null) return;
    final rect = _transform.fittedRect;
    if (rect.width <= 0 || rect.height <= 0) return;

    final corner = _grabbed;
    if (corner != null) {
      ref.read(cropRectProvider.notifier).resize(
            corner,
            _transform.screenToNormalized(details.localPosition),
            _frameAspect,
          );
      return;
    }

    ref.read(cropRectProvider.notifier).moveTo(
          Offset(
            crop.rect.left + details.delta.dx / rect.width,
            crop.rect.top + details.delta.dy / rect.height,
          ),
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
                    return GestureDetector(
                      onPanStart: _grab,
                      onPanUpdate: _drag,
                      onPanEnd: _release,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _Frame(
                            photo: widget.photo,
                            obscura: obscura,
                            angleDegrees: crop?.angleDegrees ?? 0,
                          ),
                          if (crop != null)
                            CustomPaint(
                              painter: _CropOverlayPainter(
                                crop: crop,
                                transform: _transform,
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
                lastExport: _lastExport,
                failure: _failure,
                frameAspect: _frameAspect,
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

class _Frame extends ConsumerWidget {
  const _Frame({
    required this.photo,
    required this.obscura,
    required this.angleDegrees,
  });

  final PhotoEntity photo;
  final bool obscura;
  final double angleDegrees;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Display-sized on purpose: a 60 Mpx image inside a widget janks, and this
    // is the selection surface, not the export path.
    final image = ref.watch(
      fullPreviewProvider((photo: photo, targetWidth: 1600)),
    );

    return image.when(
      // The turn is a canvas transform on the screen and a real rotation only
      // at export. Rotating pixels to preview a one-degree correction would
      // cost a full re-encode per drag of the slider.
      data: (decoded) => Transform.rotate(
        angle: angleDegrees * math.pi / 180,
        child: OrientedImage(
          key: const Key('crop-image'),
          image: decoded,
          orientation:
              DisplayOrientation.of(photo.orientation, obscura: obscura),
        ),
      ),
      error: (_, _) => const SizedBox.expand(),
      loading: () => const SizedBox.expand(),
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
    required this.lastExport,
    required this.failure,
    required this.frameAspect,
    required this.onExport,
    required this.onClose,
  });

  final CropRect? crop;
  final bool busy;
  final String? lastExport;
  final String? failure;
  final double frameAspect;
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
      child: Row(
        children: [
          for (var i = 0; i < CropRatio.values.length; i++)
            _RatioButton(
              ratio: CropRatio.values[i],
              index: i,
              selected: crop?.ratio == CropRatio.values[i],
              onPressed: () => ref
                  .read(cropRectProvider.notifier)
                  .chooseRatio(CropRatio.values[i], frameAspect),
            ),
          const SizedBox(width: ObscuraSpacing.overlayPadding),
          _Straighten(
            degrees: crop?.angleDegrees ?? 0,
            onChanged: (value) => ref
                .read(cropRectProvider.notifier)
                .straighten(value, frameAspect),
          ),
          const SizedBox(width: ObscuraSpacing.overlayPadding),
          IconButton(
            key: const Key('crop-turn'),
            tooltip: 'Portrait / paysage (R)',
            // A square has no second orientation, so the control is disabled
            // rather than present and inert.
            onPressed: crop == null || !crop!.ratio.hasOrientations
                ? null
                : () => ref.read(cropRectProvider.notifier).turn(frameAspect),
            icon: const Icon(Icons.screen_rotation_outlined, size: 18),
            color: ObscuraColors.textSecondary,
          ),
          const Spacer(),
          if (crop != null)
            Padding(
              padding: const EdgeInsets.only(right: ObscuraSpacing.overlayPadding),
              child: Text(
                'Glissez le cadre · tirez un coin pour resserrer',
                style: ObscuraTypography.bodySmall
                    .copyWith(color: ObscuraColors.textSecondary),
              ),
            ),
          if (failure != null)
            Padding(
              padding: const EdgeInsets.only(right: ObscuraSpacing.overlayPadding),
              child: Text(
                failure!,
                key: const Key('crop-failure'),
                style: ObscuraTypography.bodySmall
                    .copyWith(color: ObscuraColors.leicaRed),
              ),
            )
          else if (lastExport != null)
            Padding(
              padding: const EdgeInsets.only(right: ObscuraSpacing.overlayPadding),
              child: Text(
                'Exporté : $lastExport',
                key: const Key('crop-exported'),
                style: ObscuraTypography.monoData
                    .copyWith(color: ObscuraColors.textSecondary),
              ),
            ),
          TextButton(onPressed: onClose, child: const Text('Fermer')),
          const SizedBox(width: ObscuraSpacing.controlGap),
          FilledButton.icon(
            key: const Key('crop-export'),
            onPressed: busy || crop == null ? null : onExport,
            icon: const Icon(Icons.ios_share, size: 16),
            label: Text(busy ? 'Export…' : 'Exporter (⌘E)'),
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
          width: 150,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
