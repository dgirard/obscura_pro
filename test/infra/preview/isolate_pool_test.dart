import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obscura_pro/infra/preview/isolate_pool.dart';
import 'package:obscura_pro/infra/preview/preview_extractor.dart';

import 'tiff_fixture.dart';

void main() {
  late Directory temp;
  late _Fixture dng;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('obscura_pool');
    dng = await _writeDecodableDng(temp, name: 'L1000863.DNG');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('the decode itself', () {
    test('reads a preview out of the middle of a file and downscales it',
        () async {
      final result = await renderThumbnail(
        ThumbnailRequest(
          filePath: dng.path,
          offset: dng.small.offset,
          length: dng.small.length,
          targetShortSide: 40,
        ),
      );

      // The source thumbnail is 128x85; asking for a 40-pixel short side must
      // preserve the aspect, not letterbox or square it.
      expect(result.height, 40);
      expect(result.width, closeTo(60, 1));

      final decoded = img.decodeJpg(result.takeBytes());
      expect(decoded, isNotNull);
      expect(decoded!.height, 40);
    });

    test('never upscales, and hands back the source bytes when it does not resize',
        () async {
      final source = await _readRange(dng.path, dng.small.offset, dng.small.length);

      final result = await renderThumbnail(
        ThumbnailRequest(
          filePath: dng.path,
          offset: dng.small.offset,
          length: dng.small.length,
          targetShortSide: 4000,
        ),
      );

      expect(result.width, 128);
      expect(result.height, 85);
      // Re-encoding an unchanged image would spend a JPEG generation to make a
      // slightly worse copy of bytes we already hold.
      expect(result.takeBytes(), source);
    });

    test('reports the average colour of what it decoded', () async {
      final result = await renderThumbnail(
        ThumbnailRequest(
          filePath: dng.path,
          offset: dng.small.offset,
          length: dng.small.length,
          targetShortSide: 40,
        ),
      );

      // The fixture is a red-by-x, green-by-y ramp over a constant blue, so its
      // mean sits near the middle of the first two channels and exactly on the
      // third.
      final color = result.averageColor;
      expect((color >> 24) & 0xFF, 0xFF);
      expect((color >> 16) & 0xFF, closeTo(127, 20));
      expect((color >> 8) & 0xFF, closeTo(127, 20));
      expect(color & 0xFF, closeTo(128, 12));
    });

    test('fails on a range that runs past the end of the file', () async {
      await expectLater(
        renderThumbnail(
          ThumbnailRequest(
            filePath: dng.path,
            offset: dng.small.offset,
            length: dng.small.length + 1000000,
            targetShortSide: 40,
          ),
        ),
        throwsA(isA<ThumbnailDecodeException>()),
      );
    });

    test('fails on bytes that are not a JPEG', () async {
      await expectLater(
        renderThumbnail(
          ThumbnailRequest(
            filePath: dng.path,
            offset: 0,
            length: 64,
            targetShortSide: 40,
          ),
        ),
        throwsA(isA<ThumbnailDecodeException>()),
      );
    });
  });

  group('the pool', () {
    late DecodePool pool;

    tearDown(() => pool.dispose());

    test('runs a batch across its workers and returns every result', () async {
      pool = DecodePool(workers: 2);

      final results = await Future.wait([
        for (var i = 0; i < 8; i++) pool.decode(_request(dng, target: 40))
      ]);

      expect(results, hasLength(8));
      for (final result in results) {
        expect(result.height, 40);
      }
      expect(pool.liveWorkers, 2);
    });

    test('drops queued requests carrying a cancelled tag', () async {
      pool = DecodePool(workers: 1);
      await pool.start();

      final keep = pool.decode(_request(dng, target: 40), tag: 'keep');
      final drop = pool.decode(_request(dng, target: 40), tag: 'drop');
      final alsoKeep = pool.decode(_request(dng, target: 40), tag: 'keep');

      // A cell that has scrolled out of view withdraws its request.
      pool.cancel('drop');

      await expectLater(drop, throwsA(isA<DecodeCancelled>()));
      expect((await keep).height, 40);
      expect((await alsoKeep).height, 40);
    });

    test('cancelling a tag nothing is queued under changes nothing', () async {
      pool = DecodePool(workers: 1);

      final work = pool.decode(_request(dng, target: 40), tag: 'a');
      pool.cancel('b');

      expect((await work).height, 40);
    });

    test('drops the oldest waiting request when the queue is full', () async {
      // The oldest waiting request is the cell furthest behind the viewport, so
      // it is the one a scrolling grid can most afford to lose.
      pool = DecodePool(workers: 1, queueLimit: 2);

      final oldest = pool.decode(_request(dng, target: 40), tag: 'a');
      final middle = pool.decode(_request(dng, target: 40), tag: 'b');
      final newest = pool.decode(_request(dng, target: 40), tag: 'c');

      await expectLater(oldest, throwsA(isA<DecodeCancelled>()));
      expect((await middle).height, 40);
      expect((await newest).height, 40);
    });

    test('reports a bad range as a decode failure rather than hanging',
        () async {
      pool = DecodePool(workers: 1);

      await expectLater(
        pool.decode(
          ThumbnailRequest(
            filePath: dng.path,
            offset: 0,
            length: 64,
            targetShortSide: 40,
          ),
        ),
        throwsA(isA<ThumbnailDecodeException>()),
      );

      // The worker survives a failed job: one bad file must not cost the pool a
      // worker for the rest of the session.
      expect((await pool.decode(_request(dng, target: 40))).height, 40);
    });

    test('fails everything still pending when disposed', () async {
      pool = DecodePool(workers: 1);

      // Handlers are attached before disposing, not after: a future that is
      // failed while nobody is listening reports an uncaught error, which is
      // itself worth not doing to the app.
      final settled = [
        for (var i = 0; i < 4; i++)
          pool.decode(_request(dng, target: 40)).then<Object?>(
                (result) => result,
                onError: (Object error) => error,
              )
      ];
      await pool.dispose();

      // Some may already have completed; none may be left waiting forever.
      for (final outcome in await Future.wait(settled)) {
        expect(outcome, anyOf(isA<ThumbnailBytes>(), isA<DecodeCancelled>()));
      }
    });
  });
}

ThumbnailRequest _request(_Fixture dng, {required int target}) => ThumbnailRequest(
      filePath: dng.path,
      offset: dng.small.offset,
      length: dng.small.length,
      targetShortSide: target,
    );

class _Fixture {
  _Fixture(this.path, this.small, this.full);

  final String path;
  final PreviewStream small;
  final PreviewStream full;
}

/// Writes a DNG carrying real, decodable previews and locates them the way the
/// app does — by parsing the header, not by guessing offsets.
Future<_Fixture> _writeDecodableDng(Directory dir, {required String name}) async {
  final dng = buildSyntheticDng(decodable: true);
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(dng.bytes);

  final scan = scanPhotoHeader(dng.bytes);
  final header = (scan as PreviewScanSuccess).header;
  return _Fixture(file.path, header.gridPreview!, header.viewerPreview!);
}

Future<Uint8List> _readRange(String path, int offset, int length) async {
  final handle = await File(path).open();
  try {
    await handle.setPosition(offset);
    return await handle.read(length);
  } finally {
    await handle.close();
  }
}
