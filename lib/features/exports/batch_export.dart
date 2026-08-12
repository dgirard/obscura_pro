import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/photo_entity.dart';
import '../crop/crop_screen.dart' show exportFolderProvider, exportServiceProvider;
import '../crop/export_service.dart';
import '../crop/ratio.dart';
import 'export_marks.dart';
import 'export_store.dart';

/// How far a run of exports has got.
@immutable
class BatchProgress {
  const BatchProgress({
    this.done = 0,
    this.total = 0,
    this.current,
    this.stage,
    this.failures = const [],
    this.running = false,
  });

  final int done;
  final int total;

  /// The radical of the photograph being written, for the line on screen.
  final String? current;

  final ExportStage? stage;

  /// What went wrong, per photograph. Collected rather than thrown: one frame
  /// with no readable preview must not stop the other eleven.
  final List<String> failures;

  final bool running;

  bool get isIdle => !running && done == 0 && failures.isEmpty;
}

/// Exports every marked photograph, whole.
///
/// Whole rather than cropped: a crop is a decision made frame by frame in the
/// crop screen, and this is the other thing a photographer wants — the frames
/// they picked, as files, at the size the card allows. A frame that was cropped
/// and exported already has its file; this does not touch it.
///
/// One at a time, and the mark comes off as each file lands. That makes the
/// queue survivable: interrupted halfway, what is left marked is exactly what
/// is left to do.
class BatchExporter extends Notifier<BatchProgress> {
  @override
  BatchProgress build() => const BatchProgress();

  Future<void> run(List<PhotoEntity> photos) async {
    if (state.running) return;
    final marks = ref.read(exportMarksProvider);
    final queue =
        photos.where((p) => marks.contains(p.key.value)).toList(growable: false);
    if (queue.isEmpty) return;

    state = BatchProgress(total: queue.length, running: true);

    final Directory folder;
    try {
      folder = await ref.read(exportFolderProvider.future);
    } on Object catch (error) {
      state = BatchProgress(
        total: queue.length,
        failures: ['Le dossier d\'export est introuvable : $error'],
      );
      return;
    }

    final service = ref.read(exportServiceProvider);
    final store = ref.read(exportStoreProvider);
    final failures = <String>[];
    var done = 0;

    for (final photo in queue) {
      if (!ref.mounted) return;
      state = BatchProgress(
        done: done,
        total: queue.length,
        current: photo.radical,
        running: true,
        failures: failures,
      );

      final crop = wholeFrame(photo);
      final ExportOutcome outcome;
      try {
        outcome = await service.export(
          photo: photo,
          crop: crop,
          folder: folder,
          onStage: (stage) {
            if (!ref.mounted) return;
            state = BatchProgress(
              done: done,
              total: queue.length,
              current: photo.radical,
              stage: stage,
              running: true,
              failures: failures,
            );
          },
        );
      } on Object catch (error) {
        failures.add('${photo.radical} : $error');
        continue;
      }

      switch (outcome) {
        case ExportWritten():
          try {
            await store.record(photo: photo, crop: crop, written: outcome);
          } on Object catch (error) {
            // The file is on disk, which is the half that matters. What is lost
            // is the line saying which frame it came from, and the exports
            // screen will still list the file because it reads the folder.
            failures.add('${photo.radical} : exporté sans être consigné '
                '($error)');
          }
          // Off the queue only once it has actually been written: stopped
          // halfway, what is still marked is what is still to do.
          await ref.read(exportMarksProvider.notifier).clear(photo);
          done++;
        case ExportFailed(:final reason):
          failures.add('${photo.radical} : $reason');
      }
    }

    if (!ref.mounted) return;
    state = BatchProgress(
      done: done,
      total: queue.length,
      failures: failures,
    );
  }

  /// The whole frame: every pixel of it, not the largest permitted ratio that
  /// fits inside it.
  ///
  /// A Q3's full-size preview is 9520 x 6336 — 1.5025, not 1.5 — so cutting the
  /// largest exact 3:2 out of it would quietly shave a strip off a photograph
  /// this queue promises to export whole. The rectangle is therefore the unit
  /// square, and the ratio is carried only for the file's name, where the
  /// nearest of the six is the honest label.
  @visibleForTesting
  static CropRect wholeFrame(PhotoEntity photo) {
    final aspect = _aspectOf(photo);
    var best = CropRatio.threeTwo;
    var bestOrientation = CropOrientation.landscape;
    var distance = double.infinity;

    for (final ratio in CropRatio.values) {
      for (final orientation in CropOrientation.values) {
        final gap = (ratio.aspectIn(orientation) - aspect).abs();
        if (gap < distance) {
          distance = gap;
          best = ratio;
          bestOrientation = orientation;
        }
      }
    }

    return CropRect(
      rect: const Rect.fromLTWH(0, 0, 1, 1),
      ratio: best,
      orientation: bestOrientation,
    );
  }

  static double _aspectOf(PhotoEntity photo) {
    final stream = photo.viewerPreview ?? photo.gridPreview;
    final width = (stream?.width ?? 3).toDouble();
    final height = (stream?.height ?? 2).toDouble();
    if (width <= 0 || height <= 0) return 3 / 2;
    return photo.isPortrait ? height / width : width / height;
  }
}

final batchExporterProvider =
    NotifierProvider<BatchExporter, BatchProgress>(BatchExporter.new);
