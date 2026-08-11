import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../infra/db/database.dart';
import '../../infra/safety/atomic_ops.dart';
import '../catalog/dcf_scanner.dart';
import '../catalog/photo_entity.dart';

/// The deletion state machine, and the only thing in the app that removes a
/// photograph (KTD-14, R12, R13, R14, R21, R22).
///
/// Every card-writing step is the same three moves in the same order: commit a
/// durable intent row, do the file operation and observe the result, commit the
/// outcome. Never a batch. Never the outcome first. A crash between any two of
/// them leaves a row that says what was being attempted, which is what makes
/// [reconcile] able to work out afterwards what actually happened.
///
/// Marking is not one of those steps. Pressing Delete writes a row on the Mac
/// and touches the card not at all — a photographer culling 900 frames is
/// making decisions, not deletions, and the card should be able to be pulled at
/// any point during that without consequence.
class TrashService {
  TrashService({required AppDatabase db, required this.macTrashRoot}) : _db = db;

  final AppDatabase _db;

  /// Where rescued originals live. On the Mac, always: nothing this app invents
  /// is ever written to the card.
  final Directory macTrashRoot;

  static Future<TrashService> open(AppDatabase db) async {
    final support = await getApplicationSupportDirectory();
    return TrashService(
      db: db,
      macTrashRoot: Directory(p.join(support.path, 'Trash')),
    );
  }

  TrashDao get _trash => _db.trashDao;
  CatalogDao get _catalog => _db.catalogDao;

  // --- Marking (writes nothing to the card) ---------------------------------

  /// Marks every file of [photo] for deletion.
  ///
  /// Entity-wide by definition: a DNG and its JPG are one photograph, and
  /// leaving one behind is how a culling tool fills a card with orphans the
  /// user believes they cleared (R12).
  Future<void> mark(PhotoEntity photo) async {
    final id = await _photoId(photo);
    for (final file in photo.files) {
      await _trash.upsertItem(
        TrashItemsCompanion.insert(
          photoId: id,
          fileKind: _kindOf(file),
          cardRelativePath: _relativePath(photo, file),
          state: TrashState.marked,
          byteSize: Value(file.sizeBytes),
        ),
      );
    }
  }

  /// Takes the mark back off, for every file of the entity.
  Future<void> unmark(PhotoEntity photo) async {
    final id = await _photoId(photo);
    for (final item in await _trash.itemsOfPhoto(id)) {
      if (item.state != TrashState.marked) continue;
      await _trash.commitOutcome(item.id, TrashState.onCard);
    }
  }

  Future<Set<String>> markedKeys() async {
    final marked = await _trash.itemsInState(TrashState.marked);
    final keys = <String>{};
    for (final item in marked) {
      final photo = await _catalog.photoById(item.photoId);
      if (photo != null) keys.add(photo.cleStable);
    }
    return keys;
  }

  Stream<TrashSummary> watchSummary() => _trash.watchTrashSummary();

  // --- Emptying the trash (the irreversible one) -----------------------------

  /// Permanently removes every marked photograph from the card.
  ///
  /// One entity at a time, each as its own intent/operation/outcome triple. A
  /// batch write at the end would mean a crash halfway through left the
  /// database describing a card that no longer exists.
  ///
  /// Stops the moment the volume goes away. Everything already touched keeps
  /// whatever state it reached; everything in flight becomes uncertain, because
  /// nothing can be observed about a card that is not there (R22, CARTE-5).
  Future<EmptyTrashReport> emptyTrash(List<PhotoEntity> photos) async {
    final deleted = <String>[];
    final skipped = <TrashConflict>[];
    final uncertain = <String>[];
    var bytesFreed = 0;
    var stoppedEarly = false;

    for (final photo in photos) {
      if (stoppedEarly) {
        uncertain.add(photo.dcfPath);
        continue;
      }

      final id = await _photoId(photo);
      final items = await _trash.itemsOfPhoto(id);
      var entityDeleted = true;

      // The guard that matters, and it is asked once per photograph rather than
      // once per file. Between marking and now the camera may have been used,
      // its numbering reset, and a different frame written over these very
      // names. Deleting on the strength of a path would take the new picture.
      final intact = await _identityIntact(photo);
      if (intact == false) {
        for (final item in items) {
          if (item.state != TrashState.marked) continue;
          // The photograph the user marked is not here any more, so their
          // decision is spent — but the file now at that path is a stranger and
          // is not touched.
          await _trash.commitOutcome(item.id, TrashState.deleted);
        }
        skipped.add(TrashConflict(
          dcfPath: photo.dcfPath,
          path: photo.files.first.path,
          reason: TrashConflictReason.differentPhotographAtPath,
        ));
        continue;
      }

      for (final item in items) {
        if (item.state != TrashState.marked) continue;
        final file = photo.files.firstWhere(
          (f) => _kindOf(f) == item.fileKind,
          orElse: () => photo.files.first,
        );

        await _trash.recordIntent(item.id, TrashState.deleting);
        final outcome = await verifiedUnlink(File(file.path));

        switch (outcome) {
          case Unlinked(bytesFreed: final freed):
            bytesFreed += freed;
            await _trash.commitOutcome(item.id, TrashState.deleted);
          case AlreadyAbsent():
            // Someone or something removed it first. The user's intent is
            // satisfied either way, and refusing to record it would leave the
            // row stuck in flight for ever.
            await _trash.commitOutcome(item.id, TrashState.deleted);
          case VolumeGone():
            await _trash.commitOutcome(item.id, TrashState.uncertain);
            uncertain.add(photo.dcfPath);
            entityDeleted = false;
            stoppedEarly = true;
          case UnlinkFailed(:final reason):
            await _trash.commitOutcome(item.id, TrashState.uncertain);
            skipped.add(TrashConflict(
              dcfPath: photo.dcfPath,
              path: file.path,
              reason: TrashConflictReason.ioError,
              detail: reason,
            ));
            entityDeleted = false;
        }
      }

      if (entityDeleted && !stoppedEarly) deleted.add(photo.dcfPath);
    }

    return EmptyTrashReport(
      deleted: deleted,
      skipped: skipped,
      uncertain: uncertain,
      bytesFreed: bytesFreed,
      haltedByVolumeLoss: stoppedEarly,
    );
  }

  /// Whether what is on the card is still the photograph that was marked.
  ///
  /// Null when nothing is left to compare against — every file that could
  /// answer the question is gone, which is itself the answer to whether it
  /// still needs deleting.
  ///
  /// Compared at the entity level and only against a key of the same basis as
  /// the one recorded. A stable key is derived the way the scan derives it,
  /// from the RAW's EXIF when there is one; a sibling JPEG carrying no EXIF
  /// would yield a size-and-mtime key that legitimately differs, and reading
  /// that as "a different photograph" would block the entity from ever being
  /// deleted.
  Future<bool?> _identityIntact(PhotoEntity photo) async {
    final ordered = [...photo.files]
      ..sort((a, b) => a.kind == PhotoFileKind.raw ? -1 : 1);
    for (final file in ordered) {
      final key = await stableKeyOfFile(file.path, dcfRadical: photo.dcfPath);
      if (key == null || key.basis != photo.key.basis) continue;
      return key.value == photo.key.value;
    }
    return null;
  }

  // --- Immediate mode: move the originals to the Mac -------------------------

  /// Copies the entity to the Mac trash, then removes it from the card.
  ///
  /// The order is the whole safety property: copy, read back, hash, and only
  /// then unlink. At no instant between the two is there less than one complete
  /// readable copy of the photograph.
  Future<MoveReport> moveToMacTrash(PhotoEntity photo) async {
    final id = await _photoId(photo);
    final items = await _trash.itemsOfPhoto(id);
    final moved = <String>[];
    final failed = <TrashConflict>[];

    for (final item in items) {
      if (item.state != TrashState.marked && item.state != TrashState.onCard) {
        continue;
      }
      final file = photo.files.firstWhere(
        (f) => _kindOf(f) == item.fileKind,
        orElse: () => photo.files.first,
      );
      final destination = File(p.join(
        macTrashRoot.path,
        photo.key.value,
        p.basename(file.path),
      ));

      await _trash.recordIntent(item.id, TrashState.movingToMacTrash);
      final copy = await copyVerified(source: File(file.path), destination: destination);

      switch (copy) {
        case CopyVerified(:final path, :final hash):
          final unlink = await verifiedUnlink(File(file.path));
          if (unlink is Unlinked || unlink is AlreadyAbsent) {
            await _trash.commitOutcome(
              item.id,
              TrashState.movedToMacTrash,
              macTrashPath: path,
              sourceHash: hash,
              verifiedAt: DateTime.now(),
            );
            moved.add(file.name);
          } else {
            // The copy is good and the original is still there. That is a
            // safe place to stop: back to marked, with the verified copy left
            // where it is for reconciliation to find.
            await _trash.commitOutcome(
              item.id,
              TrashState.marked,
              macTrashPath: path,
              sourceHash: hash,
              verifiedAt: DateTime.now(),
            );
            failed.add(TrashConflict(
              dcfPath: photo.dcfPath,
              path: file.path,
              reason: TrashConflictReason.ioError,
              detail: 'copied to the Mac but the card file could not be removed',
            ));
          }
        case CopyCorrupt():
          // Never unlink on the strength of a copy that did not verify. This is
          // the case the hash exists for.
          await _trash.commitOutcome(item.id, TrashState.marked);
          failed.add(TrashConflict(
            dcfPath: photo.dcfPath,
            path: file.path,
            reason: TrashConflictReason.copyDidNotVerify,
          ));
        case CopySourceMissing():
          await _trash.commitOutcome(item.id, TrashState.deleted);
        case CopyFailed(:final reason):
          await _trash.commitOutcome(item.id, TrashState.uncertain);
          failed.add(TrashConflict(
            dcfPath: photo.dcfPath,
            path: file.path,
            reason: TrashConflictReason.ioError,
            detail: reason,
          ));
      }
    }

    return MoveReport(movedFiles: moved, failed: failed);
  }

  // --- Reconciliation --------------------------------------------------------

  /// Resolves rows left mid-operation by an interrupted run.
  ///
  /// Runs on every card open, before any scan result is shown, because a row
  /// that says `deleting` describes an operation whose result is only knowable
  /// by looking at the card — and the user must not be shown a library built on
  /// a guess.
  ///
  /// Nothing here deletes anything. Reconciliation observes and records; the
  /// only file it ever removes is an unverified partial copy of its own making,
  /// and even that is quarantined rather than dropped.
  Future<ReconcileReport> reconcile({required String cardRoot}) async {
    final resolved = <String, TrashState>{};
    final lost = <String>[];

    for (final item in await _trash.inFlightItems()) {
      final photo = await _catalog.photoById(item.photoId);
      if (photo == null) continue;
      final cardFile = File(p.join(cardRoot, item.cardRelativePath));
      final onCard = await cardFile.exists();
      final macCopy = item.macTrashPath == null ? null : File(item.macTrashPath!);
      final macExists = macCopy != null && await macCopy.exists();

      final TrashState outcome;
      switch (item.state) {
        case TrashState.deleting:
          // The unlink either happened or it did not, and the card says which.
          outcome = onCard ? TrashState.marked : TrashState.deleted;

        case TrashState.movingToMacTrash:
          if (onCard) {
            // The original is still there, so whatever is on the Mac is at best
            // a duplicate and at worst a partial copy. Quarantined, not
            // deleted: bytes are never thrown away on an inference.
            if (macExists) await _quarantine(macCopy);
            outcome = TrashState.marked;
          } else if (macExists && item.verifiedAt != null) {
            outcome = TrashState.movedToMacTrash;
          } else {
            // The card file is gone and there is no copy known to be good. This
            // is the one case the app cannot make right, and it says so rather
            // than picking a state that sounds better.
            if (macExists) await _quarantine(macCopy);
            lost.add(item.cardRelativePath);
            outcome = TrashState.uncertain;
          }

        case TrashState.restoringToCard:
          outcome = onCard ? TrashState.onCard : TrashState.movedToMacTrash;

        default:
          continue;
      }

      await _trash.commitOutcome(item.id, outcome);
      resolved[item.cardRelativePath] = outcome;
    }

    return ReconcileReport(resolved: resolved, unresolvedLosses: lost);
  }

  /// Moves a copy that cannot be trusted out of the trash tree.
  ///
  /// Kept, and kept findable. It may be most of a photograph, and that is the
  /// user's to judge, not this code's.
  Future<void> _quarantine(File copy) async {
    final destination = File(p.join(
      macTrashRoot.path,
      'quarantine',
      '${DateTime.now().millisecondsSinceEpoch}-${p.basename(copy.path)}',
    ));
    try {
      await destination.parent.create(recursive: true);
      await copy.rename(destination.path);
    } on FileSystemException {
      // Leaving it where it is beats losing it.
    }
  }

  // --- Plumbing --------------------------------------------------------------

  Future<int> _photoId(PhotoEntity photo) async {
    final existing = await _catalog.photoByStableKey(photo.key.value);
    if (existing != null) return existing.id;
    return _catalog.insertPhoto(
      PhotosCompanion.insert(
        cleStable: photo.key.value,
        radicalDcf: photo.dcfPath,
      ),
    );
  }

  static TrashFileKind _kindOf(PhotoFile file) =>
      file.kind == PhotoFileKind.raw ? TrashFileKind.dng : TrashFileKind.jpg;

  /// `DCIM/100LEICA/L1000001.DNG` — relative, because the mount point is not
  /// part of a card file's identity and changes between sessions.
  static String _relativePath(PhotoEntity photo, PhotoFile file) =>
      p.join('DCIM', photo.folder, file.name);
}

/// Why a photograph was not removed.
enum TrashConflictReason {
  /// The file at that path is a different photograph now — the camera's
  /// numbering was reset and it wrote a new frame over the name.
  differentPhotographAtPath,

  /// The Mac copy did not hash to the source, so the original was left alone.
  copyDidNotVerify,

  ioError,
}

class TrashConflict {
  const TrashConflict({
    required this.dcfPath,
    required this.path,
    required this.reason,
    this.detail,
  });

  final String dcfPath;
  final String path;
  final TrashConflictReason reason;
  final String? detail;

  @override
  String toString() => 'TrashConflict($dcfPath, ${reason.name}${detail == null ? '' : ': $detail'})';
}

class EmptyTrashReport {
  const EmptyTrashReport({
    required this.deleted,
    required this.skipped,
    required this.uncertain,
    required this.bytesFreed,
    required this.haltedByVolumeLoss,
  });

  final List<String> deleted;
  final List<TrashConflict> skipped;

  /// Entities whose fate could not be observed, because the card left.
  final List<String> uncertain;

  final int bytesFreed;
  final bool haltedByVolumeLoss;

  bool get isClean => skipped.isEmpty && uncertain.isEmpty;
}

class MoveReport {
  const MoveReport({required this.movedFiles, required this.failed});

  final List<String> movedFiles;
  final List<TrashConflict> failed;

  bool get succeeded => failed.isEmpty && movedFiles.isNotEmpty;
}

class ReconcileReport {
  const ReconcileReport({required this.resolved, required this.unresolvedLosses});

  /// What each interrupted row was resolved to, by card-relative path.
  final Map<String, TrashState> resolved;

  /// Files that are gone from the card with no copy known to be good. The one
  /// outcome the app cannot repair, surfaced loudly rather than smoothed over.
  final List<String> unresolvedLosses;

  bool get isClean => unresolvedLosses.isEmpty;
}
