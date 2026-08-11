import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'thumb_cache_dao.g.dart';

/// Index of the decoded-thumbnail files kept under application-support.
///
/// The rows describe files on the Mac only; the card is read, never cached to.
@DriftAccessor(tables: [ThumbCacheEntries])
class ThumbCacheDao extends DatabaseAccessor<AppDatabase> with _$ThumbCacheDaoMixin {
  ThumbCacheDao(super.db);

  Future<int> upsertEntry(ThumbCacheEntriesCompanion entry) => into(thumbCacheEntries).insert(
        entry,
        onConflict: DoUpdate(
          (_) => entry,
          target: [thumbCacheEntries.cleStable, thumbCacheEntries.variant],
        ),
      );

  Future<ThumbCacheEntry?> entryFor(String cleStable, ThumbVariant variant) =>
      (select(thumbCacheEntries)
            ..where((e) => e.cleStable.equals(cleStable) & e.variant.equalsValue(variant)))
          .getSingleOrNull();

  Future<List<ThumbCacheEntry>> entriesFor(String cleStable) =>
      (select(thumbCacheEntries)..where((e) => e.cleStable.equals(cleStable))).get();

  /// Total bytes the cache occupies, for the eviction budget.
  Future<int> totalBytes() async {
    final sum = thumbCacheEntries.byteSize.sum();
    final row = await (selectOnly(thumbCacheEntries)..addColumns([sum])).getSingle();
    return row.read(sum) ?? 0;
  }

  /// Oldest first -- the eviction order.
  Future<List<ThumbCacheEntry>> entriesByAge({int? limit}) {
    final query = select(thumbCacheEntries)
      ..orderBy([(e) => OrderingTerm(expression: e.createdAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  /// Forgets an index row. The caller unlinks the cache file itself, because a
  /// row without a file is a cache miss while a file without a row is a leak.
  Future<int> removeEntry(int id) =>
      (delete(thumbCacheEntries)..where((e) => e.id.equals(id))).go();
}
