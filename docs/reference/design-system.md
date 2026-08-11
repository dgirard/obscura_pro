---
name: L-System
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#393939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1b1b1c'
  surface-container: '#202020'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353535'
  on-surface: '#e5e2e1'
  on-surface-variant: '#e7bdb8'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#303030'
  outline: '#ae8883'
  outline-variant: '#5d3f3c'
  surface-tint: '#ffb4ab'
  primary: '#ffb4ab'
  on-primary: '#690006'
  primary-container: '#e11b22'
  on-primary-container: '#fff7f6'
  inverse-primary: '#c00014'
  secondary: '#c8c6c5'
  on-secondary: '#313030'
  secondary-container: '#4a4949'
  on-secondary-container: '#bab8b7'
  tertiary: '#95ccff'
  on-tertiary: '#003352'
  tertiary-container: '#0078b9'
  on-tertiary-container: '#f7f9ff'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdad6'
  primary-fixed-dim: '#ffb4ab'
  on-primary-fixed: '#410002'
  on-primary-fixed-variant: '#93000d'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1c1b1b'
  on-secondary-fixed-variant: '#474646'
  tertiary-fixed: '#cde5ff'
  tertiary-fixed-dim: '#95ccff'
  on-tertiary-fixed: '#001d32'
  on-tertiary-fixed-variant: '#004a75'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353535'
  interface-surface: '#121212'
  interface-elevated: '#1E1E1E'
  interface-border: '#2C2C2C'
  text-primary: '#FFFFFF'
  text-secondary: '#A1A1A1'
  leica-red: '#E11B22'
  status-delete: '#E11B22'
  status-export: '#007AFF'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-md:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  body-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 14px
  metadata-label:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 12px
    letterSpacing: 0.05em
  mono-data:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  grid-gutter: 12px
  sidebar-width: 260px
  viewer-margin: 40px
  control-gap: 8px
  overlay-padding: 16px
---

## Brand & Style

The design system is a high-precision utility for professional photographers, specifically optimized for the Leica Q3 workflow. It prioritizes the image above all else, adopting a **"Technical Minimalist"** style that blends macOS native patterns with the mechanical precision of German optics.

The personality is disciplined, quiet, and reliable. It avoids decorative flourishes to prevent visual interference with color grading and composition analysis. The emotional response should be one of "invisible efficiency"—the UI disappears when not needed, echoing the tactile and focused experience of using a rangefinder camera.

Key aesthetic drivers:
- **Utilitarian Professionalism:** High-density information with clear hierarchy.
- **macOS Native Integration:** Leveraging translucency (Vibrancy) and system-standard behaviors for a seamless desktop experience.
- **Technical Accuracy:** Grid systems and composition overlays derived from optical physics and classic framing rules.

## Colors

The palette is strictly dark-mode to ensure color-accurate culling and reduced eye strain during long sessions. 

- **Primary Canvas:** The background uses a deep charcoal (#121212) to provide maximum contrast for images without the harshness of pure black.
- **Accents:** "Leica Red" (#E11B22) is used sparingly. It is reserved for high-priority status indicators (like "Marked for Deletion") and critical brand touchpoints. It should never be used for large surfaces.
- **Neutral Grays:** Used for borders, secondary text, and UI controls to maintain a monochromatic environment that doesn't bias the photographer's perception of color in their photos.
- **Translucency:** macOS "Vibrancy" (Materials) should be applied to sidebars and tool overlays to provide a sense of depth and context.

## Typography

This design system uses **Inter** (a Swiss-inspired sans-serif) to mimic the legibility and neutrality of Leica’s own engravings and documentation.

- **Legibility:** Technical data (ISO, Shutter Speed, Aperture) uses `mono-data` weighting to ensure numbers remain clear and aligned.
- **Metadata Labels:** Always uppercase with increased letter-spacing for quick scanning of EXIF values.
- **Scale:** Small font sizes (11px-13px) are preferred to maximize screen real estate for the image grid, adhering to macOS desktop standards.

## Layout & Spacing

The layout is divided into a fixed-width sidebar for metadata and a fluid canvas for image culling.

- **Image Grid:** A 12px gutter is standard between thumbnails. Thumbnails should scale fluidly to fill the width of the container while maintaining aspect ratios.
- **Viewer Overlays:** EXIF data and tool overlays should be inset from the image edge by `viewer-margin` to prevent occlusion of critical corner details in the photograph.
- **Normalized Geometry:** For composition guides (Rule of Thirds, etc.), all coordinates are calculated on a 0.0 to 1.0 scale, ensuring guides remain accurate regardless of display resolution or window resizing.

## Elevation & Depth

Depth is used functionally to separate the "Image Plane" from the "Control Plane."

- **The Canvas:** The lowest layer, containing the image itself.
- **The Glass Layer:** Tool palettes and viewer overlays use a "Thin Dark" macOS material with a 20px background blur. This allows the photographer to see the colors of the image through the UI without losing legibility.
- **Low-Contrast Outlines:** Instead of shadows, surfaces are defined by a 1px solid border (#2C2C2C). This maintains a flat, technical aesthetic that feels integrated into the macOS environment.

## Shapes

The shape language is "Soft" (0.25rem / 4px) to balance the clinical nature of the app with the modern macOS aesthetic.

- **Thumbnails:** Use a 4px corner radius to distinguish individual frames in a dense grid.
- **Interactive Elements:** Buttons and input fields use the same 4px radius.
- **Active Selection:** A 2px solid stroke in the system accent color or Leica Red is used to indicate the selected image, following the outer boundary of the thumbnail.

## Components

### Buttons & Toggles
- **Action Buttons:** Subtle dark gray backgrounds that brighten on hover. No gradients.
- **Segmented Controls:** Used for aspect ratio selection (3:2, 1:1, etc.). These should feel like physical switches on a camera body.

### Photo Grid
- **Badges:** Small, high-contrast labels in the corner of thumbnails. "RAW+JPG" in white-on-gray; "Trash" icons in Leica Red.
- **Loading State:** Use the `fast_thumbhash` average color as a solid fill while the high-res JPEG preview is decoding to minimize visual jarring.

### Viewer Overlays
- **Composition Layers:** Vector paths (Rule of Thirds, Golden Spiral) rendered with a 1px stroke. The stroke color should be user-selectable (defaulting to a neutral light gray with 60% opacity) to ensure visibility against various photo backgrounds.
- **Crop Tool:** A high-contrast boundary with 8px "hit-area" handles at corners and midpoints for precise dragging.

### Input Fields
- **Search/Filter:** Minimalist, using the macOS "Search" field style. 
- **Metadata Fields:** Read-only fields should appear flush with the sidebar background, becoming interactive only when an "Edit" state is triggered.