// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'composition_dao.dart';

// ignore_for_file: type=lint
mixin _$CompositionDaoMixin on DatabaseAccessor<AppDatabase> {
  $PhotosTable get photos => attachedDatabase.photos;
  $PatternsTable get patterns => attachedDatabase.patterns;
  $LayerInstancesTable get layerInstances => attachedDatabase.layerInstances;
  $CropExportsTable get cropExports => attachedDatabase.cropExports;
  $ExportMarksTable get exportMarks => attachedDatabase.exportMarks;
  CompositionDaoManager get managers => CompositionDaoManager(this);
}

class CompositionDaoManager {
  final _$CompositionDaoMixin _db;
  CompositionDaoManager(this._db);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db.attachedDatabase, _db.photos);
  $$PatternsTableTableManager get patterns =>
      $$PatternsTableTableManager(_db.attachedDatabase, _db.patterns);
  $$LayerInstancesTableTableManager get layerInstances =>
      $$LayerInstancesTableTableManager(
        _db.attachedDatabase,
        _db.layerInstances,
      );
  $$CropExportsTableTableManager get cropExports =>
      $$CropExportsTableTableManager(_db.attachedDatabase, _db.cropExports);
  $$ExportMarksTableTableManager get exportMarks =>
      $$ExportMarksTableTableManager(_db.attachedDatabase, _db.exportMarks);
}
