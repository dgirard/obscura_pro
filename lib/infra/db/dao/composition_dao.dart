import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'composition_dao.g.dart';

/// Layer placements and export traceability -- the two things the app records
/// *about* a photo without ever modifying it.
@DriftAccessor(tables: [LayerInstances, CropExports])
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

  Future<int> removeLayer(int id) =>
      (delete(layerInstances)..where((l) => l.id.equals(id))).go();

  Future<int> recordCropExport(CropExportsCompanion export) =>
      into(cropExports).insert(export);

  /// Most recent first: the export list is a history, read from the top.
  Future<List<CropExport>> exportsOfPhoto(int photoId) => (select(cropExports)
        ..where((e) => e.photoId.equals(photoId))
        ..orderBy([
          (e) => OrderingTerm(expression: e.createdAt, mode: OrderingMode.desc),
          (e) => OrderingTerm(expression: e.id, mode: OrderingMode.desc),
        ]))
      .get();
}
