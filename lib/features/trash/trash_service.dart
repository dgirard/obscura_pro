import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:meta/meta.dart';
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
  TrashService({
    required AppDatabase db,
    required this.macTrashRoot,
    this.onStep,
    this.unlinkOverride,
    this.copyOverride,
  }) : _db = db;

  /// Called at every boundary between a durable write and a card operation.
  ///
  /// Exists so the fault-injection suite can stop a run exactly where a crash
  /// would, at each of the points the KTD-14 ordering is designed around.
  /// Production leaves it null and pays nothing for it.
  @visibleForTesting
  final void Function(String step)? onStep;

  /// Stand-ins for the two card operations, for tests only.
  ///
  /// A vanished volume is the failure this class is built around and the one it
  /// cannot be made to produce on demand: [volumeRootOf] only recognises a path
  /// under `/Volumes`, and a test cannot mount and pull a real card. Without a
  /// seam here the `VolumeGone` arms of every switch below are unreachable from
  /// the suite — which is exactly how a cast that throws on that path, and a
  /// missing `break` after it, both survived review. Production leaves these
  /// null and calls the real functions directly.
  @visibleForTesting
  final Future<UnlinkOutcome> Function(File file)? unlinkOverride;

  @visibleForTesting
  final Future<CopyOutcome> Function({
    required File source,
    required File destination,
    String? tempName,
  })? copyOverride;

  void _step(String name) => onStep?.call(name);

  Future<UnlinkOutcome> _unlink(File file) =>
      (unlinkOverride ?? verifiedUnlink)(file);

  Future<CopyOutcome> _copy({
    required File source,
    required File destination,
    String? tempName,
  }) =>
      (copyOverride ?? copyVerified)(
        source: source,
        destination: destination,
        tempName: tempName,
      );

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

  /// Every mark still standing, by stable key.
  ///
  /// This is what a relaunch reads: the decisions of an interrupted culling
  /// session, restored to the grid without the card having been touched by any
  /// of them.
  Future<Set<String>> markedKeys() => _trash.markedStableKeys();

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

        _step('empty.beforeIntent');
        await _trash.recordIntent(item.id, TrashState.deleting);
        _step('empty.beforeUnlink');
        final outcome = await _unlink(File(file.path));
        _step('empty.beforeOutcome');

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

        // The doc above promises this stops the moment the volume goes away,
        // and this is where it keeps that promise. Without it the sibling file
        // of a RAW+JPG pair records an intent and retries an unlink against a
        // card already known to be gone, and the same photograph is counted
        // uncertain once per file.
        if (stoppedEarly) break;
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

      _step('move.beforeIntent');
      await _trash.recordIntent(item.id, TrashState.movingToMacTrash);
      _step('move.beforeCopy');
      final copy = await _copy(source: File(file.path), destination: destination);
      _step('move.beforeUnlink');

      switch (copy) {
        case CopyVerified(:final path, :final hash):
          final unlink = await _unlink(File(file.path));
          _step('move.beforeOutcome');
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
        case CopyVolumeGone():
          // The card left mid-copy. Nothing can be observed about it, so the
          // row says so and the original is presumed still there — which is the
          // truthful answer, because no unlink was reached.
          await _trash.commitOutcome(item.id, TrashState.uncertain);
          failed.add(TrashConflict(
            dcfPath: photo.dcfPath,
            path: file.path,
            reason: TrashConflictReason.ioError,
            detail: 'la carte a disparu pendant la copie',
          ));
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

  // --- Restoring to the card -------------------------------------------------

  /// Puts rescued originals back where the camera had them.
  ///
  /// The only path in this app that writes a photograph to a card, and it is
  /// deliberately narrow. Three things it will not do:
  ///
  /// * **Rename.** R19 forbids it outright, so when the DCF name is taken by a
  ///   different photograph the restore is not merely awkward, it is
  ///   impossible. The entity is left in the Mac trash and the conflict is
  ///   reported, for the user to export somewhere of their choosing.
  /// * **Create a camera folder.** If `100LEICA/` is gone the card has been
  ///   reformatted or is a different card; making the directory would be this
  ///   app inventing DCF structure, which is exactly what R19 exists to stop.
  /// * **Remove the Mac copy before the card write is verified.** The rescued
  ///   bytes are the only copy there is until the new one has been read back
  ///   and hashed.
  Future<RestoreReport> restoreToCard({required String cardRoot}) async {
    final restored = <String>[];
    final conflicts = <TrashConflict>[];

    for (final item in await _trash.itemsInState(TrashState.movedToMacTrash)) {
      final photoRow = await _catalog.photoById(item.photoId);
      final macPath = item.macTrashPath;
      if (photoRow == null || macPath == null) continue;

      final macCopy = File(macPath);
      final target = File(p.join(cardRoot, item.cardRelativePath));

      if (!await macCopy.exists()) {
        conflicts.add(TrashConflict(
          dcfPath: photoRow.radicalDcf,
          path: macPath,
          reason: TrashConflictReason.copyDidNotVerify,
          detail: 'the rescued copy is no longer on the Mac',
        ));
        continue;
      }

      if (!await target.parent.exists()) {
        conflicts.add(TrashConflict(
          dcfPath: photoRow.radicalDcf,
          path: target.path,
          reason: TrashConflictReason.cameraFolderGone,
        ));
        continue;
      }

      if (await target.exists()) {
        final occupant = await stableKeyOfFile(
          target.path,
          dcfRadical: photoRow.radicalDcf,
        );
        if (occupant != null && occupant.value == photoRow.cleStable) {
          // Already back — an interrupted earlier restore that got as far as
          // the rename. Finish the bookkeeping and remove the Mac copy.
          await _finishRestore(item.id, macCopy);
          restored.add(photoRow.radicalDcf);
        } else {
          conflicts.add(TrashConflict(
            dcfPath: photoRow.radicalDcf,
            path: target.path,
            reason: TrashConflictReason.nameTakenByAnotherPhotograph,
          ));
        }
        continue;
      }

      _step('restore.beforeIntent');
      await _trash.recordIntent(item.id, TrashState.restoringToCard);
      _step('restore.beforeWrite');
      final copy = await _copy(
        source: macCopy,
        destination: target,
        tempName: cardTempNameFor(p.basename(target.path)),
      );
      _step('restore.beforeOutcome');

      switch (copy) {
        case CopyVerified(:final hash):
          // Belt and braces: the copy verified against the source it was made
          // from, and the source verifies against the hash recorded when the
          // original left the card. Both, or the Mac copy stays.
          if (item.sourceHash != null && item.sourceHash != hash) {
            // Take the card write back — and observe that it went, rather than
            // assuming it did. Committing `movedToMacTrash` on the strength of
            // an unlink nobody looked at would leave an unverified file sitting
            // at a DCF name while the database swore the card was clean, and
            // the row would no longer be in flight for reconcile to catch.
            final removed = await _unlink(target);
            switch (removed) {
              case Unlinked() || AlreadyAbsent():
                await _trash.commitOutcome(item.id, TrashState.movedToMacTrash);
                conflicts.add(TrashConflict(
                  dcfPath: photoRow.radicalDcf,
                  path: target.path,
                  reason: TrashConflictReason.copyDidNotVerify,
                  detail: 'la copie sauvée ne correspond plus à ce qui a quitté la carte',
                ));
              case UnlinkFailed() || VolumeGone():
                // The rescued original is still on the Mac, so nothing is lost;
                // what cannot be claimed is that the card is as it was.
                await _trash.commitOutcome(item.id, TrashState.uncertain);
                conflicts.add(TrashConflict(
                  dcfPath: photoRow.radicalDcf,
                  path: target.path,
                  reason: TrashConflictReason.ioError,
                  detail: 'un fichier non vérifié est resté sur la carte : '
                      'la copie d\'origine reste sur le Mac',
                ));
            }
            continue;
          }
          await _finishRestore(item.id, macCopy);
          restored.add(photoRow.radicalDcf);
        case CopyCorrupt():
          await _trash.commitOutcome(item.id, TrashState.movedToMacTrash);
          conflicts.add(TrashConflict(
            dcfPath: photoRow.radicalDcf,
            path: target.path,
            reason: TrashConflictReason.copyDidNotVerify,
          ));
        case CopySourceMissing():
        case CopyVolumeGone():
        case CopyFailed():
          // In every one of these the card write did not complete, so the Mac
          // copy remains the only copy and the row goes back to saying so.
          await _trash.commitOutcome(item.id, TrashState.movedToMacTrash);
          conflicts.add(TrashConflict(
            dcfPath: photoRow.radicalDcf,
            path: target.path,
            reason: TrashConflictReason.ioError,
          ));
      }
    }

    return RestoreReport(restored: restored, conflicts: conflicts);
  }

  /// Records the card copy as authoritative and lets the Mac copy go.
  ///
  /// In that order, and never the reverse: the row is written first because a
  /// crash between the two leaves a duplicate, while the reverse leaves nothing.
  Future<void> _finishRestore(int itemId, File macCopy) async {
    await _trash.commitOutcome(itemId, TrashState.onCard);
    await _unlink(macCopy);
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

  Future<int> _photoId(PhotoEntity photo) => _catalog.photoIdFor(
        cleStable: photo.key.value,
        radicalDcf: photo.dcfPath,
      );

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

  /// The DCF name is taken by a different photograph. Restoring would mean
  /// renaming, which R19 forbids, so it is not awkward — it is impossible.
  nameTakenByAnotherPhotograph,

  /// The camera folder is gone. Creating it would be this app inventing DCF
  /// structure on a card, which is what R19 exists to prevent.
  cameraFolderGone,

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

class RestoreReport {
  const RestoreReport({required this.restored, required this.conflicts});

  final List<String> restored;

  /// Entities that could not go back. Each keeps its Mac copy: the only answer
  /// left is for the user to export it somewhere of their choosing.
  final List<TrashConflict> conflicts;

  bool get isClean => conflicts.isEmpty;
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
