import 'dart:convert';
import 'dart:io';

import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// The slice of the platform bookmark API this app uses.
///
/// `SecureBookmarks` is a process-wide singleton, so it cannot be substituted
/// in a test. Wrapping it here keeps the store's own logic — persistence,
/// staleness, and balanced access — verifiable without a real sandbox.
abstract interface class SecureBookmarkBridge {
  Future<String> encode(Directory directory);
  Future<Directory> decode(String encoded);
  Future<void> startAccess(Directory directory);
  Future<void> stopAccess(Directory directory);
}

class PlatformSecureBookmarkBridge implements SecureBookmarkBridge {
  PlatformSecureBookmarkBridge([SecureBookmarks? bookmarks])
      : _bookmarks = bookmarks ?? SecureBookmarks();

  final SecureBookmarks _bookmarks;

  @override
  Future<String> encode(Directory directory) => _bookmarks.bookmark(directory);

  @override
  Future<Directory> decode(String encoded) async {
    final entity =
        await _bookmarks.resolveBookmark(encoded, isDirectory: true);
    return Directory(entity.path);
  }

  @override
  Future<void> startAccess(Directory directory) =>
      _bookmarks.startAccessingSecurityScopedResource(directory);

  @override
  Future<void> stopAccess(Directory directory) =>
      _bookmarks.stopAccessingSecurityScopedResource(directory);
}

/// Remembers which card the user chose, so a later session can reopen it
/// without another trip through the open panel.
///
/// Under the sandbox, choosing a folder in the open panel is what grants access
/// to it, and that grant dies with the process. A security-scoped bookmark is
/// the only thing that outlives it.
class BookmarkStore {
  BookmarkStore({
    required SecureBookmarkBridge bridge,
    Future<Directory> Function()? storageDirectory,
  })  : _bridge = bridge,
        _storageDirectory = storageDirectory ?? getApplicationSupportDirectory;

  final SecureBookmarkBridge _bridge;
  final Future<Directory> Function() _storageDirectory;

  /// Bookmarks live beside the database, on the Mac. Nothing about the app's
  /// own state is ever written to the card.
  static const fileName = 'card_bookmarks.json';

  Future<File> _file() async =>
      File(p.join((await _storageDirectory()).path, fileName));

  Future<Map<String, String>> _read() async {
    final file = await _file();
    if (!await file.exists()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry('$k', '$v'));
    } on FormatException {
      // A truncated file is worth no more than an empty one: the user picks the
      // card again, which is a far better outcome than refusing to launch.
      return {};
    }
  }

  Future<void> _write(Map<String, String> entries) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(entries), flush: true);
  }

  /// Records a bookmark for [path].
  ///
  /// Must run in the same turn as the open-panel selection: creating a bookmark
  /// depends on the panel's implicit in-process grant still being live, so
  /// minting it lazily on first use instead fails.
  Future<void> save(String key, String path) async {
    final encoded = await _bridge.encode(Directory(path));
    final entries = await _read()..[key] = encoded;
    await _write(entries);
  }

  Future<BookmarkResolution> resolve(String key) async {
    final encoded = (await _read())[key];
    if (encoded == null) return const BookmarkAbsent();

    try {
      final directory = await _bridge.decode(encoded);
      return BookmarkResolved(directory.path);
    } catch (_) {
      // Reformatted, renamed, or simply absent. All ordinary for removable
      // media, so this resolves to a state the UI can act on rather than an
      // exception every caller would have to guard.
      return const BookmarkStale();
    }
  }

  Future<void> forget(String key) async {
    final entries = await _read()..remove(key);
    await _write(entries);
  }

  /// Takes the sandbox grant for [path] and holds it until [endAccess].
  ///
  /// Used for the session-long hold on the open card, where the scope has to
  /// outlive any single operation. One-off work should prefer [withAccess],
  /// which cannot forget to release.
  Future<void> beginAccess(String path) =>
      _bridge.startAccess(Directory(path));

  Future<void> endAccess(String path) => _bridge.stopAccess(Directory(path));

  /// Runs [body] with the sandbox grant for [path] held, releasing it
  /// afterwards **even when [body] throws**.
  ///
  /// The release is structural rather than left to call sites: Apple is explicit
  /// that an unbalanced start leaks kernel resources, and the path that leaks in
  /// practice is the one nobody exercises by hand — the exception path.
  Future<T> withAccess<T>(String path, Future<T> Function() body) async {
    final directory = Directory(path);
    await _bridge.startAccess(directory);
    try {
      return await body();
    } finally {
      await _bridge.stopAccess(directory);
    }
  }
}
