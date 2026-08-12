import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'trash_dao.g.dart';

/// What the trash screen and the status bar show: how many files are still
/// waiting on a decision, and how many bytes that represents.
class TrashSummary {
  const TrashSummary({
    required this.fileCount,
    required this.photoCount,
    required this.pendingBytes,
  });

  final int fileCount;
  final int photoCount;
  final int pendingBytes;

  static const empty = TrashSummary(fileCount: 0, photoCount: 0, pendingBytes: 0);

  @override
  bool operator ==(Object other) =>
      other is TrashSummary &&
      other.fileCount == fileCount &&
      other.photoCount == photoCount &&
      other.pendingBytes == pendingBytes;

  @override
  int get hashCode => Object.hash(fileCount, photoCount, pendingBytes);

  @override
  String toString() =>
      'TrashSummary(files: $fileCount, photos: $photoCount, bytes: $pendingBytes)';
}

/// The deletion state machine's only writer of DB state (KTD-14).
///
/// Every method here is one half of an intent/outcome pair: nothing in this
/// class touches the filesystem, and the card operation always happens between
/// two calls, never inside one.
@DriftAccessor(tables: [TrashItems, Photos])
class TrashDao extends DatabaseAccessor<AppDatabase> with _$TrashDaoMixin {
  TrashDao(super.db);

  /// States that still owe the user a decision or a repair. `onCard` is not
  /// pending (nothing was asked) and `deleted` is not pending (nothing is left).
  static const pendingStates = <TrashState>[
    TrashState.marked,
    TrashState.movingToMacTrash,
    TrashState.movedToMacTrash,
    TrashState.restoringToCard,
    TrashState.deleting,
    TrashState.uncertain,
  ];

  Future<int> upsertItem(TrashItemsCompanion item) => into(trashItems).insert(
        item,
        onConflict: DoUpdate((_) => item, target: [trashItems.photoId, trashItems.fileKind]),
      );

  Future<List<TrashItem>> itemsOfPhoto(int photoId) =>
      (select(trashItems)..where((t) => t.photoId.equals(photoId))).get();

  Future<List<TrashItem>> itemsInState(TrashState state) =>
      (select(trashItems)..where((t) => t.state.equalsValue(state))).get();

  /// Records the intent to run a card operation. Must be awaited -- and, on a
  /// file-backed database, durable -- before the operation starts.
  Future<int> recordIntent(int itemId, TrashState intent) =>
      (update(trashItems)..where((t) => t.id.equals(itemId))).write(
        TrashItemsCompanion(state: Value(intent), updatedAt: Value(DateTime.now())),
      );

  /// Commits the outcome of a card operation that has already been observed on
  /// disk. [sourceHash] and [verifiedAt] are only ever written here, so an
  /// unverified copy can never look verified.
  Future<int> commitOutcome(
    int itemId,
    TrashState outcome, {
    String? sourceHash,
    DateTime? verifiedAt,
    String? macTrashPath,
  }) =>
      (update(trashItems)..where((t) => t.id.equals(itemId))).write(
        TrashItemsCompanion(
          state: Value(outcome),
          sourceHash: sourceHash == null ? const Value.absent() : Value(sourceHash),
          verifiedAt: verifiedAt == null ? const Value.absent() : Value(verifiedAt),
          macTrashPath: macTrashPath == null ? const Value.absent() : Value(macTrashPath),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Rows left in an in-flight intent state by an interrupted run; startup
  /// reconciliation resolves each of these by observing the files.
  Future<List<TrashItem>> inFlightItems() => (select(trashItems)
        ..where((t) => t.state.isInValues([
              TrashState.movingToMacTrash,
              TrashState.restoringToCard,
              TrashState.deleting,
            ])))
      .get();

  /// Stable keys of every photograph currently marked.
  ///
  /// Joined rather than looked up a row at a time: this is what a relaunch
  /// reads to restore a session's decisions, and a photographer who marked four
  /// hundred frames should not pay four hundred queries before the grid draws.
  ///
  /// A RAW+JPG pair contributes two rows and one key, which is the right count:
  /// the mark belongs to the photograph, not to its files.
  Future<Set<String>> markedStableKeys() async {
    final query = select(trashItems).join([
      innerJoin(photos, photos.id.equalsExp(trashItems.photoId)),
    ])
      ..where(trashItems.state.equalsValue(TrashState.marked));
    final rows = await query.get();
    return {for (final row in rows) row.readTable(photos).cleStable};
  }

  /// Photo ids the grid must badge as marked. Reactive: the badge has to clear
  /// the instant the mark is undone, without the grid asking again.
  Stream<Set<int>> watchMarkedPhotoIds() {
    final query = selectOnly(trashItems, distinct: true)
      ..addColumns([trashItems.photoId])
      ..where(trashItems.state.equalsValue(TrashState.marked));
    return query
        .map((row) => row.read(trashItems.photoId)!)
        .watch()
        .map((ids) => ids.toSet());
  }

  /// What the trash screen binds to. Counts only [pendingStates], so bytes
  /// stop being "pending" the moment their file is really gone.
  Stream<TrashSummary> watchTrashSummary() {
    final fileCount = trashItems.id.count();
    final photoCount = trashItems.photoId.count(distinct: true);
    final bytes = trashItems.byteSize.sum();
    final query = selectOnly(trashItems)
      ..addColumns([fileCount, photoCount, bytes])
      ..where(trashItems.state.isInValues(pendingStates));
    return query.watchSingle().map(
          (row) => TrashSummary(
            fileCount: row.read(fileCount) ?? 0,
            photoCount: row.read(photoCount) ?? 0,
            pendingBytes: row.read(bytes) ?? 0,
          ),
        );
  }
}
