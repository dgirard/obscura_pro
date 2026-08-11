/// Turning a `FileSystemException` into something the app can act on and the
/// user can understand (R22, CARTE-5, spec section 9).
///
/// The distinctions here are not cosmetic. A vanished card and a read-only card
/// both make a write fail, and they call for opposite responses: one stops
/// everything in flight and flags it uncertain, the other means no destructive
/// operation should have been offered in the first place. Collapsing them into
/// "an error occurred" is how an app ends up telling a photographer their card
/// is broken when they have merely left the write-protect switch on.
library;

import 'dart:io';

import 'atomic_ops.dart';

enum CardFailureKind {
  /// The volume is not there any more.
  volumeGone,

  /// The card is mounted read-only — the physical switch on an SD card, or a
  /// file system the system refused to mount for writing.
  readOnly,

  /// The sandbox has no grant for this path.
  notPermitted,

  /// A read or write failed at the medium. On a camera card this usually means
  /// the card itself is failing.
  mediumError,

  /// Something is holding the file.
  busy,

  other,
}

class CardFailure {
  const CardFailure({required this.kind, required this.path, required this.detail});

  final CardFailureKind kind;
  final String path;
  final String detail;

  /// Whether the operation in flight must stop entirely rather than skip this
  /// file and carry on. Nothing can be observed about a card that is not there,
  /// so nothing may be claimed about it.
  bool get halts => kind == CardFailureKind.volumeGone;

  /// Whether every destructive action should be disabled while this holds.
  bool get disablesWriting =>
      kind == CardFailureKind.readOnly || kind == CardFailureKind.notPermitted;

  /// A sentence for the user, in the terms of what they can do about it.
  String get message => switch (kind) {
        CardFailureKind.volumeGone =>
          'La carte a été retirée. L\'opération est arrêtée ; réinsérez-la pour '
              'que l\'app vérifie ce qui a été fait.',
        CardFailureKind.readOnly =>
          'La carte est en lecture seule. Vérifiez le petit loquet sur le côté '
              'de la carte SD.',
        CardFailureKind.notPermitted =>
          'macOS n\'a pas accordé l\'accès à cet emplacement. Rouvrez la carte '
              'depuis le sélecteur.',
        CardFailureKind.mediumError =>
          'La carte a signalé une erreur de lecture. Copiez ce qui est encore '
              'lisible avant toute autre opération.',
        CardFailureKind.busy =>
          'Un autre programme utilise ce fichier.',
        CardFailureKind.other => detail,
      };

  @override
  String toString() => 'CardFailure(${kind.name} at $path: $detail)';
}

/// Classifies [error], using [path] to tell a missing file apart from a missing
/// card.
///
/// The errno is the primary signal and the volume check is the tie-breaker,
/// because a pulled card produces several different codes depending on where in
/// the stack the request died — and `ENOENT` from a path whose volume root has
/// gone means something very different from `ENOENT` on a card still mounted.
CardFailure classifyCardFailure(FileSystemException error, {String? path}) {
  final target = path ?? error.path ?? '';
  final code = error.osError?.errorCode;
  final detail = error.osError?.message ?? error.message;

  final root = volumeRootOf(target);
  final volumeGone = root != null && !Directory(root).existsSync();

  final kind = switch (code) {
    _ when volumeGone => CardFailureKind.volumeGone,
    // ENXIO, ENODEV — the device behind the mount is gone.
    6 || 19 => CardFailureKind.volumeGone,
    // EROFS
    30 => CardFailureKind.readOnly,
    // EACCES, EPERM
    13 || 1 => CardFailureKind.notPermitted,
    // EIO
    5 => CardFailureKind.mediumError,
    // EBUSY, ETXTBSY
    16 || 26 => CardFailureKind.busy,
    _ => CardFailureKind.other,
  };

  return CardFailure(kind: kind, path: target, detail: detail);
}

/// Whether the card at [cardRoot] can be written to at all.
///
/// Asked once, when the card opens, so the trash and its buttons can be
/// disabled rather than offered and then failing. The probe writes a file with
/// the reserved prefix and removes it: it cannot be mistaken for a photograph,
/// and if the app dies between the two the card-safety pass recognises it as
/// ours and clears it.
///
/// A read-only card is a supported way to use this app — reviewing a card you
/// do not intend to change is a perfectly good session — so this is a question,
/// not a check that fails.
Future<bool> cardAcceptsWrites(String cardRoot) async {
  final probe = File('$cardRoot/${cardTempNameFor('WRITE-PROBE')}');
  try {
    await probe.writeAsString('', flush: true);
    await probe.delete();
    return true;
  } on FileSystemException {
    try {
      if (await probe.exists()) await probe.delete();
    } on FileSystemException {
      // If it cannot be removed it cannot have been written either.
    }
    return false;
  }
}
