import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/infra/safety/atomic_ops.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;

  setUp(() async => temp = await Directory.systemTemp.createTemp('obscura_ops'));
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  File file(String name, [String contents = 'the photograph']) {
    final f = File(p.join(temp.path, name))..createSync(recursive: true);
    f.writeAsStringSync(contents);
    return f;
  }

  group('removing a file', () {
    test('reports how many bytes came back', () async {
      final target = file('L1000001.DNG', 'x' * 4096);

      final outcome = await verifiedUnlink(target);

      expect(outcome, isA<Unlinked>());
      expect((outcome as Unlinked).bytesFreed, 4096);
      expect(target.existsSync(), isFalse);
    });

    test('treats a file that was already gone as done, not as a failure',
        () async {
      // An interrupted run that unlinked the file and crashed before recording
      // it lands here on the retry. Failing would leave the row stuck for ever.
      final outcome = await verifiedUnlink(File(p.join(temp.path, 'nothing')));

      expect(outcome, isA<AlreadyAbsent>());
    });

    test('leaves everything else alone', () async {
      final target = file('L1000001.DNG');
      final sibling = file('L1000002.DNG', 'a different photograph');

      await verifiedUnlink(target);

      expect(sibling.existsSync(), isTrue);
      expect(sibling.readAsStringSync(), 'a different photograph');
    });
  });

  group('copying a file off the card', () {
    test('verifies the copy by reading it back', () async {
      final source = file('L1000001.DNG', 'x' * 100000);
      final destination = File(p.join(temp.path, 'trash', 'L1000001.DNG'));

      final outcome = await copyVerified(source: source, destination: destination);

      expect(outcome, isA<CopyVerified>());
      expect(destination.readAsStringSync(), source.readAsStringSync());
      expect((outcome as CopyVerified).hash, await hashOf(source));
      expect(outcome.bytes, 100000);
    });

    test('leaves no half-written file at the destination path', () async {
      final source = file('L1000001.DNG', 'x' * 50000);
      final destination = File(p.join(temp.path, 'trash', 'L1000001.DNG'));

      await copyVerified(source: source, destination: destination);

      // Written through a temp name and renamed, so the destination either does
      // not exist or is complete. A later run must never adopt a partial copy
      // as the rescued original.
      final leftovers = destination.parent
          .listSync()
          .map((e) => p.basename(e.path))
          .where((n) => n.endsWith('.part'));
      expect(leftovers, isEmpty);
    });

    test('says so rather than inventing a copy when the source is gone',
        () async {
      final outcome = await copyVerified(
        source: File(p.join(temp.path, 'nothing.DNG')),
        destination: File(p.join(temp.path, 'trash', 'nothing.DNG')),
      );

      expect(outcome, isA<CopySourceMissing>());
    });

    test('overwrites a stale copy left by an earlier run', () async {
      final source = file('L1000001.DNG', 'the real one');
      final destination = File(p.join(temp.path, 'trash', 'L1000001.DNG'))
        ..createSync(recursive: true)
        ..writeAsStringSync('a stale, shorter one');

      final outcome = await copyVerified(source: source, destination: destination);

      expect(outcome, isA<CopyVerified>());
      expect(destination.readAsStringSync(), 'the real one');
    });
  });

  group('writing a file back to the card', () {
    test('goes through a temp name that cannot be a camera file', () async {
      final destination = File(p.join(temp.path, 'DCIM', '100LEICA', 'L1000001.DNG'));
      await destination.parent.create(recursive: true);
      final bytes = Uint8List.fromList(List.generate(2048, (i) => i % 251));
      final hash = sha256.convert(bytes).toString();

      final outcome = await writeVerified(
        destination: destination,
        bytes: bytes,
        expectedHash: hash,
      );

      expect(outcome, isA<CopyVerified>());
      expect(destination.readAsBytesSync(), bytes);
      // A DCF name is eight characters of [A-Z0-9_] plus an extension, so a
      // leading tilde cannot collide with one and cannot be read as a photo.
      expect(cardTempNameFor('L1000001.DNG').startsWith('~'), isTrue);
      expect(isCardTempName(cardTempNameFor('L1000001.DNG')), isTrue);
      expect(isCardTempName('L1000001.DNG'), isFalse);
    });

    test('refuses to leave bytes that do not hash to what was promised',
        () async {
      final destination = File(p.join(temp.path, 'DCIM', '100LEICA', 'L1000001.DNG'));
      await destination.parent.create(recursive: true);

      final outcome = await writeVerified(
        destination: destination,
        bytes: Uint8List.fromList([1, 2, 3]),
        expectedHash: 'a' * 64,
      );

      // A restore that wrote the wrong bytes and reported success would be the
      // worst failure this app has: the user asked for their photograph back.
      expect(outcome, isA<CopyCorrupt>());
      expect(destination.existsSync(), isFalse);
      expect(
        destination.parent.listSync().where((e) => isCardTempName(p.basename(e.path))),
        isEmpty,
      );
    });
  });

  group('comparing files', () {
    test('two identical files match, and one changed byte does not', () async {
      final a = file('a.bin', 'x' * 4096);
      final b = file('b.bin', 'x' * 4096);
      final c = file('c.bin', '${'x' * 4095}y');

      expect(await sameContents(a, b), isTrue);
      expect(await sameContents(a, c), isFalse);
    });

    test('a truncated file never matches its source', () async {
      // The case that makes hash-verify load-bearing: a copy interrupted
      // half-way is the same at the start and would pass any prefix check.
      final source = file('source.bin', 'x' * 8192);
      final truncated = file('truncated.bin', 'x' * 4096);

      expect(await sameContents(source, truncated), isFalse);
    });

    test('a missing file is not equal to anything', () async {
      expect(
        await sameContents(file('a.bin'), File(p.join(temp.path, 'gone'))),
        isFalse,
      );
    });
  });

  group('locating the volume a path is on', () {
    test('finds the mount root under /Volumes', () {
      expect(
        volumeRootOf('/Volumes/Untitled/DCIM/100LEICA/L1000001.DNG'),
        '/Volumes/Untitled',
      );
      // The volume root's own root is itself, which is what a caller asking
      // "did this mount go away" needs.
      expect(volumeRootOf('/Volumes/Untitled'), '/Volumes/Untitled');
    });

    test('reports nothing for a path that is not on a mounted volume', () {
      // A temp directory during a test, or the startup disk. Neither can
      // "vanish" the way a card does, so neither gets that treatment.
      expect(volumeRootOf('/Users/someone/Pictures/x.jpg'), isNull);
      expect(volumeRootOf('relative/path.jpg'), isNull);
    });
  });
}
