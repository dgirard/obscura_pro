import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/infra/safety/atomic_ops.dart';
import 'package:obscura_pro/infra/safety/io_errors.dart';
import 'package:obscura_pro/infra/safety/parasite_guard.dart';
import 'package:path/path.dart' as p;

import '../../fixtures/fake_card.dart';

void main() {
  late FakeCard card;
  const guard = ParasiteGuard();

  setUp(() async {
    card = await FakeCard.create();
    await card.addPhoto('L1000001');
  });

  tearDown(() async => card.dispose());

  File plant(String relative, [String contents = 'debris']) {
    final f = File(p.join(card.path, relative))..createSync(recursive: true);
    f.writeAsStringSync(contents);
    return f;
  }

  Set<String> namesUnderCamera() => Directory(p.join(card.path, 'DCIM', '100LEICA'))
      .listSync()
      .map((e) => p.basename(e.path))
      .toSet();

  group('finding what should not be there', () {
    test('reports the dotfiles a Mac leaves, and deletes nothing', () async {
      plant('.DS_Store');
      plant('DCIM/100LEICA/._L1000001.DNG');
      plant('.Spotlight-V100/store.db');

      final report = await guard.scan(card.path);

      expect(
        report.foreign.map((f) => f.relativePath),
        containsAll(['.DS_Store', 'DCIM/100LEICA/._L1000001.DNG', '.Spotlight-V100']),
      );
      // Finding and removing are separate calls. A cleaner that walks a card
      // deciding for itself what is rubbish is one bug from a lost frame.
      expect(File(p.join(card.path, '.DS_Store')).existsSync(), isTrue);
    });

    test('does not mistake a photograph for debris', () async {
      final report = await guard.scan(card.path);

      expect(report.isClean, isTrue);
      expect(report.scanned, greaterThan(0));
    });

    test('reports a `.fseventsd` directory as one thing, not its contents',
        () async {
      // Exactly what macOS created on the measured card, at mount time, before
      // this app was involved at all.
      plant('.fseventsd/fseventsd-uuid');

      final report = await guard.scan(card.path);

      final found = report.foreign.where((f) => f.relativePath == '.fseventsd');
      expect(found, hasLength(1));
      expect(found.single.isDirectory, isTrue);
      // Not descended into: the whole thing goes or nothing does.
      expect(
        report.found.map((f) => f.relativePath),
        isNot(contains('.fseventsd/fseventsd-uuid')),
      );
    });

    test('tells our own debris apart from the operating system\'s', () async {
      plant('DCIM/100LEICA/${cardTempNameFor('L1000009.DNG')}');
      plant('.DS_Store');

      final report = await guard.scan(card.path);

      expect(report.ourOwnDebris.map((f) => p.basename(f.path)),
          ['~OBSCURA-L1000009.DNG']);
      expect(report.foreign.map((f) => f.relativePath), ['.DS_Store']);
    });

    test('reports what is inside PRIVATE but refuses to remove it', () async {
      plant('PRIVATE/.DS_Store');

      final report = await guard.scan(card.path);
      final inPrivate =
          report.found.where((f) => f.relativePath.startsWith('PRIVATE'));

      // The camera's own bookkeeping is not ours to repair. Reported anyway: a
      // photographer deserves to know what is on their card even when the
      // answer is "and I will not deal with it".
      expect(inPrivate, hasLength(1));
      expect(inPrivate.single.removable, isFalse);
    });
  });

  group('cleaning up', () {
    test('removes our own debris without being asked, and only that', () async {
      plant('DCIM/100LEICA/${cardTempNameFor('L1000009.DNG')}');
      plant('.DS_Store');

      final report = await guard.removeOwnDebris(card.path);

      expect(report.removed, ['DCIM/100LEICA/~OBSCURA-L1000009.DNG']);
      // The operating system's debris is the user's call, not ours.
      expect(File(p.join(card.path, '.DS_Store')).existsSync(), isTrue);
      // And the photographs are exactly where they were.
      expect(namesUnderCamera(), {'L1000001.DNG', 'L1000001.JPG'});
    });

    test('removes exactly the list it was given', () async {
      plant('.DS_Store');
      plant('DCIM/100LEICA/._L1000001.DNG');
      final all = (await guard.scan(card.path)).foreign.toList();
      final onlyTheDsStore =
          all.where((f) => f.relativePath == '.DS_Store').toList();

      final report = await guard.remove(onlyTheDsStore);

      expect(report.isClean, isTrue);
      expect(File(p.join(card.path, '.DS_Store')).existsSync(), isFalse);
      expect(
        File(p.join(card.path, 'DCIM/100LEICA/._L1000001.DNG')).existsSync(),
        isTrue,
      );
    });

    test('refuses a path that is not a parasite name', () async {
      final photograph = Parasite(
        path: p.join(card.path, 'DCIM', '100LEICA', 'L1000001.DNG'),
        relativePath: 'DCIM/100LEICA/L1000001.DNG',
        kind: ParasiteKind.foreign,
        bytes: 1,
        isDirectory: false,
      );

      final report = await guard.remove([photograph]);

      // Belt and braces against a caller handing over a photograph. The one
      // mistake this file must never make.
      expect(report.removed, isEmpty);
      expect(report.refused, hasLength(1));
      expect(namesUnderCamera(), contains('L1000001.DNG'));
    });

    test('refuses anything inside PRIVATE', () async {
      plant('PRIVATE/.DS_Store');
      final inPrivate = (await guard.scan(card.path))
          .found
          .where((f) => f.relativePath.startsWith('PRIVATE'))
          .toList();

      final report = await guard.remove(inPrivate);

      expect(report.removed, isEmpty);
      expect(File(p.join(card.path, 'PRIVATE/.DS_Store')).existsSync(), isTrue);
    });

    test('takes a whole `.Spotlight-V100` tree in one go', () async {
      plant('.Spotlight-V100/store.db');
      plant('.Spotlight-V100/nested/more.db');
      final tree = (await guard.scan(card.path)).foreign.toList();

      final report = await guard.remove(tree);

      expect(report.isClean, isTrue);
      expect(Directory(p.join(card.path, '.Spotlight-V100')).existsSync(), isFalse);
      expect((await guard.scan(card.path)).isClean, isTrue);
    });
  });

  group('classifying what went wrong', () {
    // Paths under a temp directory rather than under /Volumes on purpose: the
    // volume check is a real filesystem question, and a test that hardcoded a
    // mount point would pass or fail depending on what happened to be plugged
    // into the machine.
    test('a read-only card is a loquet, not a broken card', () {
      final failure = classifyCardFailure(
        FileSystemException('write failed', p.join(card.path, 'x'),
            const OSError('Read-only file system', 30)),
      );

      expect(failure.kind, CardFailureKind.readOnly);
      expect(failure.disablesWriting, isTrue);
      expect(failure.halts, isFalse);
      // Telling a photographer their card is broken when they have left the
      // write-protect switch on is the failure this classification prevents.
      expect(failure.message, contains('loquet'));
    });

    test('a vanished volume halts everything', () {
      // Both signals, independently: the errno a pulled card produces, and a
      // mount point that is no longer there.
      expect(
        classifyCardFailure(
          const FileSystemException('no such device', '/Volumes/GoneAway/DCIM/x',
              OSError('No such device', 19)),
        ).kind,
        CardFailureKind.volumeGone,
      );
      final byMissingMount = classifyCardFailure(
        const FileSystemException('not found', '/Volumes/GoneAway/DCIM/x',
            OSError('No such file or directory', 2)),
      );

      expect(byMissingMount.kind, CardFailureKind.volumeGone);
      expect(byMissingMount.halts, isTrue);
    });

    test('a missing file on a card that is still there is not a vanished card',
        () async {
      // The distinction the volume check exists for: the same errno means two
      // very different things depending on whether the mount survived.
      final failure = classifyCardFailure(
        FileSystemException('not found', p.join(card.path, 'nope.DNG'),
            const OSError('No such file or directory', 2)),
      );

      expect(failure.kind, isNot(CardFailureKind.volumeGone));
      expect(failure.halts, isFalse);
    });

    test('a medium error says to rescue what is left', () {
      final failure = classifyCardFailure(
        FileSystemException('read failed', p.join(card.path, 'x'),
            const OSError('Input/output error', 5)),
      );

      expect(failure.kind, CardFailureKind.mediumError);
      expect(failure.message, contains('lisible'));
    });
  });

  group('asking whether the card can be written to', () {
    test('says yes for an ordinary card, and leaves nothing behind', () async {
      expect(await cardAcceptsWrites(card.path), isTrue);

      // The probe carries the reserved prefix, so even a crash mid-probe leaves
      // something the cleanup pass recognises as ours.
      expect((await guard.scan(card.path)).isClean, isTrue);
    });

    test('says no for a path that does not exist', () async {
      expect(await cardAcceptsWrites('/Volumes/NotAThing'), isFalse);
    });
  });
}
