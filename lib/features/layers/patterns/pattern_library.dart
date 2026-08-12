/// The library, as the rest of the app asks for it: by code, by kind, by
/// section.
///
/// The generated list is the data; these are the three questions anything ever
/// puts to it, answered once rather than by a `firstWhere` in each caller.
library;

import 'pattern.dart';
import 'patterns.g.dart';

export 'pattern.dart';
export 'patterns.g.dart' show grammairePatterns;

final Map<String, CompositionPattern> _byCode = {
  for (final pattern in grammairePatterns) pattern.code: pattern,
};

/// The pattern a saved layer refers to, or null if the code is not one of the
/// thirty.
///
/// Nullable rather than throwing: a row could name a code from a future version
/// of the document, and a layers panel that crashed on it would take the whole
/// photograph's composition with it.
CompositionPattern? patternByCode(String code) => _byCode[code];

/// The fifteen that can be laid over a photograph, in the document's order.
final List<CompositionPattern> placeableGuides =
    grammairePatterns.where((p) => p.isGuide).toList(growable: false);

/// Every pattern, grouped by the section it belongs to, sections in the
/// document's order and patterns in theirs.
final Map<PatternCategory, List<CompositionPattern>> patternsByCategory = {
  for (final category in PatternCategory.values)
    category: grammairePatterns
        .where((p) => p.category == category)
        .toList(growable: false),
};
