// Generates `lib/features/layers/patterns/patterns.g.dart` from the Grammaire.
//
//     <flutter>/bin/cache/dart-sdk/bin/dart tool/extract_patterns.dart
//
// Flutter's own Dart, because `dart run` resolves this package's dependencies
// and two of them (sqlite3, objective_c) want the native-assets experiment that
// the stable channel does not offer. Nothing here needs either: it is dart:io
// and a regular expression.
//
// Run it again after editing `docs/reference/grammaire-du-cadre.html`; it is
// idempotent, so a run that changes nothing leaves no diff.
//
// ## What this takes from the document, and what it does not
//
// It takes the metadata: number, French and English names, section, and the
// three fields every card carries. That is all mechanically extractable, and
// keeping it generated means the app's library cannot quietly drift from the
// document it claims to be.
//
// It does **not** take the geometry. The plan expected the inline SVGs to be
// overlay assets; they are teaching diagrams. Each one fills the frame white,
// labels itself in text, and draws a blue blob standing in for a subject —
// `Règle des tiers` marks three points of force in red and puts the fourth
// under the blue subject, so extracting it faithfully would produce a
// three-point rule of thirds. The constructions therefore live in
// `constructions.dart`, built from the frame they are going onto, and
// `patterns_test.dart` pins each one back to the coordinates the document
// draws. Verified against the source beats copied from it.
//
// The one judgement this file carries is [_kinds]: which of the thirty schemas
// is a construction of the frame and which is an illustration of an idea.

import 'dart:io';

const _source = 'docs/reference/grammaire-du-cadre.html';
const _output = 'lib/features/layers/patterns/patterns.g.dart';

/// Which patterns can be laid over a photograph.
///
/// A pattern is a guide when its schema is built from the frame — its edges,
/// its corners, its centre, its diagonals. It is a reference when the schema
/// draws a subject: those are worth reading and impossible to place, because
/// there is nothing in them that a photograph could be measured against.
///
/// Fifteen of each, and every call is listed rather than inferred, because a
/// heuristic over CSS classes gets `Centrage` wrong (its tolerance ring carries
/// no class) and gets `Symétrie` wrong the other way (its two arches do).
const Map<int, bool> _kinds = {
  1: true, //  Règle des tiers — the frame in thirds.
  2: true, //  Grille phi — the frame at 0.382/0.618.
  3: true, //  Spirale d'or — Fibonacci squares inscribed in the frame.
  4: true, //  Rabattement — the short side folded onto the long one.
  5: true, //  Symétrie dynamique — diagonals and their reciprocals.
  6: true, //  Lignes directrices — edges converging on a point you drag.
  7: false, // Points de fuite — three miniature frames side by side.
  8: true, //  Diagonales — the two corner-to-corner lines.
  9: true, //  Méthode des diagonales — true 45° from each corner.
  10: true, // Courbe en S — a drawn curve, but a curve for the frame.
  11: true, // Triangle d'or — the diagonal and its two perpendiculars.
  12: true, // Composition triangulaire — a triangle seated on the base.
  13: true, // Symétrie — the mirror axis. The two arches are subjects.
  14: true, // Centrage — centre cross and tolerance ring.
  15: false, // Poids visuel — a balance beam with weights on it.
  16: false, // Nombres impairs — three subjects; the triangle is already 12.
  17: false, // Espace négatif — a subject and the emptiness around it.
  18: false, // Remplir le cadre — a face.
  19: false, // Profondeur par plans — a landscape in three bands.
  20: false, // Isolation du sujet — one sharp disc among bokeh.
  21: true, //  Position de l'horizon — the two horizon lines.
  22: false, // Cadre dans le cadre — one particular arch.
  23: false, // Règle de l'espace — a subject and its gaze.
  24: false, // Gestalt — four miniature demonstrations.
  25: false, // Motif & rupture — a lattice of subjects and one that breaks it.
  26: false, // Clair-obscur — a lit face.
  27: false, // Couleur — a colour wheel, which a stroke colour cannot render.
  28: false, // Angle de prise de vue — cameras seen from the side.
  29: true, //  Blocking — the camera axis and its field of view.
  30: false, // Juxtaposition — two halves with a thing in each.
};

void main(List<String> args) {
  final source = File(_source);
  if (!source.existsSync()) {
    stderr.writeln('Not found: $_source (run from the repository root)');
    exit(1);
  }

  final html = source.readAsStringSync();
  final patterns = _parse(html);

  if (patterns.length != 30) {
    stderr.writeln('Expected 30 patterns, parsed ${patterns.length}.');
    exit(1);
  }

  final codes = patterns.map((p) => p.code).toSet();
  if (codes.length != patterns.length) {
    stderr.writeln('Codes are not unique; they are the key a saved layer '
        'refers to and two patterns cannot share one.');
    exit(1);
  }

  final out = File(_output);
  final rendered = _render(patterns);
  if (out.existsSync() && out.readAsStringSync() == rendered) {
    stdout.writeln('$_output is already up to date (${patterns.length} '
        'patterns, ${patterns.where((p) => p.guide).length} guides).');
    return;
  }
  out.writeAsStringSync(rendered);
  stdout.writeln('Wrote $_output — ${patterns.length} patterns, '
      '${patterns.where((p) => p.guide).length} guides.');
}

class _Parsed {
  _Parsed({
    required this.number,
    required this.code,
    required this.nom,
    required this.english,
    required this.category,
    required this.guide,
    required this.definition,
    required this.recognise,
    required this.effect,
  });

  final int number;
  final String code;
  final String nom;
  final String english;
  final String category;
  final bool guide;
  final String definition;
  final String recognise;
  final String effect;
}

/// The seven sections, in the document's order, as Dart enum names.
const _categories = [
  'grilles',
  'lignes',
  'formes',
  'espace',
  'perception',
  'lumiere',
  'cinema',
];

List<_Parsed> _parse(String html) {
  final sections = RegExp(
    r'<section class="cat" id="c(\d)">(.*?)</section>',
    dotAll: true,
  ).allMatches(html);

  final out = <_Parsed>[];
  for (final section in sections) {
    final index = int.parse(section.group(1)!) - 1;
    if (index < 0 || index >= _categories.length) {
      throw StateError('Unknown section c${section.group(1)}');
    }
    final articles = RegExp(
      r'<article class="fiche">(.*?)</article>',
      dotAll: true,
    ).allMatches(section.group(2)!);

    for (final article in articles) {
      final body = article.group(1)!;
      final number = int.parse(_capture(body, r'<span class="num">(\d+)</span>'));
      final nom = _text(_capture(body, r'<h3>(.*?)</h3>'));
      final english = _text(_capture(body, r'<div class="en">(.*?)</div>'));
      final guide = _kinds[number];
      if (guide == null) {
        throw StateError('Pattern $number ($nom) is not classified in _kinds.');
      }

      out.add(_Parsed(
        number: number,
        code: _slug(english),
        nom: nom,
        english: english,
        category: _categories[index],
        guide: guide,
        definition: _champ(body, 'Définition'),
        recognise: _champ(body, 'Reconnaître'),
        effect: _champ(body, 'Effet'),
      ));
    }
  }

  out.sort((a, b) => a.number.compareTo(b.number));
  return out;
}

String _capture(String source, String pattern) {
  final match = RegExp(pattern, dotAll: true).firstMatch(source);
  if (match == null) throw StateError('No match for $pattern');
  return match.group(1)!;
}

String _champ(String body, String label) =>
    _text(_capture(body, '<div class="champ"><b>$label</b>(.*?)</div>'));

/// Tags out, entities in, and the document's non-breaking spaces turned back
/// into ordinary ones — they are typography for a web page, not part of the
/// text.
String _text(String raw) {
  var s = raw.replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    ' ': ' ',
  };
  entities.forEach((from, to) => s = s.replaceAll(from, to));
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// `Rule of thirds` becomes `rule-of-thirds`.
///
/// From the English name rather than the French: it is already ASCII, and a
/// saved layer's reference must not break when someone improves the French
/// wording of a card.
String _slug(String english) {
  final head = english.split(RegExp(r'\s+[—/-]\s+')).first;
  return head
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

String _dart(String value) =>
    "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";

String _render(List<_Parsed> patterns) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED by tool/extract_patterns.dart — do not edit.')
    ..writeln('//')
    ..writeln('// Source: $_source')
    ..writeln('//')
    ..writeln('// Metadata only. A guide\'s geometry is built from the frame it')
    ..writeln('// is going onto, in constructions.dart.')
    ..writeln()
    ..writeln("import 'pattern.dart';")
    ..writeln()
    ..writeln('/// The thirty patterns of the Grammaire du cadre, in the')
    ..writeln("/// document's own order.")
    ..writeln('const List<CompositionPattern> grammairePatterns = [');

  for (final p in patterns) {
    buffer
      ..writeln('  CompositionPattern(')
      ..writeln('    number: ${p.number},')
      ..writeln('    code: ${_dart(p.code)},')
      ..writeln('    nom: ${_dart(p.nom)},')
      ..writeln('    english: ${_dart(p.english)},')
      ..writeln('    category: PatternCategory.${p.category},')
      ..writeln('    kind: PatternKind.${p.guide ? 'guide' : 'reference'},')
      ..writeln('    definition: ${_dart(p.definition)},')
      ..writeln('    recognise: ${_dart(p.recognise)},')
      ..writeln('    effect: ${_dart(p.effect)},')
      ..writeln('  ),');
  }

  buffer.writeln('];');
  return buffer.toString();
}
