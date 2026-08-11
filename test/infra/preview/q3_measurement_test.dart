// Measures a real Leica Q3 DNG so the preview pipeline is sized against facts
// instead of assumptions.
//
// The parser is developed against forged fixtures, which can prove it reads the
// TIFF grammar correctly but can say nothing about what a genuine Q3 file
// actually contains. Point this at a card or a copied sample and it reports the
// numbers the pipeline needs:
//
//   Q3_DIR=/Volumes/<card>/DCIM/100LEICA flutter test \
//     test/infra/preview/q3_measurement_test.dart
//
// Skips when Q3_DIR is unset, so the suite stays green without hardware.
// Strictly read-only; it never writes to the card.
//
// ignore_for_file: avoid_print -- reporting the measurements to whoever ran it
// is this file's entire purpose; the assertions only guard the conclusions.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/infra/preview/preview_extractor.dart';

const _candidatePrefixes = [
  8 * 1024,
  16 * 1024,
  32 * 1024,
  64 * 1024,
  128 * 1024,
  256 * 1024,
  512 * 1024,
];

void main() {
  final dir = Platform.environment['Q3_DIR'];

  group(
    'a real Q3 card',
    skip: dir == null ? 'set Q3_DIR to a DCF folder to measure hardware' : null,
    () {
      late List<File> dngs;

      setUpAll(() async {
        dngs = await Directory(dir!)
            .list()
            .where((e) => e is File && e.path.toUpperCase().endsWith('.DNG'))
            .cast<File>()
            .toList();
        dngs.sort((a, b) => a.path.compareTo(b.path));
      });

      test('carries embedded previews the grid and viewer can use', () async {
        expect(dngs, isNotEmpty, reason: 'no DNG in $dir');
        final file = dngs.first;
        final length = await file.length();

        final handle = await file.open();
        addTearDown(handle.close);
        final result = scanPhotoHeader(
          await handle.read(kHeaderPrefixBytes),
          fileLength: length,
        );

        expect(result, isA<PreviewScanSuccess>());
        final header = (result as PreviewScanSuccess).header;

        print('\n== ${file.uri.pathSegments.last} (${_mb(length)}) ==');
        print('  DateTimeOriginal : ${header.dateTimeOriginal}');
        print('  Body serial      : ${header.bodySerial}');
        print('  Preview streams  : ${header.previews.length}');

        for (final p in header.previews) {
          // Read the ends of the declared range: this is what proves the offsets
          // point at a real JPEG rather than at plausible-looking garbage.
          await handle.setPosition(p.offset);
          final head = await handle.read(2);
          await handle.setPosition(p.offset + p.length - 2);
          final tail = await handle.read(2);
          final intact = head[0] == 0xFF &&
              head[1] == 0xD8 &&
              tail[0] == 0xFF &&
              tail[1] == 0xD9;

          print('    - ${p.kind.name.padRight(17)}'
              ' ${'${p.width}x${p.height}'.padRight(12)}'
              ' ${_mb(p.length).padLeft(9)}'
              ' reduced=${p.reducedResolution}'
              ' jpeg=${intact ? 'ok' : 'BROKEN'}');

          expect(intact, isTrue, reason: 'stream at ${p.offset} is not a JPEG');
        }

        print('  Grid variant     : ${_describe(header.gridPreview)}');
        print('  Viewer variant   : ${_describe(header.viewerPreview)}');

        // The whole speed premise: a full-size encoded frame is already in the
        // file, so nothing ever has to demosaic the RAW to show a photograph.
        expect(header.previews.length, greaterThanOrEqualTo(2));
        expect(header.dateTimeOriginal, isNotNull);
      });

      test('resolves its header from a bounded read', () async {
        final file = dngs.first;
        final length = await file.length();
        final handle = await file.open();
        addTearDown(handle.close);

        int? smallest;
        print('\n== minimum header read ==');
        for (final candidate in _candidatePrefixes) {
          await handle.setPosition(0);
          final result = scanPhotoHeader(
            await handle.read(candidate),
            fileLength: length,
          );
          final ok = result is PreviewScanSuccess &&
              result.header.previews.isNotEmpty &&
              result.header.dateTimeOriginal != null;
          smallest ??= ok ? candidate : null;
          print('  ${_kb(candidate).padLeft(8)} -> ${ok ? 'resolves' : result.runtimeType}');
        }

        print('  smallest that resolves: ${smallest == null ? 'none tested' : _kb(smallest)}'
            '   (kHeaderPrefixBytes = ${_kb(kHeaderPrefixBytes)})');

        expect(smallest, isNotNull,
            reason: 'no bounded read resolved the header; the catalog scan '
                'would have to read whole files');
      });

      test('scans a full folder fast enough to fill a grid', () async {
        print('\n== scan timing (header read + parse) ==');
        for (final readSize in [8 * 1024, 16 * 1024, 64 * 1024]) {
          final watch = Stopwatch()..start();
          var resolved = 0;
          for (final file in dngs) {
            final handle = await file.open();
            final result = scanPhotoHeader(
              await handle.read(readSize),
              fileLength: await file.length(),
            );
            await handle.close();
            if (result is PreviewScanSuccess && result.header.previews.isNotEmpty) {
              resolved++;
            }
          }
          watch.stop();
          print('  ${_kb(readSize).padLeft(8)} read: ${watch.elapsedMilliseconds} ms'
              ' for ${dngs.length} files'
              ' (${(watch.elapsedMilliseconds / dngs.length).toStringAsFixed(1)} ms/file),'
              ' $resolved resolved');
        }
      }, timeout: const Timeout(Duration(minutes: 10)));
    },
  );
}

String _describe(PreviewStream? p) =>
    p == null ? 'none' : '${p.width}x${p.height} (${_mb(p.length)}, ${p.kind.name})';

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
String _kb(int bytes) => '${(bytes / 1024).round()} KB';
