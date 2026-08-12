import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/catalog/photo_entity.dart';
import 'package:obscura_pro/features/catalog/stable_key.dart';
import 'package:obscura_pro/features/crop/crop_screen.dart'
    show exportFolderProvider, exportServiceProvider;
import 'package:obscura_pro/features/crop/export_service.dart';
import 'package:obscura_pro/features/crop/ratio.dart';
import 'package:obscura_pro/features/exports/batch_export.dart';
import 'package:obscura_pro/features/exports/export_marks.dart';
import 'package:obscura_pro/features/exports/export_store.dart';
import 'package:obscura_pro/infra/preview/preview_extractor.dart';

/// Writing the frames a photographer picked.
void main() {
  late _RecordingExport service;
  late InMemoryExportStore store;
  late InMemoryExportMarkStore marks;
  late ProviderContainer container;

  setUp(() {
    service = _RecordingExport();
    store = InMemoryExportStore();
    marks = InMemoryExportMarkStore();
    container = ProviderContainer(
      overrides: [
        exportServiceProvider.overrideWithValue(service),
        exportStoreProvider.overrideWithValue(store),
        exportMarkStoreProvider.overrideWithValue(marks),
        exportFolderProvider.overrideWith((ref) async => Directory('/tmp/x')),
      ],
    );
    addTearDown(container.dispose);
  });

  BatchProgress progress() => container.read(batchExporterProvider);

  Future<void> markAll(List<PhotoEntity> photos) async {
    for (final photo in photos) {
      await container.read(exportMarksProvider.notifier).toggle(photo);
    }
  }

  test('exports every marked frame and leaves the rest alone', () async {
    final photos = [_photo('L1000001'), _photo('L1000002'), _photo('L1000003')];
    await markAll([photos.first, photos.last]);

    await container.read(batchExporterProvider.notifier).run(photos);

    expect(service.exported, ['L1000001', 'L1000003']);
    expect(progress().done, 2);
    expect(progress().failures, isEmpty);
    expect(progress().running, isFalse);
  });

  test('exports the whole frame', () async {
    final photos = [_photo('L1000001')];
    await markAll(photos);

    await container.read(batchExporterProvider.notifier).run(photos);

    // A 3:2 frame cut to 3:2 is the entire photograph: the point of this queue
    // is the frames themselves, at the size the card allows. Cropping is a
    // decision made one frame at a time, elsewhere.
    final crop = service.crops.single;
    expect(crop.ratio, CropRatio.threeTwo);
    expect(crop.rect.width, closeTo(1, 1e-9));
    expect(crop.rect.height, closeTo(1, 1e-9));
  });

  test('a portrait frame keeps its orientation', () async {
    final photos = [_photo('L1000001', portrait: true)];
    await markAll(photos);

    await container.read(batchExporterProvider.notifier).run(photos);

    final crop = service.crops.single;
    expect(crop.orientation, CropOrientation.portrait);
    expect(crop.rect.width, closeTo(1, 1e-9));
  });

  test('takes the mark off as each file lands', () async {
    final photos = [_photo('L1000001'), _photo('L1000002')];
    await markAll(photos);

    await container.read(batchExporterProvider.notifier).run(photos);

    // The queue is a list of work: interrupted halfway, what is still marked is
    // exactly what is left to do.
    expect(container.read(exportMarksProvider).isEmpty, isTrue);
    expect(await marks.markedKeys(), isEmpty);
  });

  test('one frame that fails does not stop the others', () async {
    final photos = [_photo('L1000001'), _photo('L1000002'), _photo('L1000003')];
    await markAll(photos);
    service.failOn.add('L1000002');

    await container.read(batchExporterProvider.notifier).run(photos);

    expect(progress().done, 2);
    expect(progress().failures.single, contains('L1000002'));
    // And the one that failed stays marked, because it still has to be done.
    expect(container.read(exportMarksProvider).length, 1);
  });

  test('records each file it wrote', () async {
    final photos = [_photo('L1000001')];
    await markAll(photos);

    await container.read(batchExporterProvider.notifier).run(photos);

    expect(store.recorded, hasLength(1));
  });

  test('a frame from another card waits for it', () async {
    final onThisCard = _photo('L1000001');
    final elsewhere = _photo('L1009999');
    await markAll([onThisCard, elsewhere]);

    // Only the photographs the open card actually holds are passed in.
    await container.read(batchExporterProvider.notifier).run([onThisCard]);

    expect(service.exported, ['L1000001']);
    // The other mark is untouched: its bytes are on a card in a drawer.
    expect(container.read(exportMarksProvider).length, 1);
  });

  test('nothing marked is nothing done', () async {
    await container.read(batchExporterProvider.notifier).run([_photo('L1')]);

    expect(service.exported, isEmpty);
    expect(progress().isIdle, isTrue);
  });
}

/// An export that writes nothing and remembers everything.
class _RecordingExport implements ExportService {
  final List<String> exported = [];
  final List<CropRect> crops = [];
  final Set<String> failOn = {};

  @override
  int get quality => 92;

  @override
  Future<ExportOutcome> export({
    required PhotoEntity photo,
    required CropRect crop,
    required Directory folder,
    DateTime? now,
    void Function(ExportStage stage)? onStage,
  }) async {
    onStage?.call(ExportStage.reading);
    if (failOn.contains(photo.radical)) {
      return const ExportFailed('pas de preview lisible');
    }
    onStage?.call(ExportStage.writing);
    exported.add(photo.radical);
    crops.add(crop);
    return ExportWritten(
      path: '${folder.path}/${photo.radical}_3x2_01.jpg',
      pixelWidth: 9520,
      pixelHeight: 6336,
      bytes: 2048,
    );
  }
}

PhotoEntity _photo(String radical, {bool portrait = false}) => PhotoEntity(
      radical: radical,
      folder: '100LEICA',
      key: StableKey.fromExif(
        dcfRadical: '100LEICA/$radical',
        captureTime: DateTime.utc(2026, 3, 14, 9, 26, 53),
        bodySerial: '5301234',
      ),
      files: const [],
      orientation:
          portrait ? ExifOrientation.rotate90 : ExifOrientation.normal,
      viewerPreview: const PreviewStream(
        offset: 4096,
        length: 20000,
        kind: PreviewStreamKind.jpegStrips,
        width: 9520,
        height: 6336,
      ),
    );
