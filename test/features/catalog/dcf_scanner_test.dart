import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/catalog/dcf_scanner.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';

import '../../fixtures/fake_card.dart';

void main() {
  late FakeCard card;
  const scanner = DcfScanner();

  setUp(() async => card = await FakeCard.create());
  tearDown(() async => card.dispose());

  group('pairing', () {
    test('folds a DNG and its JPG sibling into one photograph', () async {
      await card.addPhoto('L1000863');

      final catalog = await scanner.scan(card.path);

      // Two files, one picture. Counting them separately is how a culling tool
      // leaves orphan JPEGs on a card the user believes they cleared.
      expect(catalog.photos, hasLength(1));
      expect(catalog.photos.single.files, hasLength(2));
      expect(catalog.photos.single.formatBadge, 'RAW+JPG');
    });

    test('keeps a DNG-only photograph', () async {
      await card.addPhoto('L1000864', jpeg: false);

      final photo = (await scanner.scan(card.path)).photos.single;

      expect(photo.formatBadge, 'RAW');
      expect(photo.hasJpeg, isFalse);
    });

    test('keeps an orphan JPG', () async {
      await card.addPhoto('L1000865', raw: false);

      final photo = (await scanner.scan(card.path)).photos.single;

      expect(photo.formatBadge, 'JPG');
      expect(photo.hasRaw, isFalse);
    });

    test('spans several DCF folders', () async {
      await card.addPhoto('L1000863');
      await card.addPhoto('L1010001', folder: '101LEICA');

      final catalog = await scanner.scan(card.path);

      expect(catalog.photos, hasLength(2));
      expect(
        catalog.photos.map((p) => p.folder).toSet(),
        {'100LEICA', '101LEICA'},
      );
    });
  });

  group('what the scan refuses to touch', () {
    test('ignores the camera bookkeeping folder', () async {
      await card.addPhoto('L1000863');
      await card.addCameraPrivateFolder();

      final catalog = await scanner.scan(card.path);

      // PRIVATE/ holds the camera's own index and fastload files. Reading it is
      // pointless and writing it would be reckless; the walk never leaves DCIM.
      expect(catalog.photos, hasLength(1));
      expect(catalog.unsupportedFiles, isEmpty);
    });

    test('ignores macOS debris rather than cataloguing it', () async {
      await card.addPhoto('L1000863');
      await card.addMacosDebris();

      final catalog = await scanner.scan(card.path);

      expect(catalog.photos, hasLength(1));
      expect(catalog.unsupportedFiles, isEmpty);
    });

    test('reports video instead of silently dropping it', () async {
      await card.addPhoto('L1000863');
      await card.addUnsupportedFile('L1000900.MP4');

      final catalog = await scanner.scan(card.path);

      // A card reporting "1 photo" while still holding gigabytes of video would
      // mislead someone deciding whether it is safe to reformat.
      expect(catalog.photos, hasLength(1));
      expect(catalog.unsupportedFiles, ['100LEICA/L1000900.MP4']);
    });

    test('returns an empty catalog for a folder with no DCIM', () async {
      final catalog = await scanner.scan('/nowhere/at/all');

      expect(catalog.photos, isEmpty);
      expect(catalog.unsupportedFiles, isEmpty);
    });
  });

  group('identity', () {
    test('survives the card being mounted somewhere else', () async {
      await card.addPhoto('L1000863');
      final first = (await scanner.scan(card.path)).photos.single;

      final moved = await card.remountElsewhere();
      addTearDown(moved.dispose);
      final second = (await scanner.scan(moved.path)).photos.single;

      // The whole point of the composite key: layers and exports must find
      // their photograph again after a remount changes every absolute path.
      expect(second.key, first.key);
      expect(second.key.basis, StableKeyBasis.exif);
    });

    test('separates two photographs the camera gave the same name', () async {
      await card.addPhoto('L1000001', captureTime: '2026:03:14 09:26:53');
      final before = (await scanner.scan(card.path)).photos.single;

      // A numbering reset makes the camera reissue 100LEICA/L1000001 for a
      // completely different picture.
      await card.dispose();
      card = await FakeCard.create();
      await card.addPhoto('L1000001', captureTime: '2026:08:11 17:03:12');
      final after = (await scanner.scan(card.path)).photos.single;

      expect(after.key, isNot(before.key));
    });

    test('separates the same frame number shot on two bodies', () async {
      await card.addPhoto('L1000001', serial: '5301234');
      final first = (await scanner.scan(card.path)).photos.single;

      await card.dispose();
      card = await FakeCard.create();
      await card.addPhoto('L1000001', serial: 'REDACTED');
      final second = (await scanner.scan(card.path)).photos.single;

      expect(second.key, isNot(first.key));
    });

    test('falls back to file stat when the header cannot be read', () async {
      await card.addCorruptPhoto('L1000999');

      final photo = (await scanner.scan(card.path)).photos.single;

      // Weaker identity, but the photograph is still catalogued: an
      // uncatalogued file cannot be deleted either, and deleting it is exactly
      // what a user wants from a frame the camera mangled.
      expect(photo.key.basis, StableKeyBasis.fileStat);
      expect(photo.isUnreadable, isTrue);
      expect(photo.captureTime, isNull);
    });
  });

  group('what the scan records for later', () {
    test('captures the preview ranges so decoding never re-walks the IFDs',
        () async {
      await card.addPhoto('L1000863');

      final photo = (await scanner.scan(card.path)).photos.single;

      expect(photo.gridPreview, isNotNull);
      expect(photo.viewerPreview, isNotNull);
      expect(photo.gridPreview!.length,
          lessThanOrEqualTo(photo.viewerPreview!.length));
    });

    test('reads the capture time and body serial', () async {
      await card.addPhoto('L1000863', serial: 'REDACTED');

      final photo = (await scanner.scan(card.path)).photos.single;

      expect(photo.captureTime, isNotNull);
      expect(photo.bodySerial, 'REDACTED');
    });

    test('totals the bytes of every file in the photograph', () async {
      await card.addPhoto('L1000863');

      final photo = (await scanner.scan(card.path)).photos.single;

      expect(
        photo.totalBytes,
        photo.files.fold<int>(0, (sum, f) => sum + f.sizeBytes),
      );
      expect(photo.totalBytes, greaterThan(0));
    });
  });

  group('ordering', () {
    test('lists photographs in the order they were taken', () async {
      await card.addPhoto('L1000900', captureTime: '2026:03:14 11:00:00');
      await card.addPhoto('L1000863', captureTime: '2026:03:14 09:26:53');

      final catalog = await scanner.scan(card.path);

      expect(catalog.photos.map((p) => p.radical), ['L1000863', 'L1000900']);
    });

    test('puts photographs with no readable time last, in DCF order', () async {
      await card.addPhoto('L1000863', captureTime: '2026:03:14 09:26:53');
      await card.addCorruptPhoto('L1000999');

      final catalog = await scanner.scan(card.path);

      expect(catalog.photos.map((p) => p.radical), ['L1000863', 'L1000999']);
    });
  });
}
