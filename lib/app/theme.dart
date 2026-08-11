import 'package:flutter/material.dart';

/// Design tokens for the "L-System" design system.
///
/// Values are transcribed from `docs/reference/design-system.md`, which is the
/// authority for visual style. The palette is dark-only by design: culling and
/// composition judgements must not be biased by a light chrome around the image.
abstract final class ObscuraColors {
  // Interface surfaces -- the "Control Plane".
  /// Primary canvas behind images. Deep charcoal rather than pure black, so
  /// image blacks still read as black against it.
  static const canvas = Color(0xFF121212);
  static const elevated = Color(0xFF1E1E1E);

  /// Surfaces are separated by a 1px border rather than a shadow, keeping the
  /// chrome flat and technical.
  static const border = Color(0xFF2C2C2C);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA1A1A1);

  /// Reserved for high-priority status and brand touchpoints only -- never for
  /// large surfaces.
  static const leicaRed = Color(0xFFE11B22);
  static const statusDelete = Color(0xFFE11B22);
  static const statusExport = Color(0xFF007AFF);

  // Material color-role surfaces.
  static const surface = Color(0xFF131313);
  static const surfaceDim = Color(0xFF131313);
  static const surfaceBright = Color(0xFF393939);
  static const surfaceContainerLowest = Color(0xFF0E0E0E);
  static const surfaceContainerLow = Color(0xFF1B1B1C);
  static const surfaceContainer = Color(0xFF202020);
  static const surfaceContainerHigh = Color(0xFF2A2A2A);
  static const surfaceContainerHighest = Color(0xFF353535);
  static const surfaceVariant = Color(0xFF353535);

  static const onSurface = Color(0xFFE5E2E1);
  static const onSurfaceVariant = Color(0xFFE7BDB8);
  static const inverseSurface = Color(0xFFE5E2E1);
  static const inverseOnSurface = Color(0xFF303030);

  static const outline = Color(0xFFAE8883);
  static const outlineVariant = Color(0xFF5D3F3C);

  static const primary = Color(0xFFFFB4AB);
  static const onPrimary = Color(0xFF690006);
  static const primaryContainer = Color(0xFFE11B22);
  static const onPrimaryContainer = Color(0xFFFFF7F6);
  static const inversePrimary = Color(0xFFC00014);

  static const secondary = Color(0xFFC8C6C5);
  static const onSecondary = Color(0xFF313030);
  static const secondaryContainer = Color(0xFF4A4949);
  static const onSecondaryContainer = Color(0xFFBAB8B7);

  static const tertiary = Color(0xFF95CCFF);
  static const onTertiary = Color(0xFF003352);
  static const tertiaryContainer = Color(0xFF0078B9);
  static const onTertiaryContainer = Color(0xFFF7F9FF);

  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);

  /// Default stroke for composition-layer vector guides. User-selectable at
  /// runtime; this neutral light gray at 60% keeps guides visible over most
  /// photographs without competing with the image.
  static const layerStrokeDefault = Color(0x99D8D8D8);

  /// Ring drawn on the keyboard-focused control.
  ///
  /// Deliberately distinct from [leicaRed], which marks the *selected* grid
  /// cell: in a keyboard-driven app the focused control and the selected photo
  /// are different things and must not share one visual signal.
  static const focusRing = Color(0xFF95CCFF);
}

/// Layout constants. Composition guides use normalized 0..1 geometry instead
/// and therefore have no entry here.
abstract final class ObscuraSpacing {
  static const gridGutter = 12.0;
  static const sidebarWidth = 260.0;

  /// Inset for viewer overlays, so EXIF and tool chrome never occlude the
  /// corners of the photograph.
  static const viewerMargin = 40.0;
  static const controlGap = 8.0;
  static const overlayPadding = 16.0;
}

abstract final class ObscuraRadii {
  static const sm = 2.0;
  static const base = 4.0;
  static const md = 6.0;
  static const lg = 8.0;
  static const xl = 12.0;
  static const full = 9999.0;
}

abstract final class ObscuraStrokes {
  static const hairline = 1.0;
  static const selection = 2.0;
  static const focus = 2.0;

  /// Side of the square hit target on crop and layer handles. Larger than the
  /// drawn handle so precise dragging does not demand precise pointing.
  static const handleHitSize = 8.0;
}

/// Type scale.
///
/// The design system specifies Inter for its neutrality and its resemblance to
/// Leica's own engraved lettering. The font asset is not bundled yet, so these
/// styles name the family and fall back to the macOS system font until it is;
/// sizes, weights, and letter-spacing are already final.
abstract final class ObscuraTypography {
  static const fontFamily = 'Inter';
  static const fontFamilyFallback = <String>['.AppleSystemUIFont', 'Helvetica Neue'];

  static const headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
    letterSpacing: -0.02 * 24,
  );

  static const headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    letterSpacing: -0.01 * 18,
  );

  static const bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
  );

  static const bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 14 / 11,
  );

  /// EXIF field labels. Uppercase with wide tracking so values can be scanned
  /// rather than read.
  static const metadataLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 12 / 10,
    letterSpacing: 0.05 * 10,
  );

  /// Shutter speed, aperture, ISO. Tabular figures keep columns of numbers
  /// aligned between photographs.
  static const monoData = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

ThemeData buildObscuraTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: ObscuraColors.primary,
    onPrimary: ObscuraColors.onPrimary,
    primaryContainer: ObscuraColors.primaryContainer,
    onPrimaryContainer: ObscuraColors.onPrimaryContainer,
    inversePrimary: ObscuraColors.inversePrimary,
    secondary: ObscuraColors.secondary,
    onSecondary: ObscuraColors.onSecondary,
    secondaryContainer: ObscuraColors.secondaryContainer,
    onSecondaryContainer: ObscuraColors.onSecondaryContainer,
    tertiary: ObscuraColors.tertiary,
    onTertiary: ObscuraColors.onTertiary,
    tertiaryContainer: ObscuraColors.tertiaryContainer,
    onTertiaryContainer: ObscuraColors.onTertiaryContainer,
    error: ObscuraColors.error,
    onError: ObscuraColors.onError,
    errorContainer: ObscuraColors.errorContainer,
    onErrorContainer: ObscuraColors.onErrorContainer,
    surface: ObscuraColors.surface,
    onSurface: ObscuraColors.onSurface,
    surfaceDim: ObscuraColors.surfaceDim,
    surfaceBright: ObscuraColors.surfaceBright,
    surfaceContainerLowest: ObscuraColors.surfaceContainerLowest,
    surfaceContainerLow: ObscuraColors.surfaceContainerLow,
    surfaceContainer: ObscuraColors.surfaceContainer,
    surfaceContainerHigh: ObscuraColors.surfaceContainerHigh,
    surfaceContainerHighest: ObscuraColors.surfaceContainerHighest,
    onSurfaceVariant: ObscuraColors.onSurfaceVariant,
    outline: ObscuraColors.outline,
    outlineVariant: ObscuraColors.outlineVariant,
    inverseSurface: ObscuraColors.inverseSurface,
    onInverseSurface: ObscuraColors.inverseOnSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: ObscuraColors.canvas,
    canvasColor: ObscuraColors.canvas,
    dividerColor: ObscuraColors.border,
    fontFamily: ObscuraTypography.fontFamily,
    fontFamilyFallback: ObscuraTypography.fontFamilyFallback,
    textTheme: const TextTheme(
      headlineLarge: ObscuraTypography.headlineLarge,
      headlineMedium: ObscuraTypography.headlineMedium,
      bodyMedium: ObscuraTypography.bodyMedium,
      bodySmall: ObscuraTypography.bodySmall,
      labelSmall: ObscuraTypography.metadataLabel,
    ),
    dividerTheme: const DividerThemeData(
      color: ObscuraColors.border,
      thickness: ObscuraStrokes.hairline,
      space: ObscuraStrokes.hairline,
    ),
    cardTheme: CardThemeData(
      color: ObscuraColors.elevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ObscuraRadii.base),
        side: const BorderSide(color: ObscuraColors.border),
      ),
    ),
  );
}
