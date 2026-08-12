import 'package:meta/meta.dart';

import '../catalog/photo_entity.dart';
import '../settings/settings_store.dart';
import 'trash_service.dart';

/// What recording a decision actually did.
enum MarkEffect {
  /// A row on the Mac, and nothing else. The card was not touched — the
  /// ordinary case, and the whole point of deferred mode.
  recorded,

  /// The originals were copied to the Mac, verified, and only then removed from
  /// the card. The photograph has left the catalogue.
  movedOffCard,

  /// The mark is gone. Nothing was on the card to undo, because marking never
  /// put anything there.
  withdrawn,
}

/// The outcome of one decision, in the terms the interface has to report it.
@immutable
class MarkReport {
  const MarkReport(this.effect, {this.detail});

  final MarkEffect effect;

  /// Present when something did not go as the mode promised — a card write that
  /// was refused, most often. Written for a photographer to read.
  final String? detail;

  bool get isClean => detail == null;
}

/// Where a culling decision is written down so it outlives the session.
///
/// An interface rather than a direct call to [TrashService] for two reasons:
/// the deletion mode changes what "record this decision" means, and a widget
/// test has no database and should still be able to exercise the grid.
abstract interface class MarkStore {
  /// Every mark still standing, read once at startup.
  Future<Set<String>> markedKeys();

  Future<MarkReport> mark(PhotoEntity photo);

  Future<MarkReport> unmark(PhotoEntity photo);
}

/// Marking, backed by the durable trash and obeying the chosen deletion mode.
class TrashMarkStore implements MarkStore {
  const TrashMarkStore({required this.trash, required this.mode});

  final TrashService trash;
  final DeletionMode mode;

  @override
  Future<Set<String>> markedKeys() => trash.markedKeys();

  /// Records the decision, and in immediate mode acts on it at once.
  ///
  /// The row goes down first in both modes. In deferred mode it is the whole of
  /// what happens; in immediate mode it is the durable intent the move is about
  /// to act on, and a crash between the two leaves a mark — the survivable half
  /// of the pair, because a mark can be looked at again and a half-copied
  /// photograph cannot.
  @override
  Future<MarkReport> mark(PhotoEntity photo) async {
    await trash.mark(photo);
    if (mode == DeletionMode.deferred) {
      return const MarkReport(MarkEffect.recorded);
    }

    final report = await trash.moveToMacTrash(photo);
    if (report.succeeded) return const MarkReport(MarkEffect.movedOffCard);

    // The photograph is still on the card and still marked. That is the state
    // the move leaves behind when it refuses, and saying "deleted" over it
    // would be the one kind of lie this app cannot afford.
    return MarkReport(
      MarkEffect.recorded,
      detail: report.failed.isEmpty
          ? 'La photographie est restée sur la carte.'
          : 'La photographie est restée sur la carte : '
              '${_describe(report.failed.first)}',
    );
  }

  @override
  Future<MarkReport> unmark(PhotoEntity photo) async {
    await trash.unmark(photo);
    return const MarkReport(MarkEffect.withdrawn);
  }
}

/// Marking with nothing behind it.
///
/// For widget tests, which have no application-support directory to open a
/// database in. Never used in the application: a silent in-memory fallback for
/// a store that failed to open would make the app claim a durability it does
/// not have, which is the failure this class exists to avoid pretending about.
@visibleForTesting
class InMemoryMarkStore implements MarkStore {
  InMemoryMarkStore({Set<String> initial = const {}}) : _keys = {...initial};

  final Set<String> _keys;

  /// Every call made, in order, so a test can assert that the decision was
  /// written at the moment it was made rather than at the end.
  final List<String> calls = <String>[];

  @override
  Future<Set<String>> markedKeys() async => {..._keys};

  @override
  Future<MarkReport> mark(PhotoEntity photo) async {
    calls.add('mark:${photo.key.value}');
    _keys.add(photo.key.value);
    return const MarkReport(MarkEffect.recorded);
  }

  @override
  Future<MarkReport> unmark(PhotoEntity photo) async {
    calls.add('unmark:${photo.key.value}');
    _keys.remove(photo.key.value);
    return const MarkReport(MarkEffect.withdrawn);
  }
}

String _describe(TrashConflict conflict) =>
    conflict.detail ??
    switch (conflict.reason) {
      TrashConflictReason.differentPhotographAtPath =>
        'le fichier à ce nom est une autre photographie',
      TrashConflictReason.copyDidNotVerify =>
        'la copie sur le Mac n\'a pas été vérifiée',
      TrashConflictReason.nameTakenByAnotherPhotograph =>
        'ce nom DCF est pris par une autre photographie',
      TrashConflictReason.cameraFolderGone => 'le dossier de l\'appareil a disparu',
      TrashConflictReason.ioError => 'la carte a refusé l\'opération',
    };
