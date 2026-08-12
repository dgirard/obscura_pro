import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'composition_dao.g.dart';

/// Layer placements and export traceability -- the two things the app records
/// *about* a photo without ever modifying it.
@DriftAccessor(tables: [LayerInstances, CropExports, ExportMarks, Photos])
class CompositionDao extends DatabaseAccessor<AppDatabase> with _$CompositionDaoMixin {
  CompositionDao(super.db);

  Future<int> addLayer(LayerInstancesCompanion layer) => into(layerInstances).insert(layer);

  /// Ordered by [LayerInstances.zIndex] because that is the paint order; ties
  /// fall back to insertion order so re-opening a photo never reshuffles them.
  Future<List<LayerInstance>> layersOfPhoto(int photoId) => (select(layerInstances)
        ..where((l) => l.photoId.equals(photoId))
        ..orderBy([
          (l) => OrderingTerm(expression: l.zIndex),
          (l) => OrderingTerm(expression: l.id),
        ]))
      .get();

  Stream<List<LayerInstance>> watchLayersOfPhoto(int photoId) => (select(layerInstances)
        ..where((l) => l.photoId.equals(photoId))
        ..orderBy([
          (l) => OrderingTerm(expression: l.zIndex),
          (l) => OrderingTerm(expression: l.id),
        ]))
      .watch();

  Future<bool> updateLayer(LayerInstance layer) => update(layerInstances).replace(layer);

  /// Writes the fields a transform changed, leaving the rest of the row alone.
  ///
  /// A drag rewrites four numbers; `replace` would rewrite the whole row from
  /// whatever the caller happened to be holding, which is how a stale copy in
  /// one screen quietly undoes a change made in another.
  Future<int> writeLayer(int id, LayerInstancesCompanion values) =>
      (update(layerInstances)..where((l) => l.id.equals(id))).write(values);

  Future<int> removeLayer(int id) =>
      (delete(layerInstances)..where((l) => l.id.equals(id))).go();

  Future<int> recordCropExport(CropExportsCompanion export) =>
      into(cropExports).insert(export);

  /// Every export this Mac has made, newest first, with the photograph it came
  /// from.
  ///
  /// Joined rather than looked up per row: the exports screen shows the frame's
  /// DCF name beside each file, and a query per line would be one round trip
  /// per export for a value that is one join away.
  Future<List<(CropExport, Photo)>> allExports() async {
    final query = select(cropExports).join([
      innerJoin(photos, photos.id.equalsExp(cropExports.photoId)),
    ])
      ..orderBy([
        OrderingTerm(expression: cropExports.createdAt, mode: OrderingMode.desc),
        OrderingTerm(expression: cropExports.id, mode: OrderingMode.desc),
      ]);

    return [
      for (final row in await query.get())
        (row.readTable(cropExports), row.readTable(photos)),
    ];
  }

  // --- The export queue ------------------------------------------------------

  /// Marks [photoId] as wanted. Marking twice is the same decision, not two.
  Future<void> markForExport(int photoId) async {
    await into(exportMarks).insert(
      ExportMarksCompanion.insert(photoId: photoId),
      // Targeted at the unique key rather than left to default to the primary
      // one: without the target this conflicts on `id`, which a fresh row never
      // does, and the second mark of the same photograph throws.
      onConflict: DoNothing(target: [exportMarks.photoId]),
    );
  }

  Future<int> unmarkForExport(int photoId) =>
      (delete(exportMarks)..where((m) => m.photoId.equals(photoId))).go();

  /// Stable keys of every photograph waiting to be exported.
  ///
  /// Keyed by the stable key rather than by row id for the reason the whole app
  /// is: the grid holds photographs found on a card, and the mark has to find
  /// them again after the card has been out.
  Future<Set<String>> markedForExport() async {
    final query = select(exportMarks).join([
      innerJoin(photos, photos.id.equalsExp(exportMarks.photoId)),
    ]);
    return {
      for (final row in await query.get()) row.readTable(photos).cleStable,
    };
  }

  Future<int> forgetExport(int id) =>
      (delete(cropExports)..where((e) => e.id.equals(id))).go();

  /// Most recent first: the export list is a history, read from the top.
  Future<List<CropExport>> exportsOfPhoto(int photoId) => (select(cropExports)
        ..where((e) => e.photoId.equals(photoId))
        ..orderBy([
          (e) => OrderingTerm(expression: e.createdAt, mode: OrderingMode.desc),
          (e) => OrderingTerm(expression: e.id, mode: OrderingMode.desc),
        ]))
      .get();
}
