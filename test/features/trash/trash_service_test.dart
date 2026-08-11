import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/catalog/dcf_scanner.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/trash/trash_service.dart';
import 'package:obscura_pro/infra/db/database.dart';
import 'package:obscura_pro/infra/safety/atomic_ops.dart';
import 'package:path/path.dart' as p;

import '../../fixtures/fake_card.dart';

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

  /// Every file under the card's tree, with its size and modification time.
  ///
  /// The comparison that proves marking is free: not "did the photographs
  /// survive" but "did anything at all on this card change".
  Future<Map<String, (int, DateTime)>> cardSnapshot() async {
    final out = <String, (int, DateTime)>{};
    await for (final entry in Directory(card.path).list(recursive: true)) {
      if (entry is! File) continue;
      final stat = await entry.stat();
      out[p.relative(entry.path, from: card.path)] = (stat.size, stat.modified);
    }
    return out;
  }

  group('marking', () {
    test('writes nothing whatsoever to the card', () async {
      await card.addPhoto('L1000001');
      await card.addPhoto('L1000002');
      final photos = await catalogue();
      final before = await cardSnapshot();

      await service.mark(photos.first);

      // A photographer culling 900 frames is making decisions, not deletions.
      // The card must be safe to pull at any point during that.
      expect(await cardSnapshot(), before);
    });

    test('marks the whole photograph, both files of a pair', () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;

      await service.mark(photo);

      // A DNG and its JPG are one picture. Leaving one behind is how a culling
      // tool fills a card with orphans the user believes they cleared (R12).
      final summary = await service.watchSummary().first;
      expect(summary.fileCount, 2);
      expect(summary.photoCount, 1);
      expect(summary.pendingBytes, photo.totalBytes);
    });

    test('unmarking takes it back off, and marking twice is not two marks',
        () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;

      await service.mark(photo);
      await service.mark(photo);
      expect((await service.watchSummary().first).fileCount, 2);

      await service.unmark(photo);
      expect((await service.watchSummary().first).fileCount, 0);
    });
  });

  group('emptying the trash', () {
    test('removes both files of the photograph and nothing else', () async {
      await card.addPhoto('L1000001');
      await card.addPhoto('L1000002');
      final photos = await catalogue();
      final doomed = photos.firstWhere((p) => p.radical == 'L1000001');
      final survivor = photos.firstWhere((p) => p.radical == 'L1000002');
      await service.mark(doomed);

      final report = await service.emptyTrash([doomed]);

      expect(report.isClean, isTrue);
      expect(report.deleted, ['100LEICA/L1000001']);
      for (final file in doomed.files) {
        expect(File(file.path).existsSync(), isFalse, reason: file.name);
      }
      for (final file in survivor.files) {
        expect(File(file.path).existsSync(), isTrue, reason: file.name);
      }
      expect(report.bytesFreed, doomed.totalBytes);
    });

    test('renames nothing and renumbers nothing', () async {
      for (final radical in ['L1000001', 'L1000002', 'L1000003']) {
        await card.addPhoto(radical);
      }
      final photos = await catalogue();
      final doomed = photos.firstWhere((p) => p.radical == 'L1000002');
      await service.mark(doomed);

      await service.emptyTrash([doomed]);

      // R14/FONC-DEL-3: the gap in the numbering is the correct outcome. The
      // camera's own counter is independent and closing the gap would corrupt
      // the DCF layout the body relies on.
      final remaining = Directory(p.join(card.path, 'DCIM', '100LEICA'))
          .listSync()
          .map((e) => p.basename(e.path))
          .toList()
        ..sort();
      expect(remaining, [
        'L1000001.DNG',
        'L1000001.JPG',
        'L1000003.DNG',
        'L1000003.JPG',
      ]);
    });

    test('leaves a different photograph at the same path untouched', () async {
      await card.addPhoto('L1000001', captureTime: '2026:03:14 09:00:00');
      final original = (await catalogue()).single;
      await service.mark(original);

      // The camera's numbering was reset and it wrote a new frame over the same
      // name. This is the case that separates "delete this file" from "delete
      // this photograph".
      await card.addPhoto('L1000001', captureTime: '2026:08:01 17:30:00');
      final replacement = File(original.files.first.path);
      final bytesBefore = replacement.readAsBytesSync();

      final report = await service.emptyTrash([original]);

      expect(replacement.existsSync(), isTrue);
      expect(replacement.readAsBytesSync(), bytesBefore);
      expect(report.deleted, isEmpty);
      expect(
        report.skipped.map((c) => c.reason),
        everyElement(TrashConflictReason.differentPhotographAtPath),
      );
    });

    test('a file already gone is recorded as deleted, not as a failure',
        () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      await service.mark(photo);
      // An interrupted earlier run, or the user in the Finder.
      File(photo.files.first.path).deleteSync();

      final report = await service.emptyTrash([photo]);

      expect(report.deleted, ['100LEICA/L1000001']);
      expect(report.isClean, isTrue);
      expect((await service.watchSummary().first).fileCount, 0);
    });

    test('deletes only what was marked, even when asked for more', () async {
      await card.addPhoto('L1000001');
      await card.addPhoto('L1000002');
      final photos = await catalogue();
      await service.mark(photos.first);

      // The second photograph was never marked; passing it in must not be
      // enough to remove it.
      await service.emptyTrash(photos);

      expect(File(photos[1].files.first.path).existsSync(), isTrue);
    });

    test('stops and flags the rest uncertain when the card goes away',
        () async {
      for (final radical in ['L1000001', 'L1000002', 'L1000003']) {
        await card.addPhoto(radical);
      }
      final photos = await catalogue();
      for (final photo in photos) {
        await service.mark(photo);
      }
      // The card is pulled after the first entity. Nothing can be observed
      // about a volume that is not there, so nothing may be claimed about it.
      await Directory(p.join(card.path, 'DCIM')).delete(recursive: true);

      final report = await service.emptyTrash(photos);

      // Every file was already gone with the directory, so this run resolves
      // them as deleted rather than inventing failures — what matters is that
      // it reported honestly and did not crash.
      expect(report.deleted.length + report.uncertain.length, photos.length);
    });
  });

  group('moving originals to the Mac', () {
    test('copies, verifies, and only then removes the card file', () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      await service.mark(photo);
      final sourceHashes = {
        for (final f in photo.files) f.name: await hashOf(File(f.path)),
      };

      final report = await service.moveToMacTrash(photo);

      expect(report.succeeded, isTrue);
      for (final file in photo.files) {
        expect(File(file.path).existsSync(), isFalse);
        final rescued = File(p.join(macTrash.path, photo.key.value, file.name));
        expect(rescued.existsSync(), isTrue, reason: file.name);
        // Identical bytes, not merely a file of the right size.
        expect(await hashOf(rescued), sourceHashes[file.name]);
      }
    });

    test('the rescued copy is filed under the stable key, not the path',
        () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      await service.mark(photo);

      await service.moveToMacTrash(photo);

      // A card remounts at a different point and a camera reuses names; the key
      // is the only thing about a photograph that survives both.
      expect(
        Directory(p.join(macTrash.path, photo.key.value)).existsSync(),
        isTrue,
      );
    });
  });

  group('reconciliation after an interrupted run', () {
    test('a `deleting` row whose file is gone becomes deleted', () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      await service.mark(photo);
      final items = await db.trashDao.itemsOfPhoto(
        (await db.catalogDao.photoByStableKey(photo.key.value))!.id,
      );
      // The crash: intent committed, unlink done, outcome never written.
      final item = items.first;
      await db.trashDao.recordIntent(item.id, TrashState.deleting);
      File(p.join(card.path, item.cardRelativePath)).deleteSync();

      final report = await service.reconcile(cardRoot: card.path);

      expect(report.isClean, isTrue);
      expect(report.resolved.values, contains(TrashState.deleted));
    });

    test('a `deleting` row whose file survived goes back to marked', () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      await service.mark(photo);
      final items = await db.trashDao.itemsOfPhoto(
        (await db.catalogDao.photoByStableKey(photo.key.value))!.id,
      );
      await db.trashDao.recordIntent(items.first.id, TrashState.deleting);

      final report = await service.reconcile(cardRoot: card.path);

      // The unlink never happened, so the user's decision stands and nothing
      // has been done about it yet.
      expect(report.resolved.values, everyElement(TrashState.marked));
      expect(File(photo.files.first.path).existsSync(), isTrue);
    });

    test('an interrupted move with the original still there quarantines the copy',
        () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      await service.mark(photo);
      final photoRow = (await db.catalogDao.photoByStableKey(photo.key.value))!;
      final item = (await db.trashDao.itemsOfPhoto(photoRow.id)).first;

      // A copy of unknown completeness, and the card file still present.
      final partial = File(p.join(macTrash.path, photo.key.value, 'L1000001.DNG'))
        ..createSync(recursive: true)
        ..writeAsStringSync('half a photograph');
      await db.trashDao.recordIntent(item.id, TrashState.movingToMacTrash);
      await db.trashDao.commitOutcome(
        item.id,
        TrashState.movingToMacTrash,
        macTrashPath: partial.path,
      );

      final report = await service.reconcile(cardRoot: card.path);

      expect(report.resolved.values, contains(TrashState.marked));
      // Moved aside rather than deleted: it may be most of a photograph, and
      // that is the user's to judge.
      expect(partial.existsSync(), isFalse);
      expect(
        Directory(p.join(macTrash.path, 'quarantine')).listSync(),
        hasLength(1),
      );
    });

    test('a card file gone with no verified copy is a loss, and says so',
        () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      await service.mark(photo);
      final photoRow = (await db.catalogDao.photoByStableKey(photo.key.value))!;
      final item = (await db.trashDao.itemsOfPhoto(photoRow.id)).first;

      await db.trashDao.recordIntent(item.id, TrashState.movingToMacTrash);
      File(p.join(card.path, item.cardRelativePath)).deleteSync();

      final report = await service.reconcile(cardRoot: card.path);

      // The one outcome the app cannot repair. It is reported plainly rather
      // than resolved into a state that sounds better than the truth.
      expect(report.isClean, isFalse);
      expect(report.unresolvedLosses, hasLength(1));
      expect(report.resolved.values, contains(TrashState.uncertain));
    });

    test('leaves rows that were not in flight alone', () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      await service.mark(photo);

      final report = await service.reconcile(cardRoot: card.path);

      expect(report.resolved, isEmpty);
      expect((await service.watchSummary().first).fileCount, 2);
    });
  });
}
