import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../infra/card_access/bookmark_store.dart';
import '../../infra/card_access/models.dart';
import '../../infra/card_access/volume_channel.dart';
import '../../infra/safety/atomic_ops.dart' show volumeRootOf;
import '../crop/export_service.dart';
import '../settings/settings_store.dart';
import '../volume_select/card_selection.dart';

/// Where the working directory is, or why it cannot be used.
sealed class ExportFolderOutcome {
  const ExportFolderOutcome();
}

final class ExportFolderReady extends ExportFolderOutcome {
  const ExportFolderReady(this.directory);

  final Directory directory;
}

/// The folder cannot be used, and the reason is written for a photographer to
/// read rather than for a log.
final class ExportFolderRefused extends ExportFolderOutcome {
  const ExportFolderRefused(this.reason);

  final String reason;

  @override
  String toString() => 'ExportFolderRefused($reason)';
}

/// Thrown where a caller wants a folder and there is a reason there is none.
///
/// Carries the sentence written for the photographer rather than a code: every
/// site that catches this shows it, and rewording it at each of them would let
/// them drift apart.
class ExportFolderUnusable implements Exception {
  const ExportFolderUnusable(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

/// The one place that decides where exports live.
///
/// It exists because the answer has two conditions on it that were previously
/// nowhere: the folder must not be on the card, and a folder outside this app's
/// own container is only reachable through the security-scoped bookmark minted
/// when the user chose it. Both were invisible while the folder was written to
/// and never read back; a working directory reads it on every launch.
class ExportFolders {
  ExportFolders({
    required this.bookmarks,
    required this.channel,
    required Future<String?> Function() chosenFolder,
    Future<Directory> Function()? defaultRoot,
  })  : _chosenFolder = chosenFolder,
        _defaultRoot = defaultRoot ?? defaultExportRoot;

  final BookmarkStore bookmarks;
  final VolumeChannel channel;

  final Future<String?> Function() _chosenFolder;
  final Future<Directory> Function() _defaultRoot;

  /// The key the chosen folder's bookmark is filed under, beside the cards'.
  static const bookmarkKey = 'export_folder';

  /// The working root: the folder the user chose, or this app's own.
  ///
  /// Checked on every call rather than once at startup, because a path that was
  /// perfectly ordinary when it was recorded can become a card path later —
  /// mount points are reused, and `/Volumes/Untitled` is a different volume on
  /// a different day.
  Future<ExportFolderOutcome> root() async {
    final chosen = await _chosenFolder();
    if (chosen == null) return ExportFolderReady(await _defaultRoot());

    if (await isOnRemovableVolume(chosen)) {
      return const ExportFolderRefused(
        'Ce dossier est sur une carte. Les exports sont écrits sur le Mac, '
        'jamais sur la carte.',
      );
    }

    final resolution = await bookmarks.resolve(bookmarkKey);
    if (resolution is! BookmarkResolved) {
      return const ExportFolderRefused(
        'Ce dossier a été retenu sans son autorisation d\'accès. '
        'Choisissez-le à nouveau dans Réglages.',
      );
    }
    return ExportFolderReady(Directory(resolution.path));
  }

  /// The dated folder of the day, under [root].
  ///
  /// A run of exports stays together instead of silting up one directory over
  /// months — the layout `defaultExportFolder` already writes into.
  Future<ExportFolderOutcome> session({DateTime? now}) async {
    final resolved = await root();
    if (resolved is! ExportFolderReady) return resolved;
    final day = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
    return ExportFolderReady(Directory(p.join(resolved.directory.path, day)));
  }

  /// Runs [body] with the sandbox grant held, when one is needed.
  ///
  /// The grant is only needed for a folder the user chose; this app's own
  /// container needs none, and asking for one there would fail.
  Future<T?> withFolder<T>(
    Future<T> Function(Directory directory) body, {
    bool session = false,
  }) async {
    final resolved = session ? await this.session() : await root();
    if (resolved is! ExportFolderReady) return null;

    final chosen = await _chosenFolder();
    if (chosen == null) return body(resolved.directory);

    // Resolved again rather than cast from the check above: the two calls are
    // separated by an await, and a card pulled or a folder renamed in between
    // would turn a cast into a crash on the one path that exists to be careful.
    final held = await bookmarks.resolve(bookmarkKey);
    if (held is! BookmarkResolved) return null;
    return bookmarks.withAccess(held.path, () => body(resolved.directory));
  }

  /// Whether [path] sits on a mounted removable volume.
  ///
  /// Asked of the volumes actually mounted rather than of the path's spelling:
  /// a folder called `Volumes` under someone's home is their folder, and a card
  /// mounted somewhere unusual is still a card.
  Future<bool> isOnRemovableVolume(String path) async {
    final normalized = p.normalize(path);
    final volumes = await channel.listVolumes();
    for (final volume in volumes) {
      if (!volume.isRemovable && !volume.isEjectable) continue;
      if (normalized == volume.path || p.isWithin(volume.path, normalized)) {
        return true;
      }
    }
    // A path under `/Volumes` that matched no listed volume is refused as well
    // when the volume list is empty for a reason we cannot see: the cost of
    // being wrong here is writing to somebody's card.
    final root = volumeRootOf(normalized);
    return root != null && volumes.isEmpty;
  }
}

final exportFoldersProvider = Provider<ExportFolders>(
  (ref) => ExportFolders(
    bookmarks: ref.watch(bookmarkStoreProvider),
    channel: ref.watch(volumeChannelProvider),
    chosenFolder: () async =>
        (await ref.read(settingsProvider.future)).exportFolder,
  ),
);

/// Overridden in widget tests, which have no bookmarks and no volumes.
@visibleForTesting
ExportFolders inMemoryExportFolders(Directory root) => ExportFolders(
      bookmarks: BookmarkStore(
        bridge: _NoBookmarks(),
        storageDirectory: () async => root,
      ),
      channel: VolumeChannel(),
      chosenFolder: () async => null,
      defaultRoot: () async => root,
    );

class _NoBookmarks implements SecureBookmarkBridge {
  @override
  Future<String> encode(Directory directory) async => directory.path;

  @override
  Future<Directory> decode(String encoded) async => Directory(encoded);

  @override
  Future<void> startAccess(Directory directory) async {}

  @override
  Future<void> stopAccess(Directory directory) async {}
}
