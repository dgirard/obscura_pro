import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// One guide, placed on one photograph.
///
/// Everything here is in normalized frame space (KTD-6): [position] is the
/// centre of the guide as a fraction of the photograph, and [scaleX]/[scaleY]
/// are its size as a fraction of it — so a layer means the same thing in the
/// viewer, at 400 % zoom, and on a window half the size. Nothing in this class
/// knows what a pixel is.
///
/// [rotation] is the one part that does depend on the frame's shape: it is a
/// turn in the photograph's *pixels*, not in normalized units, so a symmetry
/// axis laid at 30° is at 30° on the print. The painter's matrix is where that
/// is resolved.
@immutable
final class LayerPlacement {
  const LayerPlacement({
    required this.localId,
    required this.patternCode,
    this.rowId,
    this.position = const Offset(0.5, 0.5),
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
    this.opacity = 0.6,
    this.color = defaultStroke,
    this.zIndex = 0,
    this.locked = false,
    this.obscura = false,
  });

  /// Neutral light grey, per the design system. The alpha lives in [opacity]
  /// rather than here, so the two are one control rather than two that have to
  /// be multiplied out of each other.
  static const int defaultStroke = 0xFFD8D8D8;

  /// The smallest a guide may be dragged to.
  ///
  /// A tenth of the frame, because a layer scaled to nothing has no handles
  /// left to grab and would be unreachable except by deleting it.
  static const double minScale = 0.1;

  /// Identity inside the session, assigned when the layer is placed.
  ///
  /// Separate from [rowId] because the row does not exist yet at the moment the
  /// user first drags the thing they have just placed: the insert is in flight,
  /// and a selection keyed on the database would be null for exactly as long as
  /// the disk takes.
  final int localId;

  /// `pattern.code` — the Grammaire's own identifier, not a row id.
  final String patternCode;

  /// Primary key of the persisted row, once there is one.
  final int? rowId;

  final Offset position;
  final double scaleX;
  final double scaleY;

  /// Radians, clockwise, in the photograph's pixels.
  final double rotation;

  final double opacity;

  /// ARGB, as a plain int so the model does not depend on a Flutter type.
  final int color;

  final int zIndex;

  /// A locked layer is drawn and cannot be moved. It is the answer to the one
  /// thing that goes wrong with direct manipulation: a guide the user has
  /// finished aligning, nudged while reaching for the next one.
  final bool locked;

  /// Whether the layer was placed while the photograph was upside down.
  ///
  /// Recorded rather than acted on: the placement itself is in the photograph's
  /// own space either way (FONC-OBS-2), and this says which perceptual context
  /// the judgement was made in.
  final bool obscura;

  LayerPlacement copyWith({
    int? rowId,
    Offset? position,
    double? scaleX,
    double? scaleY,
    double? rotation,
    double? opacity,
    int? color,
    int? zIndex,
    bool? locked,
  }) =>
      LayerPlacement(
        localId: localId,
        patternCode: patternCode,
        rowId: rowId ?? this.rowId,
        position: position ?? this.position,
        scaleX: scaleX ?? this.scaleX,
        scaleY: scaleY ?? this.scaleY,
        rotation: rotation ?? this.rotation,
        opacity: opacity ?? this.opacity,
        color: color ?? this.color,
        zIndex: zIndex ?? this.zIndex,
        locked: locked ?? this.locked,
        obscura: obscura,
      );

  /// Moves the guide, keeping its centre on the photograph.
  ///
  /// Clamped to the frame and not to the guide's own bounds: a layer may hang
  /// off the edge — half a spiral often should — but a centre dragged past the
  /// corner would leave nothing on screen to grab.
  LayerPlacement movedTo(Offset centre) => copyWith(
        position: Offset(centre.dx.clamp(0.0, 1.0), centre.dy.clamp(0.0, 1.0)),
      );

  LayerPlacement resizedTo({
    required Offset centre,
    required double scaleX,
    required double scaleY,
  }) =>
      movedTo(centre).copyWith(
        scaleX: math.max(minScale, scaleX),
        scaleY: math.max(minScale, scaleY),
      );

  /// The aspect of the guide's own rectangle, given the photograph's.
  ///
  /// This is what a construction is built against: a rule of thirds squeezed
  /// into a tall layer divides *that* rectangle in three, and the spiral
  /// inscribed in it is the spiral of that rectangle.
  double aspectIn(double frameAspect) {
    if (!frameAspect.isFinite || frameAspect <= 0) return 1;
    if (scaleY <= 0) return frameAspect;
    return frameAspect * scaleX / scaleY;
  }

  @override
  bool operator ==(Object other) =>
      other is LayerPlacement &&
      other.localId == localId &&
      other.patternCode == patternCode &&
      other.rowId == rowId &&
      other.position == position &&
      other.scaleX == scaleX &&
      other.scaleY == scaleY &&
      other.rotation == rotation &&
      other.opacity == opacity &&
      other.color == color &&
      other.zIndex == zIndex &&
      other.locked == locked &&
      other.obscura == obscura;

  @override
  int get hashCode => Object.hash(
        localId,
        patternCode,
        rowId,
        position,
        scaleX,
        scaleY,
        rotation,
        opacity,
        color,
        zIndex,
        locked,
        obscura,
      );

  @override
  String toString() => 'LayerPlacement($patternCode #$localId'
      '${rowId == null ? ', unsaved' : ''})';
}
