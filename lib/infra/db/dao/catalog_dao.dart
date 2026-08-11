import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'catalog_dao.g.dart';

/// Reads and writes the two reference tables every other module keys into:
/// the pattern library and the known-photo catalog.
@DriftAccessor(tables: [Patterns, Photos])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);

  Future<List<Pattern>> allPatterns() => select(patterns).get();

  Future<Pattern?> patternByCode(String code) =>
      (select(patterns)..where((p) => p.code.equals(code))).getSingleOrNull();

  /// Re-seeding the pattern library must not multiply rows or renumber the
  /// patterns already referenced by layer instances, so `code` -- not the row
  /// id, which the seed does not know -- is the conflict target.
  Future<void> upsertPatterns(Iterable<PatternsCompanion> rows) async {
    await transaction(() async {
      for (final row in rows) {
        await into(patterns).insert(
          row,
          onConflict: DoUpdate((_) => row, target: [patterns.code]),
        );
      }
    });
  }

  Future<int> insertPhoto(PhotosCompanion photo) => into(photos).insert(photo);

  Future<Photo?> photoByStableKey(String cleStable) =>
      (select(photos)..where((p) => p.cleStable.equals(cleStable))).getSingleOrNull();

  Future<Photo?> photoById(int id) =>
      (select(photos)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Rescanning a card re-derives the same stable key for a file that has not
  /// changed, so the scan upserts rather than inserting.
  Future<void> upsertPhoto(PhotosCompanion photo) async {
    await into(photos).insert(photo, onConflict: DoUpdate((_) => photo, target: [photos.cleStable]));
  }

  /// Fills in the header-parse result so decode workers never walk the IFD
  /// chain again for this photo.
  Future<void> recordPreviewOffsets(
    int photoId, {
    required int smallOffset,
    required int smallLength,
    required int fullOffset,
    required int fullLength,
  }) async {
    await (update(photos)..where((p) => p.id.equals(photoId))).write(
      PhotosCompanion(
        previewSmallOffset: Value(smallOffset),
        previewSmallLength: Value(smallLength),
        previewFullOffset: Value(fullOffset),
        previewFullLength: Value(fullLength),
      ),
    );
  }

  /// Drops a photo and everything the app derived from it. Card files are not
  /// touched: this forgets the photo, it does not delete it.
  Future<int> purgePhoto(int photoId) =>
      (delete(photos)..where((p) => p.id.equals(photoId))).go();

  Future<List<Photo>> allPhotos() =>
      (select(photos)..orderBy([(p) => OrderingTerm(expression: p.radicalDcf)])).get();

  Stream<List<Photo>> watchAllPhotos() =>
      (select(photos)..orderBy([(p) => OrderingTerm(expression: p.radicalDcf)])).watch();
}
