import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/catalog/dcf_scanner.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/settings/settings_store.dart';
import 'package:obscura_pro/features/trash/mark_store.dart';
import 'package:obscura_pro/features/trash/trash_service.dart';
import 'package:obscura_pro/infra/db/database.dart';
import 'package:obscura_pro/infra/safety/atomic_ops.dart';

import '../../fixtures/fake_card.dart';

/// What a mark has to survive: the app closing.
///
/// Before this, the grid and the viewer held the marks in a set in memory and
/// the trash table was written only when Empty Trash ran. A photographer who
/// culled nine hundred frames and quit had made nine hundred decisions about a
/// card that had deliberately not been touched, and every one of them was gone.
void main() {
  late FakeCard card;
  late AppDatabase db;
  late Directory macTrash;
  late TrashService service;

  setUp(() async {
    card = await FakeCard.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    macTrash = await Directory.systemTemp.createTemp('obscura_mactrash');
    service = TrashService(db: db, macTrashRoot: macTrash);
  });

  tearDown(() async {
    await db.close();
    await card.dispose();
    if (await macTrash.exists()) await macTrash.delete(recursive: true);
  });

  Future<List<PhotoEntity>> catalogue() async =>
      (await const DcfScanner().scan(card.path)).photos;

  MarkStore deferred() =>
      TrashMarkStore(trash: service, mode: DeletionMode.deferred);
  MarkStore immediate() =>
      TrashMarkStore(trash: service, mode: DeletionMode.immediate);

  group('deferred marking', () {
    test('a mark made now is readable by a store opened later', () async {
      await card.addPhoto('L1000001');
      await card.addPhoto('L1000002');
      final photos = await catalogue();

      await deferred().mark(photos.first);

      // A second store over the same database is what a relaunch looks like
      // from here: nothing is carried over in memory, only what reached disk.
      expect(await deferred().markedKeys(), {photos.first.key.value});
    });

    test('records the decision and touches no file on the card', () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      final before = await _cardSnapshot(card);

      final report = await deferred().mark(photo);

      expect(report.effect, MarkEffect.recorded);
      expect(report.isClean, isTrue);
      expect(await _cardSnapshot(card), before);
    });

    test('unmarking takes the key back out of what a relaunch would read',
        () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      final store = deferred();

      await store.mark(photo);
      final report = await store.unmark(photo);

      expect(report.effect, MarkEffect.withdrawn);
      expect(await store.markedKeys(), isEmpty);
    });

    test('reads back one key for a RAW+JPG pair, not two', () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;

      await deferred().mark(photo);

      // The mark belongs to the photograph. Two files, two rows, one decision.
      expect(photo.files, hasLength(2));
      expect(await deferred().markedKeys(), hasLength(1));
    });

    test('restoring a list leaves the rest of the trash alone', () async {
      await card.addPhoto('L1000001');
      await card.addPhoto('L1000002');
      final photos = await catalogue();
      final store = deferred();
      for (final photo in photos) {
        await store.mark(photo);
      }

      await store.unmark(photos.first);

      // "Restore All" is given the photographs on screen rather than told to
      // clear the table: the table spans every card this Mac has culled, and a
      // button under a list of eleven frames must not undo a decision made
      // about a card that is in a drawer.
      expect(await store.markedKeys(), {photos.last.key.value});
    });
  });

  group('immediate marking', () {
    test('moves the photograph off the card and reports that it did', () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;

      final report = await immediate().mark(photo);

      expect(report.effect, MarkEffect.movedOffCard);
      for (final file in photo.files) {
        expect(File(file.path).existsSync(), isFalse);
      }
      // Nothing is left marked: there is no decision outstanding about a
      // photograph that has already gone.
      expect(await immediate().markedKeys(), isEmpty);
    });

    test('the rescued originals are on the Mac before the card loses them',
        () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;

      await immediate().mark(photo);

      final rescued = macTrash
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(rescued, {'L1000001.DNG', 'L1000001.JPG'});
    });

    test('a refused card write leaves the photograph marked, and says so',
        () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      // The copy verifies and the unlink refuses — a card that has gone
      // read-only under a session that started on a writable one.
      final refusing = TrashMarkStore(
        trash: TrashService(
          db: db,
          macTrashRoot: macTrash,
          unlinkOverride: (file) async =>
              const UnlinkFailed('read-only file system'),
        ),
        mode: DeletionMode.immediate,
      );

      final report = await refusing.mark(photo);

      // Not "deleted". The frame is still on the card, the decision stands, and
      // the interface is told which of those two is which.
      expect(report.effect, MarkEffect.recorded);
      expect(report.detail, contains('restée sur la carte'));
      expect(await deferred().markedKeys(), {photo.key.value});
      expect(File(photo.files.first.path).existsSync(), isTrue);
    });
  });
}

/// Every file under the card, with its size and modification time.
Future<Map<String, (int, DateTime)>> _cardSnapshot(FakeCard card) async {
  final out = <String, (int, DateTime)>{};
  await for (final entry in Directory(card.path).list(recursive: true)) {
    if (entry is! File) continue;
    final stat = await entry.stat();
    out[entry.path] = (stat.size, stat.modified);
  }
  return out;
}
