import 'dart:ui' show Offset;

import 'package:meta/meta.dart';

/// The seven sections of `docs/reference/grammaire-du-cadre.html`, in the
/// document's own order.
enum PatternCategory {
  grilles('Grilles & rapports'),
  lignes('Lignes & directions'),
  formes('Formes & équilibre'),
  espace('Espace & profondeur'),
  perception('Perception & Gestalt'),
  lumiere('Lumière & couleur'),
  cinema('Point de vue & héritage du cinéma');

  const PatternCategory(this.label);

  final String label;
}

/// Whether a pattern is something you put on a photograph.
///
/// The Grammaire's thirty schemas are teaching diagrams, not overlay assets:
/// about half draw a construction of the frame — lines defined by its edges,
/// corners or centre — and the rest draw a *subject* to illustrate an idea. The
/// first kind can be laid over someone's photograph and dragged onto their
/// composition. The second cannot: a smiling face for "fill the frame" or a
/// colour wheel for "complementary colours" is a page from a book, and putting
/// it on a photograph would say nothing about that photograph.
///
/// Both stay in the library. A [reference] pattern opens its card instead of
/// dropping a shape, so the Grammaire is readable inside the app rather than
/// half-imported and half-lost.
enum PatternKind { guide, reference }

/// One drawable piece of a guide, in normalized frame coordinates.
///
/// `(0,0)` is the top-left of the photograph and `(1,1)` the bottom-right, the
/// same space [ViewTransform] maps — so a guide survives a window resize, a
/// zoom, and obscura without any of them touching its numbers.
sealed class GuidePrimitive {
  const GuidePrimitive();

  /// Dashed strokes are the Grammaire's own distinction between a construction
  /// and the scaffolding that produced it — the reciprocal diagonals of an
  /// armature, the arc that swings a square into place.
  bool get dashed;
}

@immutable
final class GuideSegment extends GuidePrimitive {
  const GuideSegment(this.a, this.b, {this.dashed = false});

  final Offset a;
  final Offset b;

  @override
  final bool dashed;
}

/// An open or closed run of straight segments.
@immutable
final class GuidePolyline extends GuidePrimitive {
  const GuidePolyline(this.points, {this.closed = false, this.dashed = false});

  final List<Offset> points;
  final bool closed;

  @override
  final bool dashed;
}

@immutable
final class GuideCubic extends GuidePrimitive {
  const GuideCubic({
    required this.start,
    required this.control1,
    required this.control2,
    required this.end,
    this.dashed = false,
  });

  final Offset start;
  final Offset control1;
  final Offset control2;
  final Offset end;

  @override
  final bool dashed;
}

/// An elliptical arc, with both radii normalized to their own axis.
///
/// Normalized rather than circular because the golden spiral's quarter-circles
/// are circular in the *photograph's* pixels, and a 3:2 frame stretches those
/// pixels differently on each axis. Storing `rx` and `ry` separately is what
/// lets the same arc be right on a square crop and on an XPan panorama.
@immutable
final class GuideArc extends GuidePrimitive {
  const GuideArc({
    required this.centre,
    required this.radii,
    required this.startAngle,
    required this.sweep,
    this.dashed = false,
  });

  final Offset centre;

  /// `(rx, ry)`, each a fraction of its own axis.
  final Offset radii;

  /// Radians, zero pointing along +x, growing clockwise as screen y does.
  final double startAngle;
  final double sweep;

  @override
  final bool dashed;
}

/// A true circle, whatever the frame's shape.
///
/// [radius] is a fraction of the frame's *shorter* side, so this stays round
/// rather than becoming the ellipse a [GuideArc] would give. The centring
/// pattern's tolerance ring means "this far from the middle in any direction",
/// which is a circle or it is nothing.
@immutable
final class GuideCircle extends GuidePrimitive {
  const GuideCircle({
    required this.centre,
    required this.radius,
    this.dashed = false,
  });

  final Offset centre;
  final double radius;

  @override
  final bool dashed;
}

/// A place rather than a shape: a point of force, an intersection worth landing
/// a subject on.
///
/// Drawn at a fixed size on screen, because a marker that grew with the frame
/// would stop being a marker.
@immutable
final class GuidePoint extends GuidePrimitive {
  const GuidePoint(this.at);

  final Offset at;

  @override
  bool get dashed => false;
}

/// One of the thirty patterns of the Grammaire du cadre.
///
/// The metadata is generated from the document (`tool/extract_patterns.dart`);
/// the geometry of a [PatternKind.guide] is built by
/// `constructions.dart` from the frame it is going onto.
@immutable
final class CompositionPattern {
  const CompositionPattern({
    required this.number,
    required this.code,
    required this.nom,
    required this.english,
    required this.category,
    required this.kind,
    required this.definition,
    required this.recognise,
    required this.effect,
  });

  /// The document's own numbering, 1..30.
  final int number;

  /// Stable identifier, and the `pattern.code` a saved layer refers to. Derived
  /// from the English name, which is ASCII and does not change when the French
  /// wording is polished.
  final String code;

  final String nom;
  final String english;
  final PatternCategory category;
  final PatternKind kind;

  /// The three fields every card in the Grammaire carries.
  final String definition;
  final String recognise;
  final String effect;

  bool get isGuide => kind == PatternKind.guide;
}
