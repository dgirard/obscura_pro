import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keyboard catalogue for the whole app, transcribed from the keyboard table in
/// `docs/reference/spec-q3-culling.md` (section 5).
///
/// Culling is a keyboard-driven activity: the photographer's hand should not
/// leave the arrow keys during a session. Every binding lives in this one file
/// so the full map can be reviewed -- and tested for collisions -- in one place
/// rather than being scattered across the screens that happen to use it.
///
/// Built on Flutter's own `Shortcuts`/`Actions`/`Intent` widgets; no plugin is
/// involved.

// --- Navigation -------------------------------------------------------------

class PreviousPhotoIntent extends Intent {
  const PreviousPhotoIntent();
}

class NextPhotoIntent extends Intent {
  const NextPhotoIntent();
}

class PreviousRowIntent extends Intent {
  const PreviousRowIntent();
}

class NextRowIntent extends Intent {
  const NextRowIntent();
}

class OpenViewerIntent extends Intent {
  const OpenViewerIntent();
}

class CloseViewerIntent extends Intent {
  const CloseViewerIntent();
}

// --- Review -----------------------------------------------------------------

class ToggleObscuraIntent extends Intent {
  const ToggleObscuraIntent();
}

class ToggleLayersPanelIntent extends Intent {
  const ToggleLayersPanelIntent();
}

class ZoomInIntent extends Intent {
  const ZoomInIntent();
}

class ZoomOutIntent extends Intent {
  const ZoomOutIntent();
}

class ZoomResetIntent extends Intent {
  const ZoomResetIntent();
}

// --- Deletion ---------------------------------------------------------------

/// Marks the photo for deletion, or unmarks it when it is already marked.
///
/// Marking writes nothing to the card -- it is recorded on the Mac and only
/// acted on when the trash is emptied.
class ToggleMarkForDeletionIntent extends Intent {
  const ToggleMarkForDeletionIntent();
}

/// The only irreversible action in the app.
class EmptyTrashIntent extends Intent {
  const EmptyTrashIntent();
}

// --- Crop -------------------------------------------------------------------

class EnterCropModeIntent extends Intent {
  const EnterCropModeIntent();
}

/// Selects one of the six permitted aspect ratios. Free-form ratios are not
/// reachable by design.
class SelectCropRatioIntent extends Intent {
  const SelectCropRatioIntent(this.ratioIndex);

  /// Zero-based index into the permitted ratio list (3:2, 4:3, 5:4, 1:1, 16:9,
  /// 65:24), bound to the `1`..`6` keys in that order.
  final int ratioIndex;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'SelectCropRatioIntent(ratioIndex: $ratioIndex)';
}

class ToggleCropOrientationIntent extends Intent {
  const ToggleCropOrientationIntent();
}

class ExportCropIntent extends Intent {
  const ExportCropIntent();
}

// --- Session ----------------------------------------------------------------

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class EjectCardIntent extends Intent {
  const EjectCardIntent();
}

/// Where a binding is active.
///
/// The same key legitimately means different things in different places --
/// Enter opens a photo from the grid and returns to the grid from the viewer --
/// so a binding is only ever ambiguous *within* one scope.
enum ShortcutScope {
  /// Active everywhere. Collides with every other scope.
  global,
  grid,
  viewer,
  crop,
  layers,
}

/// One row of the keyboard table.
@immutable
class ShortcutBinding {
  const ShortcutBinding({
    required this.scope,
    required this.activator,
    required this.intent,
    required this.description,
  });

  final ShortcutScope scope;
  final SingleActivator activator;
  final Intent intent;

  /// Human-readable action, for the future keyboard-reference sheet.
  final String description;

  /// Identity of the key combination, independent of which intent it triggers.
  /// Two bindings sharing this signature in overlapping scopes are a conflict.
  ({LogicalKeyboardKey key, bool meta, bool shift, bool alt, bool control})
      get signature => (
            key: activator.trigger,
            meta: activator.meta,
            shift: activator.shift,
            alt: activator.alt,
            control: activator.control,
          );
}

/// The canonical keyboard map.
const List<ShortcutBinding> obscuraShortcutBindings = <ShortcutBinding>[
  // Session-wide.
  ShortcutBinding(
    scope: ShortcutScope.global,
    activator: SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
    intent: UndoIntent(),
    description: 'Undo',
  ),
  ShortcutBinding(
    scope: ShortcutScope.global,
    activator: SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
    intent: RedoIntent(),
    description: 'Redo',
  ),
  ShortcutBinding(
    scope: ShortcutScope.global,
    activator: SingleActivator(LogicalKeyboardKey.eject, meta: true),
    intent: EjectCardIntent(),
    description: 'Eject the card safely',
  ),
  ShortcutBinding(
    scope: ShortcutScope.global,
    activator: SingleActivator(LogicalKeyboardKey.backspace, meta: true),
    intent: EmptyTrashIntent(),
    description: 'Empty the trash (permanent)',
  ),
  ShortcutBinding(
    scope: ShortcutScope.global,
    activator: SingleActivator(LogicalKeyboardKey.backspace),
    intent: ToggleMarkForDeletionIntent(),
    description: 'Mark or unmark for deletion',
  ),

  // Grid.
  ShortcutBinding(
    scope: ShortcutScope.grid,
    activator: SingleActivator(LogicalKeyboardKey.arrowLeft),
    intent: PreviousPhotoIntent(),
    description: 'Previous photo',
  ),
  ShortcutBinding(
    scope: ShortcutScope.grid,
    activator: SingleActivator(LogicalKeyboardKey.arrowRight),
    intent: NextPhotoIntent(),
    description: 'Next photo',
  ),
  ShortcutBinding(
    scope: ShortcutScope.grid,
    activator: SingleActivator(LogicalKeyboardKey.arrowUp),
    intent: PreviousRowIntent(),
    description: 'Previous row',
  ),
  ShortcutBinding(
    scope: ShortcutScope.grid,
    activator: SingleActivator(LogicalKeyboardKey.arrowDown),
    intent: NextRowIntent(),
    description: 'Next row',
  ),
  ShortcutBinding(
    scope: ShortcutScope.grid,
    activator: SingleActivator(LogicalKeyboardKey.enter),
    intent: OpenViewerIntent(),
    description: 'Open the photo full-frame',
  ),
  ShortcutBinding(
    scope: ShortcutScope.grid,
    activator: SingleActivator(LogicalKeyboardKey.space),
    intent: OpenViewerIntent(),
    description: 'Open the photo full-frame',
  ),

  // Viewer.
  ShortcutBinding(
    scope: ShortcutScope.viewer,
    activator: SingleActivator(LogicalKeyboardKey.arrowLeft),
    intent: PreviousPhotoIntent(),
    description: 'Previous photo',
  ),
  ShortcutBinding(
    scope: ShortcutScope.viewer,
    activator: SingleActivator(LogicalKeyboardKey.arrowRight),
    intent: NextPhotoIntent(),
    description: 'Next photo',
  ),
  ShortcutBinding(
    scope: ShortcutScope.viewer,
    activator: SingleActivator(LogicalKeyboardKey.enter),
    intent: CloseViewerIntent(),
    description: 'Back to the grid',
  ),
  ShortcutBinding(
    scope: ShortcutScope.viewer,
    activator: SingleActivator(LogicalKeyboardKey.space),
    intent: CloseViewerIntent(),
    description: 'Back to the grid',
  ),
  ShortcutBinding(
    scope: ShortcutScope.viewer,
    activator: SingleActivator(LogicalKeyboardKey.keyO),
    intent: ToggleObscuraIntent(),
    description: 'Toggle obscura view (rotate 180 degrees)',
  ),
  ShortcutBinding(
    scope: ShortcutScope.viewer,
    activator: SingleActivator(LogicalKeyboardKey.keyL),
    intent: ToggleLayersPanelIntent(),
    description: 'Show or hide the composition layers panel',
  ),
  ShortcutBinding(
    scope: ShortcutScope.viewer,
    activator: SingleActivator(LogicalKeyboardKey.keyC),
    intent: EnterCropModeIntent(),
    description: 'Enter crop mode',
  ),
  ShortcutBinding(
    scope: ShortcutScope.viewer,
    activator: SingleActivator(LogicalKeyboardKey.equal, meta: true),
    intent: ZoomInIntent(),
    description: 'Zoom in',
  ),
  ShortcutBinding(
    scope: ShortcutScope.viewer,
    activator: SingleActivator(LogicalKeyboardKey.minus, meta: true),
    intent: ZoomOutIntent(),
    description: 'Zoom out',
  ),
  ShortcutBinding(
    scope: ShortcutScope.viewer,
    activator: SingleActivator(LogicalKeyboardKey.digit0, meta: true),
    intent: ZoomResetIntent(),
    description: 'Fit the photo to the window',
  ),

  // Crop mode. The six ratio keys follow the order the ratio selector shows.
  ShortcutBinding(
    scope: ShortcutScope.crop,
    activator: SingleActivator(LogicalKeyboardKey.digit1),
    intent: SelectCropRatioIntent(0),
    description: 'Ratio 3:2',
  ),
  ShortcutBinding(
    scope: ShortcutScope.crop,
    activator: SingleActivator(LogicalKeyboardKey.digit2),
    intent: SelectCropRatioIntent(1),
    description: 'Ratio 4:3',
  ),
  ShortcutBinding(
    scope: ShortcutScope.crop,
    activator: SingleActivator(LogicalKeyboardKey.digit3),
    intent: SelectCropRatioIntent(2),
    description: 'Ratio 5:4',
  ),
  ShortcutBinding(
    scope: ShortcutScope.crop,
    activator: SingleActivator(LogicalKeyboardKey.digit4),
    intent: SelectCropRatioIntent(3),
    description: 'Ratio 1:1',
  ),
  ShortcutBinding(
    scope: ShortcutScope.crop,
    activator: SingleActivator(LogicalKeyboardKey.digit5),
    intent: SelectCropRatioIntent(4),
    description: 'Ratio 16:9',
  ),
  ShortcutBinding(
    scope: ShortcutScope.crop,
    activator: SingleActivator(LogicalKeyboardKey.digit6),
    intent: SelectCropRatioIntent(5),
    description: 'Ratio 65:24 (XPan panoramic)',
  ),
  ShortcutBinding(
    scope: ShortcutScope.crop,
    activator: SingleActivator(LogicalKeyboardKey.keyR),
    intent: ToggleCropOrientationIntent(),
    description: 'Swap the frame between portrait and landscape',
  ),
  ShortcutBinding(
    scope: ShortcutScope.crop,
    activator: SingleActivator(LogicalKeyboardKey.keyE, meta: true),
    intent: ExportCropIntent(),
    description: 'Export the crop to the Mac',
  ),
];

/// Bindings that apply in [scope], including the global ones.
List<ShortcutBinding> bindingsFor(ShortcutScope scope) => obscuraShortcutBindings
    .where((b) => b.scope == ShortcutScope.global || b.scope == scope)
    .toList(growable: false);

/// Shortcut map for a `Shortcuts` widget wrapping a screen in [scope].
Map<ShortcutActivator, Intent> shortcutMapFor(ShortcutScope scope) => {
      for (final binding in bindingsFor(scope)) binding.activator: binding.intent,
    };
