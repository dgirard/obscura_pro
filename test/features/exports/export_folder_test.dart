import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/exports/export_folder.dart';
import 'package:obscura_pro/infra/card_access/bookmark_store.dart';
import 'package:obscura_pro/infra/card_access/models.dart';

import '../../infra/card_access/fakes.dart';

/// Where the working directory is, and the two things that must never be true
/// of it: on the card, or unreadable after a relaunch.
void main() {
  late RecordingBridge bridge;
  late BookmarkStore bookmarks;
  late Directory support;

  setUp(() async {
    bridge = RecordingBridge();
    support = await Directory.systemTemp.createTemp('obscura_export_folder');
    bookmarks = BookmarkStore(
      bridge: bridge,
      storageDirectory: () async => support,
    );
  });

  tearDown(() async {
    if (await support.exists()) await support.delete(recursive: true);
  });

  ExportFolders foldersFor({
    List<MountedVolume> volumes = const [],
    String? chosen,
    Directory? fallback,
  }) =>
      ExportFolders(
        bookmarks: bookmarks,
        channel: FakeVolumeChannel(volumes: volumes),
        chosenFolder: () async => chosen,
        defaultRoot: () async => fallback ?? support,
      );

  MountedVolume card(String path) => MountedVolume(
        name: path.split('/').last,
        path: path,
        isRemovable: true,
        isEjectable: true,
      );

  group('refusing the card', () {
    test('a folder on a mounted removable volume is refused', () async {
      final folders = foldersFor(
        volumes: [card('/Volumes/Q3')],
        chosen: '/Volumes/Q3/DCIM/exports',
      );

      final outcome = await folders.root();

      // The guarantee the whole app is built on is that it never writes to the
      // card. A file chooser must not be the way around it.
      expect(outcome, isA<ExportFolderRefused>());
      expect((outcome as ExportFolderRefused).reason, contains('carte'));
    });

    test('the volume root itself is refused', () async {
      final folders =
          foldersFor(volumes: [card('/Volumes/Q3')], chosen: '/Volumes/Q3');

      expect(await folders.root(), isA<ExportFolderRefused>());
    });

    test('a folder under the home is accepted', () async {
      await bookmarks.save(ExportFolders.bookmarkKey, support.path);
      final folders = foldersFor(
        volumes: [card('/Volumes/Q3')],
        chosen: support.path,
      );

      expect(await folders.root(), isA<ExportFolderReady>());
    });

    test('the check keys on the volume, not on the word in the path', () async {
      // No removable volume is mounted here, so a path that merely looks like
      // one is somebody's ordinary folder.
      final ordinary = '${support.path}/Volumes/exports';
      await bookmarks.save(ExportFolders.bookmarkKey, ordinary);
      final folders = foldersFor(chosen: ordinary);

      expect(await folders.root(), isA<ExportFolderReady>());
    });

    test('a folder that has since become a card path is refused', () async {
      // Recorded when nothing was mounted there; a card now occupies the mount
      // point, and mount points are reused.
      final folders = foldersFor(
        volumes: [card('/Volumes/Untitled')],
        chosen: '/Volumes/Untitled/Exports',
      );

      expect(await folders.root(), isA<ExportFolderRefused>());
    });
  });

  group('surviving a relaunch', () {
    test('a chosen folder is used through its bookmark', () async {
      await bookmarks.save(ExportFolders.bookmarkKey, support.path);
      bridge.calls.clear();

      final folders = foldersFor(chosen: support.path);
      final outcome = await folders.root() as ExportFolderReady;

      expect(outcome.directory.path, support.path);
      // Resolved rather than trusted: the recorded path is a note to self, and
      // only the bookmark carries the grant.
      expect(bridge.calls.any((c) => c.startsWith('decode:')), isTrue);
    });

    test('running inside the scope releases it, even when the body throws',
        () async {
      await bookmarks.save(ExportFolders.bookmarkKey, support.path);
      final folders = foldersFor(chosen: support.path);

      await expectLater(
        folders.withFolder((directory) async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );

      expect(bridge.started, bridge.stopped);
      expect(bridge.started, greaterThan(0));
    });

    test('a chosen folder with no bookmark is reported, not silently used',
        () async {
      final folders = foldersFor(chosen: '/Users/someone/Pictures/Job');

      final outcome = await folders.root();

      // The path is remembered and the grant is not. Writing there would fail
      // under the sandbox, and saying so beats an export that cannot explain
      // itself.
      expect(outcome, isA<ExportFolderRefused>());
      expect((outcome as ExportFolderRefused).reason, contains('autorisation'));
    });

    test('the default folder needs no bookmark at all', () async {
      final folders = foldersFor(fallback: support);

      final outcome = await folders.root();

      expect(outcome, isA<ExportFolderReady>());
      // Inside the app's own container: nothing to grant, so nothing is minted.
      expect(bridge.calls, isEmpty);
    });
  });

  group('the session folder', () {
    test('is a dated folder under the root', () async {
      final folders = foldersFor(fallback: support);

      final session = await folders.session(now: DateTime(2026, 8, 13));

      expect(session, isA<ExportFolderReady>());
      expect(
        (session as ExportFolderReady).directory.path,
        '${support.path}/2026-08-13',
      );
    });

    test('carries the refusal rather than inventing a folder', () async {
      final folders = foldersFor(
        volumes: [card('/Volumes/Q3')],
        chosen: '/Volumes/Q3/Exports',
      );

      expect(await folders.session(), isA<ExportFolderRefused>());
    });
  });
}
