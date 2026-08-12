import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infra/db/database.dart';
import '../../infra/db/database_provider.dart';
import '../catalog/photo_entity.dart';

/// Where "I want this one" is written down.
///
/// The mirror of the deletion mark, and kept the same way for the same reason:
/// culling is one pass over nine hundred frames in which two decisions are
/// being made, and a decision that lives only in memory is one the app throws
/// away when it closes.
abstract interface class ExportMarkStore {
  /// Every photograph still waiting to be exported.
  Future<Set<String>> markedKeys();

  Future<void> mark(PhotoEntity photo);

  Future<void> unmark(PhotoEntity photo);
}

class DriftExportMarkStore implements ExportMarkStore {
  DriftExportMarkStore(this._db);

  final AppDatabase _db;

  @override
  Future<Set<String>> markedKeys() => _db.compositionDao.markedForExport();

  @override
  Future<void> mark(PhotoEntity photo) async {
    final id = await _db.catalogDao.photoIdFor(
      cleStable: photo.key.value,
      radicalDcf: photo.dcfPath,
    );
    await _db.compositionDao.markForExport(id);
  }

  @override
  Future<void> unmark(PhotoEntity photo) async {
    final existing = await _db.catalogDao.photoByStableKey(photo.key.value);
    if (existing == null) return;
    await _db.compositionDao.unmarkForExport(existing.id);
  }
}

/// A queue that lives no longer than the test that made it.
@visibleForTesting
class InMemoryExportMarkStore implements ExportMarkStore {
  InMemoryExportMarkStore({Set<String> initial = const {}})
      : _keys = {...initial};

  final Set<String> _keys;

  @override
  Future<Set<String>> markedKeys() async => {..._keys};

  @override
  Future<void> mark(PhotoEntity photo) async => _keys.add(photo.key.value);

  @override
  Future<void> unmark(PhotoEntity photo) async => _keys.remove(photo.key.value);
}

/// Overridden in widget tests, which have no database.
final exportMarkStoreProvider = Provider<ExportMarkStore>(
  (ref) => DriftExportMarkStore(ref.watch(appDatabaseProvider)),
);

/// The photographs waiting to be exported, and whether that fact is safe.
///
/// The same shape as `Marks`, and for the same reason: what the user decided
/// and whether it reached the disk are two facts that can disagree, and only
/// one of them is worth showing in grey.
@immutable
class ExportQueue {
  const ExportQueue({this.keys = const {}, this.durable = true, this.failure});

  final Set<String> keys;
  final bool durable;
  final String? failure;

  bool contains(String stableKey) => keys.contains(stableKey);

  int get length => keys.length;

  bool get isEmpty => keys.isEmpty;

  ExportQueue withKeys(Set<String> next) =>
      ExportQueue(keys: next, durable: durable, failure: failure);

  @override
  bool operator ==(Object other) =>
      other is ExportQueue &&
      other.durable == durable &&
      other.failure == failure &&
      setEquals(other.keys, keys);

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(keys), durable, failure);
}

/// Marking a photograph as wanted, held in memory and written through.
///
/// Both halves for the reason marking for deletion has both: the badge has to
/// arrive on the keystroke, and the decision has to still be there tomorrow.
class ExportMarksNotifier extends Notifier<ExportQueue> {
  @override
  ExportQueue build() {
    _hydrate();
    return const ExportQueue();
  }

  Future<ExportMarkStore> get _store async => ref.read(exportMarkStoreProvider);

  Future<void> _hydrate() async {
    try {
      final keys = await (await _store).markedKeys();
      if (keys.isEmpty || !ref.mounted) return;
      // Merged rather than replaced: a decision made while the read was in
      // flight is as real as one made before it.
      state = state.withKeys({...state.keys, ...keys});
    } on Object catch (error) {
      _reportFailure(error);
    }
  }

  Future<void> toggle(PhotoEntity photo) async {
    final key = photo.key.value;
    final wasMarked = state.contains(key);
    state = state.withKeys(
      wasMarked ? ({...state.keys}..remove(key)) : {...state.keys, key},
    );

    try {
      final store = await _store;
      if (wasMarked) {
        await store.unmark(photo);
      } else {
        await store.mark(photo);
      }
      if (!ref.mounted) return;
      if (!state.durable) state = ExportQueue(keys: state.keys);
    } on Object catch (error) {
      _reportFailure(error);
    }
  }

  /// Takes the mark off a photograph that has just been exported.
  ///
  /// The queue is a list of work, not a permanent attribute: what is left after
  /// the file is written is the file, and the row that says where it came from.
  Future<void> clear(PhotoEntity photo) async {
    if (!state.contains(photo.key.value)) return;
    await toggle(photo);
  }

  void _reportFailure(Object error) {
    if (!ref.mounted) return;
    state = ExportQueue(keys: state.keys, durable: false, failure: '$error');
  }
}

final exportMarksProvider =
    NotifierProvider<ExportMarksNotifier, ExportQueue>(ExportMarksNotifier.new);
