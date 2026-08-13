import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infra/db/database.dart';
import '../../infra/db/database_provider.dart';
import '../catalog/photo_entity.dart';
import '../grid/grid_screen.dart' show cardCatalogProvider;
import '../settings/settings_store.dart';
import 'mark_store.dart';
import 'trash_service.dart';

final trashServiceProvider = FutureProvider<TrashService>(
  (ref) => TrashService.open(ref.watch(appDatabaseProvider)),
);

/// What is waiting on a decision, live.
final trashSummaryProvider = StreamProvider<TrashSummary>((ref) async* {
  final service = await ref.watch(trashServiceProvider.future);
  yield* service.watchSummary();
});

/// Where a decision is written down.
///
/// Rebuilt when the deletion mode changes, because the mode is half of what
/// "record this" means. Overridden in widget tests, which have no database.
final markStoreProvider = FutureProvider<MarkStore>((ref) async {
  final trash = await ref.watch(trashServiceProvider.future);
  final settings = await ref.watch(settingsProvider.future);
  return TrashMarkStore(trash: trash, mode: settings.deletionMode);
});

/// The photographs marked for deletion, and whether that fact is safe.
///
/// Two things rather than one because they can disagree: the marks are what the
/// user decided, [durable] is whether those decisions reached the disk. A set
/// that quietly stops being written is indistinguishable from one that is
/// being written, and the difference is a whole culling session.
@immutable
class Marks {
  const Marks({this.keys = const {}, this.durable = true, this.failure});

  final Set<String> keys;

  /// False once a write has failed. The session carries on — a decision the
  /// user made is still a decision — but the interface must stop implying it
  /// will survive the app closing.
  final bool durable;

  /// What went wrong, for the trash screen to state.
  final String? failure;

  bool contains(String stableKey) => keys.contains(stableKey);

  int get length => keys.length;

  Marks withKeys(Set<String> next) =>
      Marks(keys: next, durable: durable, failure: failure);

  @override
  bool operator ==(Object other) =>
      other is Marks &&
      other.durable == durable &&
      other.failure == failure &&
      setEquals(other.keys, keys);

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(keys), durable, failure);
}

/// Photographs marked for deletion, held in memory and written through.
///
/// Both halves matter. In memory, because culling is a keyboard activity and
/// the badge has to arrive on the keystroke rather than on the write. Written
/// through, because before this the decisions lived only here: closing the app
/// halfway through nine hundred frames threw away every one of them, on a card
/// that had deliberately not been touched.
///
/// The write is not awaited before the state moves. That is the opposite of the
/// settings screen's rule, and for the opposite reason: a preference that
/// claims to be active when the write failed is telling the user something
/// untrue about the card, whereas a mark is true the moment it is made — what a
/// failed write costs is its survival, and [Marks.durable] is where that is
/// said.
class MarkedForDeletionNotifier extends Notifier<Marks> {
  @override
  Marks build() {
    _hydrate();
    return const Marks();
  }

  Future<void> _hydrate() async {
    try {
      final keys = await (await _store).markedKeys();
      if (keys.isEmpty) return;
      // Merged rather than replaced: a decision made while the read was in
      // flight is as real as one made before it, and arrives here first.
      state = state.withKeys({...state.keys, ...keys});
    } on Object catch (error) {
      _reportFailure(error);
    }
  }

  Future<MarkStore> get _store => ref.read(markStoreProvider.future);

  /// Marks or unmarks [photo], and records the decision.
  ///
  /// Takes the entity rather than its key: what gets written down is every file
  /// of the photograph, and a key alone cannot say which those are.
  Future<MarkReport?> toggle(PhotoEntity photo) async {
    // Refused before the badge moves, and refused again by the store: this
    // mark is about removing a frame from a card, and a photograph read from
    // the Mac has no card path to remove. One predicate, two places that ask
    // it, because a guard that lives in one screen is lost the moment a second
    // screen learns to mark.
    if (!photo.isOnCard) {
      return const MarkReport(MarkEffect.refused, detail: markRefusedOffCard);
    }

    final key = photo.key.value;
    final wasMarked = state.contains(key);
    state = state.withKeys(
      wasMarked ? ({...state.keys}..remove(key)) : {...state.keys, key},
    );

    try {
      final store = await _store;
      final report =
          wasMarked ? await store.unmark(photo) : await store.mark(photo);
      if (report.effect == MarkEffect.refused) {
        // Nothing was written, so nothing is marked: the badge goes back where
        // it was rather than showing a decision the app refused to record.
        state = state.withKeys(
          wasMarked ? {...state.keys, key} : ({...state.keys}..remove(key)),
        );
        return report;
      }
      if (report.effect == MarkEffect.movedOffCard) {
        // The photograph is not on the card any more, so there is nothing left
        // to decide about it — and the catalogue is now describing a card that
        // has changed underneath it.
        state = state.withKeys({...state.keys}..remove(key));
        ref.invalidate(cardCatalogProvider);
      }
      if (!state.durable) state = Marks(keys: state.keys);
      return report;
    } on Object catch (error) {
      _reportFailure(error);
      return null;
    }
  }

  /// Takes the mark back off each of [photos].
  ///
  /// What "Restore All" does, and it is given the photographs on screen rather
  /// than told to clear the table: marks are durable and the table spans every
  /// card this Mac has culled, so a button under a list of eleven frames must
  /// not quietly undo a decision made about a card that is in a drawer.
  ///
  /// Touches no file on the card, because marking never touched one either.
  Future<void> unmark(Iterable<PhotoEntity> photos) async {
    state = state.withKeys(
      {...state.keys}..removeAll(photos.map((p) => p.key.value)),
    );
    try {
      final store = await _store;
      for (final photo in photos) {
        await store.unmark(photo);
      }
      if (!state.durable) state = Marks(keys: state.keys);
    } on Object catch (error) {
      _reportFailure(error);
    }
  }

  /// Drops marks whose rows have already moved on, without writing anything.
  ///
  /// What Empty Trash leaves behind: every one of those photographs now has a
  /// row saying `deleted` or `uncertain`, so there is no mark left to take off
  /// — only a badge still being drawn over a decision that has been carried
  /// out. Writing here would put the marks back.
  void forget(Iterable<String> stableKeys) {
    final next = {...state.keys}..removeAll(stableKeys);
    if (next.length != state.keys.length) state = state.withKeys(next);
  }

  /// The marks stand; what is lost is the promise that they will still be there
  /// next launch. Said rather than swallowed.
  void _reportFailure(Object error) {
    state = Marks(keys: state.keys, durable: false, failure: '$error');
  }
}

final markedForDeletionProvider =
    NotifierProvider<MarkedForDeletionNotifier, Marks>(
  MarkedForDeletionNotifier.new,
);
