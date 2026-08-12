import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import 'bookmark_store.dart';
import 'models.dart';
import 'volume_channel.dart';

/// The open panel, injectable so the one place a sandbox grant is created can
/// be exercised without an NSOpenPanel.
typedef DirectoryPicker = Future<String?> Function({String? startAt});

/// Opening a card, holding on to it, and letting go of it safely.
class CardAccessService {
  CardAccessService({
    required VolumeChannel channel,
    required BookmarkStore bookmarks,
    DirectoryPicker? directoryPicker,
  })  : _channel = channel,
        _bookmarks = bookmarks,
        _pickDirectory = directoryPicker ?? _openPanel;

  final VolumeChannel _channel;
  final BookmarkStore _bookmarks;
  final DirectoryPicker _pickDirectory;

  final _lost = StreamController<String>.broadcast();
  StreamSubscription<VolumeEvent>? _watch;
  String? _openCardPath;

  /// Whether a security scope is actually held for the open card.
  ///
  /// Tracked so the release stays balanced: Apple is explicit that stopping a
  /// scope that was never started is as wrong as never stopping one.
  bool _scopeHeld = false;

  /// Why the scope could not be taken, when it could not.
  ///
  /// Kept rather than thrown: the session works without it, but the card will
  /// not reopen by itself next launch, and that is worth being able to say.
  String? scopeFailure;

  /// Whether the open card will still be reachable after a relaunch.
  bool get cardSurvivesRelaunch => _scopeHeld;

  /// Key under which the most recent card is remembered.
  static const lastCardKey = 'last_card';

  /// Key under which a particular card is remembered, so that *any* card this
  /// Mac has been given access to opens by itself when it comes back — not only
  /// the one from last session.
  ///
  /// Keyed by mount path, and that is safe in the way that matters: a bookmark
  /// is bound to the volume, not to the path it happens to be mounted at, so a
  /// different card arriving at `/Volumes/Untitled` resolves stale rather than
  /// handing out a grant for someone else's card.
  static String cardKey(String path) => 'card:$path';

  /// DCF folder names: three digits then five free characters, giving
  /// `100LEICA` on a Q3. Matching the standard rather than the Leica spelling
  /// keeps a card written by another body readable.
  static final _dcfFolder = RegExp(r'^\d{3}[A-Z0-9_]{5}$');

  /// [startAt] opens the panel already inside that volume, so choosing a card
  /// the picker has already listed is one confirmation rather than a hunt
  /// through the file system.
  static Future<String?> _openPanel({String? startAt}) => getDirectoryPath(
        initialDirectory: startAt,
        confirmButtonText: 'Ouvrir la carte',
      );

  /// The card currently open, if any.
  String? get openCardPath => _openCardPath;

  /// Fires with the card's path when the volume goes away underneath us.
  ///
  /// This is how an operation in flight learns to stop. On a non-journaled
  /// exFAT card a write interrupted by the medium disappearing is exactly the
  /// failure the app exists to avoid, so `willUnmount` is treated as loss —
  /// the last moment at which stopping still helps.
  Stream<String> get cardLost => _lost.stream;

  /// Volumes that could plausibly be a camera card.
  Future<List<MountedVolume>> availableCards() async {
    final volumes = await _channel.listVolumes();
    return volumes.where((v) => v.isCardCandidate).toList(growable: false);
  }

  Stream<VolumeEvent> watchVolumes() => _channel.watchVolumes();

  /// Asks the user to choose the card, then opens it.
  ///
  /// The open panel is not merely a convenience: under the sandbox the user's
  /// selection *is* the grant, so there is no way to reach a volume the user has
  /// not pointed at. Seeing a volume in the list and being allowed to read it
  /// are different things.
  ///
  /// [startAt] is the volume the user pointed at in the app's own list. It
  /// only positions the panel; the grant still comes from their confirmation.
  ///
  /// Returns null when the user dismissed the panel.
  Future<CardCheck?> chooseCard({String? startAt}) async {
    final path = await _pickDirectory(startAt: startAt);
    if (path == null) return null;

    final check = await inspect(path);
    if (check is CardMissingDcim) return check;

    // Minted here, in the same turn as the selection: the ability to create a
    // bookmark depends on the panel's implicit grant still being live, so
    // deferring it to first use fails.
    await _bookmarks.save(lastCardKey, path);
    await _bookmarks.save(cardKey(path), path);

    // Resolving the bookmark just written is not a redundant round trip.
    // `startAccessingSecurityScopedResource` takes the URL that came *out of*
    // resolving a bookmark and no other, so until the resolve has happened
    // there is no scope to take — asking for one fails, and the platform
    // reports it as a malformed argument, which is not what went wrong.
    final resolved = await _bookmarks.resolve(lastCardKey);
    await _hold(resolved is BookmarkResolved ? resolved.path : path);
    return check;
  }

  /// Re-opens the card remembered from a previous session, if it is back.
  ///
  /// The scope is taken *before* the card is looked at, which is the reverse of
  /// [chooseCard] and has to be. There the open panel has already granted this
  /// process access, so the inspection is free; here the grant exists only
  /// inside the bookmark, and resolving one yields a URL and no access at all.
  /// Listing `DCIM/` first is the call the sandbox refuses — and its refusal is
  /// indistinguishable from a card that is not in the reader, so the app would
  /// have quietly fallen back to the panel every launch and looked like a
  /// feature that was never wired.
  ///
  /// Returns null when there is nothing to reopen, which covers all the
  /// ordinary cases: no card was ever chosen, the bookmark is stale, or the
  /// card is not there. The grant is given back in every one of them.
  Future<CardCheck?> reopenLastCard() async {
    final resolution = await _bookmarks.resolve(lastCardKey);
    if (resolution is! BookmarkResolved) return null;

    await _hold(resolution.path);
    try {
      final check = await inspect(resolution.path);
      if (check is! CardMissingDcim) return check;
    } on Object {
      // A path that cannot be read is not a card that can be reopened, and at
      // launch there is nobody to tell about it who is not better served by the
      // picker.
    }
    await closeCard();
    return null;
  }

  Future<void> forgetLastCard() => _bookmarks.forget(lastCardKey);

  /// Opens a mounted card this Mac has been given access to before.
  ///
  /// The fluent case, and the one [reopenLastCard] misses: the photographer has
  /// two cards and swaps them, or opened another one in between. Both were
  /// granted at some point, so both can be reopened without a panel, and asking
  /// again for a card the user has already pointed at is the interface making
  /// them repeat themselves.
  ///
  /// Same ordering as [reopenLastCard] and for the same reason: the scope comes
  /// before the look. Tries the candidates in the order given and stops at the
  /// first that opens.
  Future<CardCheck?> reopenKnownCard(Iterable<String> mountedPaths) async {
    for (final path in mountedPaths) {
      if (path == _openCardPath) continue;
      final resolution = await _bookmarks.resolve(cardKey(path));
      if (resolution is! BookmarkResolved) continue;

      await _hold(resolution.path);
      try {
        final check = await inspect(resolution.path);
        if (check is! CardMissingDcim) {
          // Whatever was reopened is now the card to come back to.
          await _bookmarks.save(lastCardKey, resolution.path);
          return check;
        }
      } on Object {
        // Unreadable is indistinguishable from absent from here, and the picker
        // is already the answer to both.
      }
      await closeCard();
    }
    return null;
  }

  /// Takes the sandbox grant and starts listening for the card leaving.
  ///
  /// A grant that cannot be taken does not stop the session. Choosing the card
  /// in the panel granted this process access to it already; the bookmark scope
  /// is what makes that survive a relaunch. Refusing to open a readable card
  /// over a scope that failed would trade a working session for a stricter one
  /// that shows the user nothing.
  Future<void> _hold(String path) async {
    await closeCard();
    try {
      await _bookmarks.beginAccess(path);
      _scopeHeld = true;
    } on Object catch (error) {
      _scopeHeld = false;
      scopeFailure = '$error';
    }
    _openCardPath = path;
    _watch = _channel.watchVolumes().listen(_onVolumeEvent);
  }

  void _onVolumeEvent(VolumeEvent event) {
    final open = _openCardPath;
    if (open == null) return;
    if (event.kind == VolumeEventKind.mounted) return;
    // Path prefix rather than equality: the notification names the volume,
    // while the open card may be a folder within it.
    if (open != event.path && !p.isWithin(event.path, open)) return;
    _lost.add(open);
  }

  /// Releases the sandbox grant and stops watching.
  ///
  /// Apple is explicit that an unbalanced start leaks kernel resources, so this
  /// runs even when the card vanished — there is still a grant to give back.
  Future<void> closeCard() async {
    await _watch?.cancel();
    _watch = null;
    final path = _openCardPath;
    final held = _scopeHeld;
    _openCardPath = null;
    _scopeHeld = false;
    if (path != null && held) await _bookmarks.endAccess(path);
  }

  /// Runs [body] with the sandbox grant for [path] held and always released.
  Future<T> withCardAccess<T>(String path, Future<T> Function() body) =>
      _bookmarks.withAccess(path, body);

  /// Whether [path] is laid out like a camera card.
  ///
  /// Checked before a scan so that picking the wrong folder produces a clear
  /// answer instead of an empty library the user has to interpret.
  Future<CardCheck> inspect(String path) async {
    final dcim = Directory(p.join(path, 'DCIM'));
    if (!await dcim.exists()) return CardMissingDcim(path);

    final folders = <String>[];
    await for (final entry in dcim.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final name = p.basename(entry.path);
      if (_dcfFolder.hasMatch(name)) folders.add(name);
    }
    folders.sort();

    if (folders.isEmpty) return CardEmpty(dcim.path);
    return CardAccepted(dcimPath: dcim.path, cameraFolders: folders);
  }

  /// Unmounts and ejects the card.
  ///
  /// On a non-journaled exFAT volume this is the point at which writes are
  /// guaranteed to have landed, so a refusal is surfaced with its reason rather
  /// than retried or swallowed.
  Future<EjectOutcome> eject(String path) async {
    final outcome = await _channel.eject(path);
    if (outcome is EjectSucceeded) await closeCard();
    return outcome;
  }

  Future<void> dispose() async {
    await closeCard();
    await _lost.close();
  }
}
