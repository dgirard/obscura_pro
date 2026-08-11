// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thumb_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$ThumbCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $PhotosTable get photos => attachedDatabase.photos;
  $ThumbCacheEntriesTable get thumbCacheEntries =>
      attachedDatabase.thumbCacheEntries;
  ThumbCacheDaoManager get managers => ThumbCacheDaoManager(this);
}

class ThumbCacheDaoManager {
  final _$ThumbCacheDaoMixin _db;
  ThumbCacheDaoManager(this._db);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db.attachedDatabase, _db.photos);
  $$ThumbCacheEntriesTableTableManager get thumbCacheEntries =>
      $$ThumbCacheEntriesTableTableManager(
        _db.attachedDatabase,
        _db.thumbCacheEntries,
      );
}
