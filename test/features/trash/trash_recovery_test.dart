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

/// Thrown at an injected step boundary. Stands in for the process dying: the
/// durable writes already made survive, and nothing after this point runs.
class _Crash implements Exception {
  const _Crash(this.step);
  final String step;
  @override
  String toString() => 'crash at $step';
}

void main() {
  late FakeCard card;
  late AppDatabase db;
  late Directory macTrash;

  setUp(() async {
    card = await FakeCard.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    macTrash = await Directory.systemTemp.createTemp('obscura_recovery');
  });

  tearDown(() async {
    await db.close();
    await card.dispose();
    if (await macTrash.exists()) await macTrash.delete(recursive: true);
  });

  TrashService serviceCrashingAt(String? step) => TrashService(
        db: db,
        macTrashRoot: macTrash,
        onStep: step == null ? null : (s) { if (s == step) throw _Crash(s); },
      );

  Future<List<PhotoEntity>> catalogue() async =>
      (await const DcfScanner().scan(card.path)).photos;

  /// Every state the trash table is in, by card-relative path.
  Future<Map<String, TrashState>> states() async {
    final out = <String, TrashState>{};
    for (final state in TrashState.values) {
      for (final item in await db.trashDao.itemsInState(state)) {
        out[item.cardRelativePath] = state;
      }
    }
    return out;
  }

  /// The invariant the whole KTD-14 ordering exists to hold.
  ///
  /// After a crash and a reconciliation, nothing is left describing an
  /// operation still in flight, and no file has vanished without either a
  /// verified deletion or a verified copy of it somewhere else. A row that
  /// still said `deleting` would be a card the app could not describe.
  Future<void> expectSettled(List<PhotoEntity> photos) async {
    for (final entry in (await states()).entries) {
      expect(
        entry.value,
        isNot(anyOf(
          TrashState.deleting,
          TrashState.movingToMacTrash,
          TrashState.restoringToCard,
        )),
        reason: '${entry.key} was left mid-operation',
      );
    }

    for (final photo in photos) {
      for (final file in photo.files) {
        final onCard = File(file.path).existsSync();
        if (onCard) continue;
        final relative = p.join('DCIM', photo.folder, file.name);
        final state = (await states())[relative];
        final rescued =
            File(p.join(macTrash.path, photo.key.value, file.name)).existsSync();
        expect(
          state == TrashState.deleted ||
              state == TrashState.uncertain ||
              rescued,
          isTrue,
          reason: '$relative is gone from the card and is neither recorded as '
              'deleted, flagged uncertain, nor rescued to the Mac',
        );
      }
    }
  }

  group('a crash during Empty Trash', () {
    // Every boundary the ordering is built around. At each one the process is
    // assumed dead: whatever was committed before it survives, nothing after it
    // runs, and the next launch has to make sense of what is left.
    for (final step in [
      'empty.beforeIntent',
      'empty.beforeUnlink',
      'empty.beforeOutcome',
    ]) {
      test('at $step leaves nothing in flight and loses nothing', () async {
        await card.addPhoto('L1000001');
        await card.addPhoto('L1000002');
        final photos = await catalogue();
        final marking = serviceCrashingAt(null);
        for (final photo in photos) {
          await marking.mark(photo);
        }

        await expectLater(
          serviceCrashingAt(step).emptyTrash(photos),
          throwsA(isA<_Crash>()),
        );

        // The next launch.
        final report = await serviceCrashingAt(null).reconcile(cardRoot: card.path);

        await expectSettled(photos);
        expect(report.unresolvedLosses, isEmpty,
            reason: 'Empty Trash never has a Mac copy to lose');
      });
    }

    test('a crash before the unlink leaves the photograph on the card',
        () async {
      await card.addPhoto('L1000001');
      final photos = await catalogue();
      await serviceCrashingAt(null).mark(photos.single);

      await expectLater(
        serviceCrashingAt('empty.beforeUnlink').emptyTrash(photos),
        throwsA(isA<_Crash>()),
      );
      await serviceCrashingAt(null).reconcile(cardRoot: card.path);

      // The intent was durable but the deletion never happened, so the user's
      // decision stands and their photograph is still there.
      for (final file in photos.single.files) {
        expect(File(file.path).existsSync(), isTrue, reason: file.name);
      }
      expect((await states()).values, everyElement(TrashState.marked));
    });

    test('a crash after the unlink records the deletion that did happen',
        () async {
      await card.addPhoto('L1000001');
      final photos = await catalogue();
      await serviceCrashingAt(null).mark(photos.single);

      await expectLater(
        serviceCrashingAt('empty.beforeOutcome').emptyTrash(photos),
        throwsA(isA<_Crash>()),
      );
      await serviceCrashingAt(null).reconcile(cardRoot: card.path);

      // One file went; reconciliation reads the card and says so, rather than
      // leaving a row claiming an operation is still running.
      final settled = await states();
      expect(settled.values, contains(TrashState.deleted));
      await expectSettled(photos);
    });
  });

  group('a crash while moving originals to the Mac', () {
    for (final step in [
      'move.beforeIntent',
      'move.beforeCopy',
      'move.beforeUnlink',
      'move.beforeOutcome',
    ]) {
      test('at $step never loses the photograph', () async {
        await card.addPhoto('L1000001');
        final photos = await catalogue();
        await serviceCrashingAt(null).mark(photos.single);

        await expectLater(
          serviceCrashingAt(step).moveToMacTrash(photos.single),
          throwsA(isA<_Crash>()),
        );

        await serviceCrashingAt(null).reconcile(cardRoot: card.path);

        await expectSettled(photos);
        // The property that matters more than any state: at no point was there
        // less than one complete readable copy of the photograph.
        for (final file in photos.single.files) {
          final onCard = File(file.path).existsSync();
          final rescued = File(
            p.join(macTrash.path, photos.single.key.value, file.name),
          ).existsSync();
          expect(onCard || rescued, isTrue, reason: '${file.name} is nowhere');
        }
      });
    }

    test('a crash between the copy and the unlink keeps both, not neither',
        () async {
      await card.addPhoto('L1000001');
      final photos = await catalogue();
      await serviceCrashingAt(null).mark(photos.single);
      final sourceHash = await hashOf(File(photos.single.files.first.path));

      await expectLater(
        serviceCrashingAt('move.beforeUnlink').moveToMacTrash(photos.single),
        throwsA(isA<_Crash>()),
      );

      // Before reconciliation: the original is untouched and a copy exists.
      expect(File(photos.single.files.first.path).existsSync(), isTrue);
      expect(await hashOf(File(photos.single.files.first.path)), sourceHash);

      await serviceCrashingAt(null).reconcile(cardRoot: card.path);

      // Reconciliation moves the unverifiable copy aside and puts the entity
      // back to marked: the card still holds the original, which is the state
      // the user can act on again.
      expect(File(photos.single.files.first.path).existsSync(), isTrue);
      await expectSettled(photos);
    });
  });

  group('restoring what was rescued', () {
    Future<PhotoEntity> movedPhoto() async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      final service = serviceCrashingAt(null);
      await service.mark(photo);
      await service.moveToMacTrash(photo);
      return photo;
    }

    test('puts the bytes back exactly as they were', () async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      final hashes = {
        for (final f in photo.files) f.name: await hashOf(File(f.path)),
      };
      final service = serviceCrashingAt(null);
      await service.mark(photo);
      await service.moveToMacTrash(photo);

      final report = await service.restoreToCard(cardRoot: card.path);

      expect(report.isClean, isTrue);
      for (final file in photo.files) {
        expect(File(file.path).existsSync(), isTrue, reason: file.name);
        expect(await hashOf(File(file.path)), hashes[file.name]);
      }
      // The Mac copy goes only after the card write verified.
      expect(
        Directory(p.join(macTrash.path, photo.key.value)).listSync(),
        isEmpty,
      );
    });

    test('refuses when the name is taken by a different photograph', () async {
      final photo = await movedPhoto();
      // The camera was used again and wrote a new frame over the name.
      await card.addPhoto('L1000001', captureTime: '2026:08:01 17:30:00');
      final intruderBytes = File(photo.files.first.path).readAsBytesSync();

      final report =
          await serviceCrashingAt(null).restoreToCard(cardRoot: card.path);

      // Renaming is forbidden by R19, so this restore is not awkward — it is
      // impossible, and the app says so instead of improvising.
      expect(report.restored, isEmpty);
      expect(
        report.conflicts.map((c) => c.reason),
        contains(TrashConflictReason.nameTakenByAnotherPhotograph),
      );
      expect(File(photo.files.first.path).readAsBytesSync(), intruderBytes);
      // And the rescued bytes are still there, which is the point.
      expect(
        File(p.join(macTrash.path, photo.key.value, 'L1000001.DNG')).existsSync(),
        isTrue,
      );
    });

    test('treats the same photograph already back as done', () async {
      final photo = await movedPhoto();
      // An interrupted earlier restore that got as far as the rename.
      final rescued = File(p.join(macTrash.path, photo.key.value, 'L1000001.DNG'));
      await rescued.copy(photo.files.first.path);

      final report =
          await serviceCrashingAt(null).restoreToCard(cardRoot: card.path);

      expect(report.conflicts, isEmpty);
      expect(File(photo.files.first.path).existsSync(), isTrue);
    });

    test('refuses when the camera folder is gone', () async {
      final photo = await movedPhoto();
      await Directory(p.join(card.path, 'DCIM', '100LEICA')).delete(recursive: true);

      final report =
          await serviceCrashingAt(null).restoreToCard(cardRoot: card.path);

      // Creating the directory would be this app inventing DCF structure on a
      // card, which is exactly what R19 exists to prevent.
      expect(
        report.conflicts.map((c) => c.reason),
        everyElement(TrashConflictReason.cameraFolderGone),
      );
      expect(
        File(p.join(macTrash.path, photo.key.value, 'L1000001.DNG')).existsSync(),
        isTrue,
      );
    });

    for (final step in [
      'restore.beforeIntent',
      'restore.beforeWrite',
      'restore.beforeOutcome',
    ]) {
      test('a crash at $step leaves no debris a camera could see', () async {
        final photo = await movedPhoto();

        await expectLater(
          serviceCrashingAt(step).restoreToCard(cardRoot: card.path),
          throwsA(isA<_Crash>()),
        );

        // Everything actually on the card, measured against the camera files
        // that belong there. Filtering this list by `isCardTempName` before
        // asserting `isCardTempName` — which is what this test used to do —
        // removes the only entries that could fail it, and a file with a
        // camera-lookalike name is precisely the debris that matters: a
        // photographer finds it on their card and dares not touch it.
        final belongs = photo.files.map((f) => f.name).toSet();
        final present = Directory(p.join(card.path, 'DCIM', '100LEICA'))
            .listSync()
            .map((e) => p.basename(e.path))
            .toSet();

        for (final name in present.difference(belongs)) {
          expect(
            isCardTempName(name),
            isTrue,
            reason: '$name survived on the card without the reserved prefix, '
                'so the card-safety pass cannot recognise it as ours',
          );
        }

        await serviceCrashingAt(null).reconcile(cardRoot: card.path);
        await expectSettled([photo]);
      });
    }

    test('a card that goes away mid-write leaves the Mac copy authoritative',
        () async {
      final photo = await movedPhoto();
      final service = TrashService(
        db: db,
        macTrashRoot: macTrash,
        copyOverride: ({required source, required destination, tempName}) async =>
            CopyVolumeGone(destination.path),
      );

      final report = await service.restoreToCard(cardRoot: card.path);

      // Nothing reached the card, so the rescued bytes stay the only copy and
      // the row goes back to saying exactly that.
      expect(report.isClean, isFalse);
      expect(
        File(p.join(macTrash.path, photo.key.value, 'L1000001.DNG')).existsSync(),
        isTrue,
      );
      expect(
        (await states())['DCIM/100LEICA/L1000001.DNG'],
        TrashState.movedToMacTrash,
      );
    });

    test('a cleanup unlink that fails is not recorded as a clean card', () async {
      final photo = await movedPhoto();
      // The rescued copy no longer hashes to what left the card, and the
      // removal of the bad card write cannot be proved. Every row of the
      // entity, not just the first: which file that is is not the test's to
      // assume.
      for (final item
          in await db.trashDao.itemsInState(TrashState.movedToMacTrash)) {
        await db.trashDao.commitOutcome(
          item.id,
          TrashState.movedToMacTrash,
          sourceHash: 'not-the-hash-that-left-the-card',
        );
      }
      final service = TrashService(
        db: db,
        macTrashRoot: macTrash,
        unlinkOverride: (file) async => const UnlinkFailed('read-only card'),
      );

      final report = await service.restoreToCard(cardRoot: card.path);

      // The claim the app must never make is that the card is as it was.
      expect(
        (await states())['DCIM/100LEICA/L1000001.DNG'],
        TrashState.uncertain,
      );
      expect(
        report.conflicts.map((c) => c.detail).join(' '),
        contains('non vérifié'),
      );
      expect(
        File(p.join(macTrash.path, photo.key.value, 'L1000001.DNG')).existsSync(),
        isTrue,
      );
    });
  });

  group('reconciling an interrupted restore', () {
    /// One row put back into `restoringToCard`, as an interrupted run leaves it.
    ///
    /// The row is chosen by its own `cardRelativePath` rather than by taking
    /// the first of a set: a RAW+JPG entity has two, and a test that copies one
    /// file back while asserting about the other passes or fails on row order.
    Future<int> rowRestoringToCard({required bool fileOnCard}) async {
      await card.addPhoto('L1000001');
      final photo = (await catalogue()).single;
      final service = serviceCrashingAt(null);
      await service.mark(photo);
      await service.moveToMacTrash(photo);
      final item = (await db.trashDao.itemsInState(TrashState.movedToMacTrash))
          .firstWhere((i) => i.cardRelativePath.endsWith('.DNG'));
      await db.trashDao.recordIntent(item.id, TrashState.restoringToCard);
      if (fileOnCard) {
        await File(item.macTrashPath!)
            .copy(p.join(card.path, item.cardRelativePath));
      }
      return item.id;
    }

    test('the card write landed, so the photograph is back', () async {
      final id = await rowRestoringToCard(fileOnCard: true);

      await serviceCrashingAt(null).reconcile(cardRoot: card.path);

      final states = await db.trashDao.itemsInState(TrashState.onCard);
      expect(states.map((i) => i.id), contains(id));
    });

    test('the card write did not land, so the Mac copy is still it', () async {
      final id = await rowRestoringToCard(fileOnCard: false);

      await serviceCrashingAt(null).reconcile(cardRoot: card.path);

      final states =
          await db.trashDao.itemsInState(TrashState.movedToMacTrash);
      expect(states.map((i) => i.id), contains(id));
    });
  });

  group('emptying the trash when the card leaves', () {
    test('stops at the file it was on, and counts the entity once', () async {
      await card.addPhoto('L1000001');
      await card.addPhoto('L1000002');
      final photos = await catalogue();
      // A RAW+JPG pair: without a break after the volume goes, the sibling
      // file records an intent and retries against a card known to be gone.
      expect(photos.first.files.length, greaterThan(1));
      final marking = serviceCrashingAt(null);
      for (final photo in photos) {
        await marking.mark(photo);
      }

      final report = await TrashService(
        db: db,
        macTrashRoot: macTrash,
        unlinkOverride: (file) async => VolumeGone(file.path),
      ).emptyTrash(photos);

      expect(report.haltedByVolumeLoss, isTrue);
      // Once per photograph, not once per file of it.
      expect(report.uncertain.length, report.uncertain.toSet().length);
      expect(report.uncertain, hasLength(photos.length));
    });
  });

  group('the outcome families', () {
    test('each carry their own vanished-volume case', () {
      // Not decoration. These are two separate sealed hierarchies, and the bug
      // this guards was one family's value cast into the other — which compiles
      // cleanly and throws only when a card is actually pulled, on the one path
      // the whole file exists to survive.
      expect(const VolumeGone('/Volumes/X'), isA<UnlinkOutcome>());
      expect(const VolumeGone('/Volumes/X'), isNot(isA<CopyOutcome>()));
      expect(const CopyVolumeGone('/Volumes/X'), isA<CopyOutcome>());
      expect(const CopyVolumeGone('/Volumes/X'), isNot(isA<UnlinkOutcome>()));
    });
  });
}
