import 'dart:ui' show Offset;

import 'package:drift/drift.dart' show Value;
import 'package:meta/meta.dart';

import '../../infra/db/database.dart';
import '../catalog/photo_entity.dart';
import 'layer_placement.dart';
import 'patterns/pattern_library.dart';

/// Where a composition is kept.
///
/// An interface for the reason [MarkStore] is one: a widget test has no
/// application-support directory to open a database in, and the viewer must
/// still be exercisable without one.
abstract interface class LayerStore {
  /// The layers saved on [photo], in paint order.
  Future<List<LayerPlacement>> layersOf(PhotoEntity photo);

  /// Makes what is stored match [placements], and returns them with their row
  /// ids filled in.
  Future<List<LayerPlacement>> save(
    PhotoEntity photo,
    List<LayerPlacement> placements,
  );
}

/// The composition, on the Mac, keyed by the photograph rather than by its path
/// (R23).
///
/// The card is not touched, and the mount point is not part of the key, so
/// ejecting a card and putting it back in a different reader brings the layers
/// back with it — which is AE3, and the reason the stable key exists at all.
class LayerRepository implements LayerStore {
  LayerRepository(this._db);

  final AppDatabase _db;

  Future<Map<String, int>>? _seeding;

  CompositionDao get _composition => _db.compositionDao;
  CatalogDao get _catalog => _db.catalogDao;

  /// The pattern library, seeded once and then held as code → row id.
  ///
  /// Seeded on first use rather than at startup: the library is thirty rows of
  /// reference data, and a database write at launch would sit in front of the
  /// first thumbnail for no one's benefit.
  Future<Map<String, int>> patternIds() => _seeding ??= _seed();

  Future<Map<String, int>> _seed() async {
    await _catalog.upsertPatterns([
      for (final pattern in grammairePatterns)
        PatternsCompanion.insert(
          code: pattern.code,
          nom: pattern.nom,
          categorie: pattern.category.name,
          kind: Value(pattern.kind.name),
        ),
    ]);
    return {
      for (final row in await _catalog.allPatterns()) row.code: row.id,
    };
  }

  /// [LayerPlacement.localId] comes back as the row id: they are unique and
  /// stable, and giving the session a second numbering for rows that already
  /// have one is how a selection ends up pointing at the wrong guide.
  @override
  Future<List<LayerPlacement>> layersOf(PhotoEntity photo) async {
    final ids = await patternIds();
    final codes = {for (final entry in ids.entries) entry.value: entry.key};

    final existing = await _catalog.photoByStableKey(photo.key.value);
    if (existing == null) return const [];

    final rows = await _composition.layersOfPhoto(existing.id);
    return [
      for (final row in rows)
        if (codes[row.patternId] case final code?)
          LayerPlacement(
            localId: row.id,
            rowId: row.id,
            patternCode: code,
            position: Offset(row.posX, row.posY),
            scaleX: row.scaleX,
            scaleY: row.scaleY,
            rotation: row.rotation,
            opacity: row.opacity,
            color: row.color,
            zIndex: row.zIndex,
            locked: row.locked,
            obscura: row.obscura,
          ),
    ];
  }

  /// A diff rather than a delete-and-reinsert. Rewriting the table would work
  /// and would renumber every row on every drag, which turns "delete this one
  /// layer" into "delete all of them and put the others back" — indistinguishable
  /// afterwards, and not at all the same thing if the write is interrupted
  /// halfway.
  @override
  Future<List<LayerPlacement>> save(
    PhotoEntity photo,
    List<LayerPlacement> placements,
  ) async {
    final ids = await patternIds();
    final photoId = await _catalog.photoIdFor(
      cleStable: photo.key.value,
      radicalDcf: photo.dcfPath,
    );

    final kept = {
      for (final placement in placements)
        if (placement.rowId != null) placement.rowId!,
    };
    for (final row in await _composition.layersOfPhoto(photoId)) {
      if (!kept.contains(row.id)) await _composition.removeLayer(row.id);
    }

    final out = <LayerPlacement>[];
    for (final placement in placements) {
      final patternId = ids[placement.patternCode];
      // A code with no row is a guide this build does not know. Dropping the
      // placement would lose the user's work silently, so it is kept in memory
      // and simply not written — and `save` returning it unchanged, still with
      // no row id, is what says so.
      if (patternId == null) {
        out.add(placement);
        continue;
      }

      if (placement.rowId == null) {
        final id = await _composition.addLayer(
          LayerInstancesCompanion.insert(
            photoId: photoId,
            patternId: patternId,
            posX: Value(placement.position.dx),
            posY: Value(placement.position.dy),
            scaleX: Value(placement.scaleX),
            scaleY: Value(placement.scaleY),
            rotation: Value(placement.rotation),
            opacity: Value(placement.opacity),
            color: placement.color,
            zIndex: Value(placement.zIndex),
            locked: Value(placement.locked),
            obscura: Value(placement.obscura),
          ),
        );
        out.add(placement.copyWith(rowId: id));
      } else {
        await _composition.writeLayer(
          placement.rowId!,
          LayerInstancesCompanion(
            posX: Value(placement.position.dx),
            posY: Value(placement.position.dy),
            scaleX: Value(placement.scaleX),
            scaleY: Value(placement.scaleY),
            rotation: Value(placement.rotation),
            opacity: Value(placement.opacity),
            color: Value(placement.color),
            zIndex: Value(placement.zIndex),
            locked: Value(placement.locked),
            obscura: Value(placement.obscura),
          ),
        );
        out.add(placement);
      }
    }
    return out;
  }
}

/// A composition that lives no longer than the test that made it.
///
/// Never used by the application: a silent in-memory fallback for a store that
/// failed to open would let the panel report a composition as saved when
/// nothing had been written, which is the one thing [LayerBoard.durable] exists
/// to prevent.
@visibleForTesting
class InMemoryLayerStore implements LayerStore {
  final Map<String, List<LayerPlacement>> _byPhoto = {};

  int _nextRowId = 1;

  @override
  Future<List<LayerPlacement>> layersOf(PhotoEntity photo) async =>
      [...?_byPhoto[photo.key.value]];

  @override
  Future<List<LayerPlacement>> save(
    PhotoEntity photo,
    List<LayerPlacement> placements,
  ) async {
    final saved = [
      for (final placement in placements)
        placement.rowId == null
            ? placement.copyWith(rowId: _nextRowId++)
            : placement,
    ];
    _byPhoto[photo.key.value] = saved;
    return saved;
  }
}
