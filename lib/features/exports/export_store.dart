import 'dart:io';
import 'dart:ui' show Size;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infra/db/database.dart';
import '../../infra/db/database_provider.dart';
import '../../infra/preview/jpeg_size.dart';
import '../catalog/photo_entity.dart';
import '../crop/export_service.dart';
import '../crop/ratio.dart';
import 'export_folder.dart';

/// One file this app has written to the Mac, as the exports screen shows it.
///
/// Every record here has a file behind it. The row and the file are two
/// different facts, and where they disagree the file wins: a photographer who
/// moved an export into a job folder has not lost anything, and the row that
/// stayed behind describes something that is no longer there. Those rows are
/// dropped when the list is built, so nothing downstream has to ask.
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
  });

  final int id;

  /// `100LEICA/L1000001` — the camera's name for the frame it came from, or
  /// empty for a file this app has no record of.
  final String radical;

  /// Nominal ratio label, e.g. `3:2`.
  final String ratio;
  final String orientation;
  final String path;
  final DateTime createdAt;

  final int? pixelWidth;
  final int? pixelHeight;

  /// Size on disk, read when the list is built.
  final int? byteSize;

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

  /// True for a file found in the export folder that no row describes.
  ///
  /// It is the user's export as far as they are concerned — it is in their
  /// export folder — and leaving it out because this app has no row for it
  /// would make the screen a view of the database rather than of the folder.
  bool get untracked => id < 0;

  /// The line under the file name: the frame it came from and the crop, when
  /// they are known, and what the file itself says when they are not.
  String get detail => [
        if (radical.isNotEmpty) radical,
        if (ratio.isNotEmpty && ratio != '—') ratio,
        dimensions,
        if (untracked) 'trouvé dans le dossier',
      ].join('  ·  ');
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
  DriftExportStore(this._db, {Future<Directory> Function()? root})
      : _root = root ?? defaultExportRoot;

  final AppDatabase _db;

  /// Where exports go. Read as well as written: see [all].
  final Future<Directory> Function() _root;

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

  /// Everything exported, newest first: the rows, and then whatever else is in
  /// the export folder.
  ///
  /// The folder is the authority on what exists; the rows are what this app
  /// knows *about* what exists — which frame it came from, which crop, how
  /// large it came out. A file with no row is listed with what the file itself
  /// can say, because a photographer looking at their export folder through
  /// this screen should see the same files the Finder would show them.
  @override
  Future<List<ExportRecord>> all() async {
    final rows = await _db.compositionDao.allExports();
    // A row whose file is gone is left out rather than shown greyed: this list
    // is a view of a folder, and a file moved or thrown away in the Finder is
    // not in the folder. The row stays in the database — put the file back at
    // its path and it is listed again, with its frame and its crop.
    final records = <ExportRecord>[];
    for (final (export, photo) in rows) {
      final record = await _describe(export, photo);
      if (record != null) records.add(record);
    }

    final known = {for (final record in records) record.path};
    records.addAll(await _looseFiles(known));
    // One order for both kinds: newest first, whatever put them there.
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  /// Image files under the export folder that no row accounts for.
  Future<List<ExportRecord>> _looseFiles(Set<String> known) async {
    final Directory root;
    try {
      root = await _root();
      if (!await root.exists()) return const [];
    } on Object {
      return const [];
    }

    final out = <ExportRecord>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.split('/').last;
      if (!_isJpeg(name) || known.contains(entity.path)) continue;

      final stat = await entity.stat();
      final size = await _headerSize(entity);
      out.add(ExportRecord(
        // Negative, and never a row id: nothing can be forgotten from the
        // database that was never in it.
        id: -out.length - 1,
        radical: '',
        ratio: '—',
        orientation: '',
        path: entity.path,
        createdAt: stat.modified,
        pixelWidth: size?.width.round(),
        pixelHeight: size?.height.round(),
        byteSize: stat.size,
      ));
    }
    return out;
  }

  static bool _isJpeg(String name) {
    final lower = name.toLowerCase();
    return !name.startsWith('.') &&
        (lower.endsWith('.jpg') || lower.endsWith('.jpeg'));
  }

  /// The size the file declares, from its first bytes.
  ///
  /// Sixty-four kilobytes is past any frame header a camera or this app writes,
  /// and short of reading a 12 MB export to fill in one column.
  static Future<Size?> _headerSize(File file) async {
    try {
      final handle = await file.open();
      try {
        return jpegPixelSize(await handle.read(64 * 1024));
      } finally {
        await handle.close();
      }
    } on Object {
      return null;
    }
  }

  @override
  Future<void> forget(int id) async {
    // A file the database never knew about has no row to drop; the screen has
    // already dealt with the file itself.
    if (id < 0) return;
    await _db.compositionDao.forgetExport(id);
  }

  /// The row as the screen shows it, or null when its file is gone.
  Future<ExportRecord?> _describe(CropExport export, Photo photo) async {
    final file = File(export.exportPath);
    final stat = await file.stat();
    if (stat.type == FileSystemEntityType.notFound) return null;

    return ExportRecord(
      id: export.id,
      radical: photo.radicalDcf,
      ratio: export.ratio,
      orientation: export.orientation,
      path: export.exportPath,
      createdAt: export.createdAt,
      pixelWidth: export.pixelWidth,
      pixelHeight: export.pixelHeight,
      byteSize: stat.size,
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
    // Listed afterwards, like the real one: a store where recording and listing
    // are unrelated would let a caller pass a test it should fail.
    records.insert(
      0,
      ExportRecord(
        id: records.length + 1,
        radical: photo.dcfPath,
        ratio: crop.ratio.label,
        orientation: crop.orientation.name,
        path: written.path,
        createdAt: DateTime(2026, 8, 12),
        pixelWidth: written.pixelWidth,
        pixelHeight: written.pixelHeight,
        byteSize: written.bytes,
      ),
    );
  }

  @override
  Future<List<ExportRecord>> all() async => [...records];

  @override
  Future<void> forget(int id) async => records.removeWhere((r) => r.id == id);
}

/// Overridden in widget tests, which have no database.
final exportStoreProvider = Provider<ExportStore>(
  (ref) => DriftExportStore(
    ref.watch(appDatabaseProvider),
    root: () async {
      final outcome = await ref.read(exportFoldersProvider).root();
      return switch (outcome) {
        ExportFolderReady(:final directory) => directory,
        // The list is a view of a folder; when there is no usable folder there
        // is nothing to list, and `all()` already treats an absent root as an
        // empty list rather than an error.
        ExportFolderRefused() => Directory(''),
      };
    },
  ),
);

/// The exports, as the screen reads them.
///
/// Re-read rather than watched: the interesting changes are on the file system
/// — a file moved in the Finder, an export the user has just made — and a
/// database stream would not see either of them.
final exportsProvider = FutureProvider<List<ExportRecord>>(
  (ref) => ref.watch(exportStoreProvider).all(),
);
