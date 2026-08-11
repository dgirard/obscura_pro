// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trash_dao.dart';

// ignore_for_file: type=lint
mixin _$TrashDaoMixin on DatabaseAccessor<AppDatabase> {
  $PhotosTable get photos => attachedDatabase.photos;
  $TrashItemsTable get trashItems => attachedDatabase.trashItems;
  TrashDaoManager get managers => TrashDaoManager(this);
}

class TrashDaoManager {
  final _$TrashDaoMixin _db;
  TrashDaoManager(this._db);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db.attachedDatabase, _db.photos);
  $$TrashItemsTableTableManager get trashItems =>
      $$TrashItemsTableTableManager(_db.attachedDatabase, _db.trashItems);
}
