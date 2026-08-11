import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../catalog/photo_entity.dart';

/// Whether the viewer states the exposure over the photograph.
///
/// Global and sticky by design: a photographer who has asked to see shutter and
/// aperture wants them on the next frame too, and one who has hidden them is
/// looking at pictures. Re-deciding per photograph would make the overlay
/// flicker through a session.
///
/// The spec's keyboard table (section 5) assigns no key to this, so it is a
/// visible control rather than an invented binding.
class ExifOverlayNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final exifOverlayVisibleProvider =
    NotifierProvider<ExifOverlayNotifier, bool>(ExifOverlayNotifier.new);

/// What the camera was set to, stated over the frame.
///
/// Inset by the design system's viewer margin so it never sits on a corner of
/// the photograph, and laid out as label-over-value pairs with wide tracking on
/// the labels: these are numbers to be scanned across frames, not read.
class ExifOverlay extends StatelessWidget {
  const ExifOverlay({super.key, required this.photo});

  final PhotoEntity photo;

  @override
  Widget build(BuildContext context) {
    final settings = photo.settings;
    final fields = <(String, String)>[
      ('Focale', settings.focalLabel ?? '—'),
      ('Vitesse', settings.shutterLabel ?? '—'),
      ('Ouverture', settings.apertureLabel ?? '—'),
      ('ISO', settings.iso?.toString() ?? '—'),
    ];

    return Padding(
      padding: const EdgeInsets.all(ObscuraSpacing.viewerMargin),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          key: const Key('exif-overlay'),
          padding: const EdgeInsets.symmetric(
            horizontal: ObscuraSpacing.overlayPadding,
            vertical: ObscuraSpacing.controlGap * 1.5,
          ),
          decoration: BoxDecoration(
            // Opaque enough to be legible over a white sky as well as a dark
            // interior: an overlay only readable over half the photographs is
            // not an overlay.
            color: ObscuraColors.canvas.withValues(alpha: 0.86),
            border: Border.all(color: ObscuraColors.border),
            borderRadius: BorderRadius.circular(ObscuraRadii.base),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                photo.radical,
                key: const Key('exif-radical'),
                style: ObscuraTypography.bodyMedium,
              ),
              if (settings.model != null)
                Text(
                  settings.model!,
                  style: ObscuraTypography.bodySmall
                      .copyWith(color: ObscuraColors.textSecondary),
                ),
              const SizedBox(height: ObscuraSpacing.controlGap * 1.5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (label, value) in fields)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: ObscuraSpacing.overlayPadding * 1.5,
                      ),
                      child: _Field(label: label, value: value),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: ObscuraTypography.metadataLabel
              .copyWith(color: ObscuraColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(value, style: ObscuraTypography.monoData),
      ],
    );
  }
}
