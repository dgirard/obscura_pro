import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dao/catalog_dao.dart';
import 'dao/composition_dao.dart';
import 'dao/thumb_cache_dao.dart';
import 'dao/trash_dao.dart';
import 'tables.dart';

export 'dao/catalog_dao.dart' show CatalogDao;
export 'dao/composition_dao.dart' show CompositionDao;
export 'dao/thumb_cache_dao.dart' show ThumbCacheDao;
export 'dao/trash_dao.dart' show TrashDao, TrashSummary;
export 'tables.dart' show ThumbVariant, TrashFileKind, TrashState;

part 'database.g.dart';

const _databaseFileName = 'obscura_pro.sqlite';

/// The one place that decides where the database lives.
///
/// It resolves under `~/Library/Application Support/<app>/` and **never** on the
/// SD card: the card must stay exactly as the camera wrote it, and a SQLite file
/// there would mean writes (and WAL files) on an unjournalled exFAT volume.
Future<File> obscuraDatabaseFile() async {
  final supportDir = await getApplicationSupportDirectory();
  await supportDir.create(recursive: true);
  return File(p.join(supportDir.path, _databaseFileName));
}

/// Durability settings applied to every file-backed connection.
///
/// `synchronous = FULL` is not the usual WAL default (`NORMAL`) and is chosen
/// deliberately: a destructive-intent row must have reached the disk before the
/// card operation it authorises begins, otherwise a crash can leave a card file
/// unlinked with no record that anyone meant to unlink it.
const durabilityPragmas = <String>[
  'PRAGMA journal_mode = WAL',
  'PRAGMA synchronous = FULL',
];

@DriftDatabase(
  tables: [Patterns, Photos, LayerInstances, CropExports, TrashItems, ThumbCacheEntries],
  daos: [CatalogDao, CompositionDao, TrashDao, ThumbCacheDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openOnMac());

  /// Tests pass `NativeDatabase.memory()`; nothing else should use this.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          var version = from;

          // v2 gave the thumbnail index the placeholder colour and pixel size
          // the grid needs before it reads any cache file.
          if (version == 1) {
            await m.addColumn(thumbCacheEntries, thumbCacheEntries.pixelWidth);
            await m.addColumn(thumbCacheEntries, thumbCacheEntries.pixelHeight);
            await m.addColumn(thumbCacheEntries, thumbCacheEntries.averageColor);
            version = 2;
          }

          // v3 took `svg` and `aspect_ratio` off the pattern library: a guide's
          // geometry is built from the frame it lands on and cannot be stored
          // (see [Patterns]). Rebuilding the table is safe in a way it would
          // not usually be — `pattern` has never had a writer, so no database
          // in existence holds a row, and no `layer_instance` can be pointing
          // at one. Foreign keys are still off here: the pragma in
          // [beforeOpen] runs after migrations, which is what makes drift's
          // copy-and-swap legal at all.
          if (version == 2) {
            await m.alterTable(
              // `kind` has to be named as new, or the copy-and-swap selects a
              // column the old table never had and the whole open fails.
              TableMigration(patterns, newColumns: [patterns.kind]),
            );
            version = 3;
          }

          // v4 lets an export say how large it came out, so the exports list
          // can quote a pixel size without decoding every file it lists.
          if (version == 3) {
            await m.addColumn(cropExports, cropExports.pixelWidth);
            await m.addColumn(cropExports, cropExports.pixelHeight);
            version = 4;
          }

          if (version != to) {
            throw UnsupportedError(
              'No migration is defined from schema $version to $to. '
              'Add the step here before bumping schemaVersion.',
            );
          }
        },
        beforeOpen: (details) async {
          // SQLite disables foreign keys per connection, so the cascades that
          // keep layers, exports, trash rows and cache entries from outliving
          // their photo only exist if this runs on every open.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openOnMac() {
  return LazyDatabase(() async {
    final file = await obscuraDatabaseFile();
    return NativeDatabase(file, setup: (rawDb) {
      for (final pragma in durabilityPragmas) {
        rawDb.execute(pragma);
      }
    });
  });
}
