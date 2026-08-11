import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/theme.dart';

/// Guards the design tokens against silent drift away from
/// `docs/reference/design-system.md`, which is the authority for visual style.
void main() {
  group('L-System palette', () {
    test('carries the exact brand and canvas values', () {
      // Leica Red is the one saturated colour in the app; getting it wrong
      // would misrepresent the brand on every delete badge.
      expect(ObscuraColors.leicaRed, const Color(0xFFE11B22));
      expect(ObscuraColors.statusDelete, const Color(0xFFE11B22));
      expect(ObscuraColors.statusExport, const Color(0xFF007AFF));

      // Deep charcoal, not pure black, so image blacks still read as black.
      expect(ObscuraColors.canvas, const Color(0xFF121212));
      expect(ObscuraColors.elevated, const Color(0xFF1E1E1E));
      expect(ObscuraColors.border, const Color(0xFF2C2C2C));

      expect(ObscuraColors.textPrimary, const Color(0xFFFFFFFF));
      expect(ObscuraColors.textSecondary, const Color(0xFFA1A1A1));
    });

    test('keeps the focus ring distinct from the selection colour', () {
      // A keyboard-driven app must not signal "this control has focus" and
      // "this photo is selected" with the same colour.
      expect(ObscuraColors.focusRing, isNot(ObscuraColors.leicaRed));
    });

    test('defaults composition-guide strokes to a translucent neutral', () {
      // Guides sit on top of photographs; a fully opaque or tinted default
      // would fight the image it is meant to describe.
      expect(ObscuraColors.layerStrokeDefault.a, closeTo(0.6, 0.01));
    });
  });

  group('layout tokens', () {
    test('match the design system', () {
      expect(ObscuraSpacing.gridGutter, 12.0);
      expect(ObscuraSpacing.sidebarWidth, 260.0);
      expect(ObscuraSpacing.viewerMargin, 40.0);
      expect(ObscuraSpacing.controlGap, 8.0);
      expect(ObscuraSpacing.overlayPadding, 16.0);
      expect(ObscuraRadii.base, 4.0);
    });
  });

  group('type scale', () {
    test('uses the small desktop sizes that keep room for the image', () {
      expect(ObscuraTypography.bodyMedium.fontSize, 13);
      expect(ObscuraTypography.bodySmall.fontSize, 11);
      expect(ObscuraTypography.headlineLarge.fontSize, 24);
      expect(ObscuraTypography.headlineMedium.fontSize, 18);
    });

    test('tracks metadata labels wider for scanning', () {
      expect(ObscuraTypography.metadataLabel.fontSize, 10);
      expect(ObscuraTypography.metadataLabel.fontWeight, FontWeight.w700);
      expect(ObscuraTypography.metadataLabel.letterSpacing, closeTo(0.5, 0.001));
    });

    test('aligns EXIF figures in columns', () {
      // Shutter/aperture/ISO are read down a column across photographs;
      // proportional digits would make them jitter.
      expect(
        ObscuraTypography.monoData.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });

  group('theme', () {
    test('is dark with the charcoal canvas behind every surface', () {
      final theme = buildObscuraTheme();
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, ObscuraColors.canvas);
      expect(theme.canvasColor, ObscuraColors.canvas);
    });

    test('separates surfaces with a hairline border instead of a shadow', () {
      final theme = buildObscuraTheme();
      expect(theme.dividerTheme.color, ObscuraColors.border);
      expect(theme.dividerTheme.thickness, 1.0);
    });
  });
}
