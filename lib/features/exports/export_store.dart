import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infra/db/database.dart';
import '../../infra/db/database_provider.dart';
import '../catalog/photo_entity.dart';
import '../crop/export_service.dart';
import '../crop/ratio.dart';

/// One file this app has written to the Mac, as the exports screen shows it.
///
/// The row and the file are two different facts, and this keeps them apart:
/// [missing] is what the app knows about the file *now*, not what it recorded
/// when it wrote it. A photographer who moved an export into a job folder has
/// not lost anything, and a list that claimed the file was still there would be
/// the app being wrong about the one thing it can check.
@immutable
final class ExportRecord {
  const ExportRecord({
    required this.id,
    required this.radical,
    required this.ratio,
    required this.orientation,
    required this.path,
    required this.createdAt,
    this.pixelWidth,
    this.pixelHeight,
    this.byteSize,
    this.missing = false,
  });

  final int id;

  /// `100LEICA/L1000001` — the camera's name for the frame it came from.
  final String radical;

  /// Nominal ratio label, e.g. `3:2`.
  final String ratio;
  final String orientation;
  final String path;
  final DateTime createdAt;

  final int? pixelWidth;
  final int? pixelHeight;

  /// Size on disk, read when the list is built. Null when the file is gone.
  final int? byteSize;

  /// True when nothing is at [path] any more.
  final bool missing;

  String get fileName => path.split('/').last;

  /// The day folder the export was written into, which is how a session is
  /// grouped: `~/Pictures/Q3Culling/Exports/2026-08-12/`.
  String get folder {
    final parts = path.split('/');
    return parts.length < 2 ? '' : parts[parts.length - 2];
  }

  String get dimensions => pixelWidth == null || pixelHeight == null
      ? '—'
      : '$pixelWidth × $pixelHeight px';
}

/// Where the traceability of an export lives.
///
/// An interface for the reason the mark store and the layer store are: a widget
/// test has no database, and the screen must still be exercisable.
abstract interface class ExportStore {
  /// Records a file that has just been written.
  Future<void> record({
    required PhotoEntity photo,
    required CropRect crop,
    required ExportWritten written,
  });

  /// Everything exported, newest first, each one checked against the disk.
  Future<List<ExportRecord>> all();

  /// Drops the row. The file is the caller's business — the two are separate
  /// acts and the screen does them in the order that survives an interruption:
  /// file first, row second, so a crash between them leaves a row this list
  /// will show as missing rather than a file nothing remembers.
  Future<void> forget(int id);
}

class DriftExportStore implements ExportStore {
  DriftExportStore(this._db);

  final AppDatabase _db;

  @override
  Future<void> record({
    required PhotoEntity photo,
    required CropRect crop,
    required ExportWritten written,
  }) async {
    final photoId = await _db.catalogDao.photoIdFor(
      cleStable: photo.key.value,
      radicalDcf: photo.dcfPath,
    );
    await _db.compositionDao.recordCropExport(
      CropExportsCompanion.insert(
        photoId: photoId,
        ratio: crop.ratio.label,
        orientation: crop.orientation.name,
        rectX: crop.rect.left,
        rectY: crop.rect.top,
        rectW: crop.rect.width,
        rectH: crop.rect.height,
        exportPath: written.path,
        pixelWidth: Value(written.pixelWidth),
        pixelHeight: Value(written.pixelHeight),
      ),
    );
  }

  @override
  Future<List<ExportRecord>> all() async {
    final rows = await _db.compositionDao.allExports();
    return [
      for (final (export, photo) in rows)
        await _describe(export, photo),
    ];
  }

  @override
  Future<void> forget(int id) => _db.compositionDao.forgetExport(id);

  Future<ExportRecord> _describe(CropExport export, Photo photo) async {
    final file = File(export.exportPath);
    final stat = await file.stat();
    final present = stat.type != FileSystemEntityType.notFound;

    return ExportRecord(
      id: export.id,
      radical: photo.radicalDcf,
      ratio: export.ratio,
      orientation: export.orientation,
      path: export.exportPath,
      createdAt: export.createdAt,
      pixelWidth: export.pixelWidth,
      pixelHeight: export.pixelHeight,
      byteSize: present ? stat.size : null,
      missing: !present,
    );
  }
}

/// A list of exports with nothing behind it.
///
/// For widget tests, which have no database. The records are handed in already
/// built, because what the screen has to get right is how it renders them and
/// what it does to them — not how they were derived.
@visibleForTesting
class InMemoryExportStore implements ExportStore {
  InMemoryExportStore([List<ExportRecord> initial = const []])
      : records = [...initial];

  final List<ExportRecord> records;
  final List<String> recorded = [];

  @override
  Future<void> record({
    required PhotoEntity photo,
    required CropRect crop,
    required ExportWritten written,
  }) async {
    recorded.add(written.path);
  }

  @override
  Future<List<ExportRecord>> all() async => [...records];

  @override
  Future<void> forget(int id) async => records.removeWhere((r) => r.id == id);
}

/// Overridden in widget tests, which have no database.
final exportStoreProvider = Provider<ExportStore>(
  (ref) => DriftExportStore(ref.watch(appDatabaseProvider)),
);

/// The exports, as the screen reads them.
///
/// Re-read rather than watched: the interesting changes are on the file system
/// — a file moved in the Finder, an export the user has just made — and a
/// database stream would not see either of them.
final exportsProvider = FutureProvider<List<ExportRecord>>(
  (ref) => ref.watch(exportStoreProvider).all(),
);
