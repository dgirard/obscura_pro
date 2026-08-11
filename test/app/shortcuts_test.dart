import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/shortcuts.dart';

/// Verifies the keyboard catalogue against the table in
/// `docs/reference/spec-q3-culling.md` (section 5).
void main() {
  /// The check the collision tests rely on: which key combinations appear more
  /// than once among [bindings].
  Set<String> duplicateSignatures(List<ShortcutBinding> bindings) {
    final seen = <String, int>{};
    for (final binding in bindings) {
      final s = binding.signature;
      final key = '${s.key.keyLabel}|meta=${s.meta}|shift=${s.shift}'
          '|alt=${s.alt}|ctrl=${s.control}';
      seen[key] = (seen[key] ?? 0) + 1;
    }
    return seen.entries.where((e) => e.value > 1).map((e) => e.key).toSet();
  }

  group('collision detection', () {
    test('flags a genuine conflict', () {
      // Proves the check below can actually fail. Without this, a detector that
      // silently returned an empty set would make every scope look clean.
      final conflicting = [
        const ShortcutBinding(
          scope: ShortcutScope.viewer,
          activator: SingleActivator(LogicalKeyboardKey.keyO),
          intent: ToggleObscuraIntent(),
          description: 'Toggle obscura',
        ),
        const ShortcutBinding(
          scope: ShortcutScope.viewer,
          activator: SingleActivator(LogicalKeyboardKey.keyO),
          intent: ToggleLayersPanelIntent(),
          description: 'Something else on the same key',
        ),
      ];
      expect(duplicateSignatures(conflicting), isNotEmpty);
    });

    test('treats a modifier as part of the combination', () {
      // Backspace and Command-Backspace are mark-for-deletion and empty-trash.
      // Collapsing them would map the destructive action onto the safe key.
      final distinct = [
        const ShortcutBinding(
          scope: ShortcutScope.global,
          activator: SingleActivator(LogicalKeyboardKey.backspace),
          intent: ToggleMarkForDeletionIntent(),
          description: 'Mark',
        ),
        const ShortcutBinding(
          scope: ShortcutScope.global,
          activator: SingleActivator(LogicalKeyboardKey.backspace, meta: true),
          intent: EmptyTrashIntent(),
          description: 'Empty trash',
        ),
      ];
      expect(duplicateSignatures(distinct), isEmpty);
    });
  });

  group('the shipped catalogue', () {
    for (final scope in ShortcutScope.values) {
      test('has no conflicting bindings in ${scope.name}', () {
        expect(
          duplicateSignatures(bindingsFor(scope)),
          isEmpty,
          reason: 'Two actions in ${scope.name} answer the same key press.',
        );
      });
    }

    test('lets one key mean different things in different scopes', () {
      // Enter opens a photo from the grid and closes the viewer. That is not a
      // conflict, and the scoping must keep it legal.
      final gridEnter = bindingsFor(ShortcutScope.grid)
          .firstWhere((b) => b.activator.trigger == LogicalKeyboardKey.enter);
      final viewerEnter = bindingsFor(ShortcutScope.viewer)
          .firstWhere((b) => b.activator.trigger == LogicalKeyboardKey.enter);

      expect(gridEnter.intent, isA<OpenViewerIntent>());
      expect(viewerEnter.intent, isA<CloseViewerIntent>());
    });
  });

  group('coverage of the spec keyboard table', () {
    bool hasBinding(
      ShortcutScope scope,
      LogicalKeyboardKey key, {
      bool meta = false,
      bool shift = false,
    }) =>
        bindingsFor(scope).any((b) =>
            b.activator.trigger == key &&
            b.activator.meta == meta &&
            b.activator.shift == shift);

    test('covers grid navigation', () {
      expect(hasBinding(ShortcutScope.grid, LogicalKeyboardKey.arrowLeft), isTrue);
      expect(hasBinding(ShortcutScope.grid, LogicalKeyboardKey.arrowRight), isTrue);
      expect(hasBinding(ShortcutScope.grid, LogicalKeyboardKey.arrowUp), isTrue);
      expect(hasBinding(ShortcutScope.grid, LogicalKeyboardKey.arrowDown), isTrue);
      expect(hasBinding(ShortcutScope.grid, LogicalKeyboardKey.enter), isTrue);
      expect(hasBinding(ShortcutScope.grid, LogicalKeyboardKey.space), isTrue);
    });

    test('covers viewer review actions', () {
      expect(hasBinding(ShortcutScope.viewer, LogicalKeyboardKey.keyO), isTrue);
      expect(hasBinding(ShortcutScope.viewer, LogicalKeyboardKey.keyL), isTrue);
      expect(hasBinding(ShortcutScope.viewer, LogicalKeyboardKey.keyC), isTrue);
      expect(hasBinding(ShortcutScope.viewer, LogicalKeyboardKey.equal, meta: true), isTrue);
      expect(hasBinding(ShortcutScope.viewer, LogicalKeyboardKey.minus, meta: true), isTrue);
      expect(hasBinding(ShortcutScope.viewer, LogicalKeyboardKey.digit0, meta: true), isTrue);
    });

    test('covers deletion, undo and eject everywhere', () {
      expect(hasBinding(ShortcutScope.global, LogicalKeyboardKey.backspace), isTrue);
      expect(hasBinding(ShortcutScope.global, LogicalKeyboardKey.backspace, meta: true), isTrue);
      expect(hasBinding(ShortcutScope.global, LogicalKeyboardKey.keyZ, meta: true), isTrue);
      expect(hasBinding(ShortcutScope.global, LogicalKeyboardKey.keyZ, meta: true, shift: true), isTrue);
      expect(hasBinding(ShortcutScope.global, LogicalKeyboardKey.eject, meta: true), isTrue);
    });

    test('binds exactly the six permitted crop ratios, in selector order', () {
      final ratioIntents = bindingsFor(ShortcutScope.crop)
          .map((b) => b.intent)
          .whereType<SelectCropRatioIntent>()
          .map((i) => i.ratioIndex)
          .toList()
        ..sort();

      // Six ratios and no more: free-form cropping is not reachable by design.
      expect(ratioIntents, [0, 1, 2, 3, 4, 5]);
      expect(hasBinding(ShortcutScope.crop, LogicalKeyboardKey.keyR), isTrue);
      expect(hasBinding(ShortcutScope.crop, LogicalKeyboardKey.keyE, meta: true), isTrue);
    });
  });

  group('shortcutMapFor', () {
    test('gives a screen its own bindings plus the global ones', () {
      final cropMap = shortcutMapFor(ShortcutScope.crop);

      // A crop-mode key...
      expect(cropMap.values.whereType<SelectCropRatioIntent>(), isNotEmpty);
      // ...and a global one reachable from the same screen.
      expect(cropMap.values.whereType<UndoIntent>(), isNotEmpty);
      // ...but nothing scoped to the grid.
      expect(cropMap.values.whereType<NextRowIntent>(), isEmpty);
    });
  });
}
