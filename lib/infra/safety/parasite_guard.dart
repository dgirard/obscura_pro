/// Keeping the card free of everything the Mac would like to leave on it
/// (R20, CARTE-2).
///
/// The requirement is "zero parasite files", and the measured card says that
/// cannot be met by the app simply declining to write: macOS created
/// `.fseventsd/fseventsd-uuid` at mount time, before this app was involved at
/// all. So the guarantee has two halves — never adding to the mess, and being
/// able to clear it before the card goes back in the camera — and this file is
/// the second half.
///
/// Nothing here removes anything on its own. Finding and removing are separate
/// calls, and the removal takes the exact list it was given. A cleaner that
/// walks a card deciding for itself what is rubbish is one bug away from
/// deleting a photograph.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'atomic_ops.dart';

/// Names macOS and other systems leave on removable media.
///
/// Exact names and one prefix. Matching by pattern beyond this would be
/// guessing, and the cost of a wrong guess on a camera card is a lost frame.
const Set<String> kParasiteNames = {
  '.DS_Store',
  '.Spotlight-V100',
  '.fseventsd',
  '.Trashes',
  '.TemporaryItems',
  '.DocumentRevisions-V100',
  '.TrashCanary',
  '.apdisk',
};

/// AppleDouble resource forks, written when a Mac copies to a file system that
/// cannot hold extended attributes — which exFAT cannot.
const String kAppleDoublePrefix = '._';

/// Folders this app will not descend into, whatever is in them.
///
/// `PRIVATE/` is the camera's own bookkeeping — its index and fastload files.
/// The origin spec said the body writes no annex files; the real card says
/// otherwise, and either way it is not ours to read or repair.
const Set<String> kUntouchableFolders = {'PRIVATE'};

enum ParasiteKind {
  /// Debris this app left: an interrupted card write, recognisable by the
  /// reserved temp prefix. The one kind that is removed without asking.
  ourOwnDebris,

  /// A dotfile the operating system left.
  foreign,
}

class Parasite {
  const Parasite({
    required this.path,
    required this.relativePath,
    required this.kind,
    required this.bytes,
    required this.isDirectory,
    this.removable = true,
  });

  final String path;
  final String relativePath;
  final ParasiteKind kind;
  final int bytes;
  final bool isDirectory;

  /// False for anything inside a folder this app will not touch. Reported
  /// anyway: a photographer deserves to know what is on their card even when
  /// the answer is "and I will not deal with it".
  final bool removable;

  @override
  String toString() => 'Parasite($relativePath, ${kind.name})';
}

class ParasiteReport {
  const ParasiteReport({required this.found, required this.scanned});

  final List<Parasite> found;
  final int scanned;

  Iterable<Parasite> get ourOwnDebris =>
      found.where((f) => f.kind == ParasiteKind.ourOwnDebris);
  Iterable<Parasite> get foreign =>
      found.where((f) => f.kind == ParasiteKind.foreign);

  int get totalBytes => found.fold(0, (sum, f) => sum + f.bytes);
  bool get isClean => found.isEmpty;
}

class CleanupReport {
  const CleanupReport({required this.removed, required this.refused});

  final List<String> removed;

  /// Paths that were asked for and not removed, with why.
  final Map<String, String> refused;

  bool get isClean => refused.isEmpty;
}

/// Finds what should not be on the card. Removes nothing.
class ParasiteGuard {
  const ParasiteGuard();

  /// Walks the card and reports every parasite.
  ///
  /// Read-only, and safe to run on every card open. `PRIVATE/` is listed but
  /// never entered: its contents are reported as unremovable rather than
  /// pretended away.
  Future<ParasiteReport> scan(String cardRoot) async {
    final found = <Parasite>[];
    var scanned = 0;

    Future<void> walk(Directory directory, {required bool removable}) async {
      final List<FileSystemEntity> entries;
      try {
        entries = await directory.list(followLinks: false).toList();
      } on FileSystemException {
        // An unreadable directory is not a parasite and not this pass's
        // problem; the scan reports what it could see.
        return;
      }

      for (final entry in entries) {
        scanned++;
        final name = p.basename(entry.path);
        final relative = p.relative(entry.path, from: cardRoot);
        final isDirectory = entry is Directory;

        if (_isParasiteName(name)) {
          found.add(Parasite(
            path: entry.path,
            relativePath: relative,
            kind: isCardTempName(name)
                ? ParasiteKind.ourOwnDebris
                : ParasiteKind.foreign,
            bytes: isDirectory ? 0 : await _sizeOf(entry),
            isDirectory: isDirectory,
            removable: removable,
          ));
          // Not descended into: the whole thing goes or nothing does.
          continue;
        }

        if (isDirectory) {
          await walk(
            entry,
            removable: removable && !kUntouchableFolders.contains(name),
          );
        }
      }
    }

    await walk(Directory(cardRoot), removable: true);
    return ParasiteReport(found: found, scanned: scanned);
  }

  /// Removes the debris this app itself left behind.
  ///
  /// Runs on card open, before the catalogue scan and before the user can ask
  /// for anything. It is the only removal that happens without being asked for,
  /// and it is limited to names carrying the reserved prefix — files that
  /// cannot be camera output and can only have come from an interrupted write
  /// of ours.
  Future<CleanupReport> removeOwnDebris(String cardRoot) async {
    final report = await scan(cardRoot);
    return remove(report.ourOwnDebris.toList());
  }

  /// Removes exactly the parasites given, and nothing else.
  ///
  /// Takes a list rather than a card path on purpose: the caller has shown the
  /// user what will go, and this must remove that and not whatever a second
  /// walk happens to turn up in between.
  Future<CleanupReport> remove(List<Parasite> parasites) async {
    final removed = <String>[];
    final refused = <String, String>{};

    for (final parasite in parasites) {
      if (!parasite.removable) {
        refused[parasite.relativePath] =
            'inside a folder this app does not touch';
        continue;
      }
      if (!_isParasiteName(p.basename(parasite.path))) {
        // Belt and braces against a caller handing over a photograph.
        refused[parasite.relativePath] = 'not a parasite name';
        continue;
      }

      try {
        if (parasite.isDirectory) {
          await Directory(parasite.path).delete(recursive: true);
          removed.add(parasite.relativePath);
        } else {
          final outcome = await verifiedUnlink(File(parasite.path));
          switch (outcome) {
            case Unlinked():
            case AlreadyAbsent():
              removed.add(parasite.relativePath);
            case VolumeGone():
              refused[parasite.relativePath] = 'the card went away';
            case UnlinkFailed(:final reason):
              refused[parasite.relativePath] = reason;
          }
        }
      } on FileSystemException catch (error) {
        refused[parasite.relativePath] = error.message;
      }
    }

    return CleanupReport(removed: removed, refused: refused);
  }

  static bool _isParasiteName(String name) =>
      kParasiteNames.contains(name) ||
      name.startsWith(kAppleDoublePrefix) ||
      isCardTempName(name);

  static Future<int> _sizeOf(FileSystemEntity entry) async {
    try {
      return (await entry.stat()).size;
    } on FileSystemException {
      return 0;
    }
  }
}

/// What Spotlight indexing costs, and what can honestly be done about it.
///
/// The spec asks for indexing to be disabled on the volume. `.metadata_never_index`
/// is the file that used to do it and is widely repeated as the answer; on
/// current macOS it is unreliable, and `mdutil -i off` needs administrator
/// rights this app does not have and should not ask for.
///
/// So the honest position is the one stated here rather than a file written in
/// hope: the app does not create `.metadata_never_index` unless the user asks
/// for it, because writing to the card to *maybe* prevent a write is a poor
/// trade made silently.
abstract final class SpotlightPolicy {
  static const String markerName = '.metadata_never_index';

  static const String explanation =
      'macOS peut indexer la carte et y écrire .Spotlight-V100. Le fichier '
      '.metadata_never_index est censé l\'en empêcher, mais il n\'est plus '
      'fiable sur les versions récentes — et le créer est lui-même une '
      'écriture sur la carte. Le nettoyage avant éjection est la voie sûre.';

  /// Writes the marker, at the user's explicit request only.
  static Future<bool> optIn(String cardRoot) async {
    try {
      await File(p.join(cardRoot, markerName)).writeAsString('');
      return true;
    } on FileSystemException {
      return false;
    }
  }
}

/// What the app did and found when the card was opened.
class CardOpenReport {
  const CardOpenReport({
    required this.debrisRemoved,
    required this.parasites,
    required this.writable,
    required this.reconciled,
    required this.losses,
  });

  static const none = CardOpenReport(
    debrisRemoved: [],
    parasites: [],
    writable: true,
    reconciled: 0,
    losses: [],
  );

  /// Our own leftovers, cleared without asking.
  final List<String> debrisRemoved;

  /// The operating system's, reported and left alone: removing them is the
  /// user's call, because it is a write to their card.
  final List<Parasite> parasites;

  final bool writable;

  /// Interrupted operations resolved by observing the card.
  final int reconciled;

  /// Files gone with no copy known to be good. The one thing here that is not
  /// routine.
  final List<String> losses;

  bool get hasSomethingToSay =>
      parasites.isNotEmpty || losses.isNotEmpty || !writable;
}
