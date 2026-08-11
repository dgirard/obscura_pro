import 'dart:io';

import 'package:path/path.dart' as p;

import '../../infra/preview/preview_extractor.dart';
import 'photo_entity.dart';
import 'stable_key.dart';

/// Walks a card into photographs.
///
/// Strictly read-only. The scan opens files, reads a bounded prefix of each and
/// closes them; it creates nothing, renames nothing and never descends outside
/// `DCIM/`. The camera's own bookkeeping — `PRIVATE/`, with its index and
/// fastload files — is not ours to read or repair.
class DcfScanner {
  const DcfScanner({this.concurrency = 8});

  /// How many files are read at once.
  ///
  /// Header reads are I/O-bound, not CPU-bound: measured at roughly 2 ms per
  /// file, almost all of it waiting on the card. Bounded async concurrency
  /// therefore buys the parallelism, and isolates are reserved for JPEG
  /// decoding, where the work is genuinely on the CPU.
  final int concurrency;

  /// DCF folder names: three digits then five free characters, giving
  /// `100LEICA` on a Leica. Matching the standard rather than the spelling
  /// keeps a card written by another body readable.
  static final _dcfFolder = RegExp(r'^\d{3}[A-Z0-9_]{5}$');

  /// DCF file radicals: four free characters then four digits.
  static final _dcfRadical = RegExp(r'^[A-Z0-9_]{4}\d{4}$');

  static const _rawExtensions = {'.DNG'};
  static const _jpegExtensions = {'.JPG', '.JPEG'};

  Future<CardCatalog> scan(String cardRoot) async {
    final watch = Stopwatch()..start();
    final dcim = Directory(p.join(cardRoot, 'DCIM'));
    if (!await dcim.exists()) {
      return CardCatalog(
        photos: const [],
        unsupportedFiles: const [],
        scanDuration: (watch..stop()).elapsed,
      );
    }

    final grouped = <String, _Group>{};
    final unsupported = <String>[];

    await for (final folder in dcim.list(followLinks: false)) {
      if (folder is! Directory) continue;
      final folderName = p.basename(folder.path);
      if (!_dcfFolder.hasMatch(folderName)) continue;

      await for (final entry in folder.list(followLinks: false)) {
        if (entry is! File) continue;
        final name = p.basename(entry.path);
        // Dot-files are macOS debris, not camera output. They are reported by
        // the card-safety pass, not catalogued as photographs.
        if (name.startsWith('.')) continue;

        final extension = p.extension(name).toUpperCase();
        final radical = p.basenameWithoutExtension(name).toUpperCase();

        final kind = _rawExtensions.contains(extension)
            ? PhotoFileKind.raw
            : _jpegExtensions.contains(extension)
                ? PhotoFileKind.jpeg
                : null;

        if (kind == null || !_dcfRadical.hasMatch(radical)) {
          unsupported.add('$folderName/$name');
          continue;
        }

        final stat = await entry.stat();
        (grouped['$folderName/$radical'] ??= _Group(folderName, radical))
            .files
            .add(PhotoFile(
              name: name,
              path: entry.path,
              kind: kind,
              sizeBytes: stat.size,
              modified: stat.modified,
            ));
      }
    }

    final photos = await _resolveHeaders(grouped.values.toList());

    // Capture order is what a photographer expects; the radical breaks ties and
    // carries entities whose EXIF was unreadable.
    photos.sort((a, b) {
      final at = a.captureTime;
      final bt = b.captureTime;
      if (at != null && bt != null && at != bt) return at.compareTo(bt);
      if (at == null && bt != null) return 1;
      if (at != null && bt == null) return -1;
      return a.dcfPath.compareTo(b.dcfPath);
    });

    unsupported.sort();
    watch.stop();
    return CardCatalog(
      photos: photos,
      unsupportedFiles: unsupported,
      scanDuration: watch.elapsed,
    );
  }

  /// Reads one bounded header per photograph, [concurrency] at a time.
  Future<List<PhotoEntity>> _resolveHeaders(List<_Group> groups) async {
    final photos = <PhotoEntity>[];
    for (var i = 0; i < groups.length; i += concurrency) {
      final slice = groups.skip(i).take(concurrency);
      photos.addAll(await Future.wait(slice.map(_toEntity)));
    }
    return photos;
  }

  Future<PhotoEntity> _toEntity(_Group group) async {
    // The RAW carries the fuller EXIF, so it is preferred as the identity
    // source; a JPG-only entity falls back to its own.
    final ordered = [...group.files]..sort(
        (a, b) => a.kind == PhotoFileKind.raw ? -1 : 1,
      );

    PhotoHeader? header;
    for (final file in ordered) {
      header = await _readHeader(file);
      if (header?.dateTimeOriginal != null) break;
    }

    final captureTime = header?.dateTimeOriginal;
    final key = captureTime != null
        ? StableKey.fromExif(
            dcfRadical: '${group.folder}/${group.radical}',
            captureTime: captureTime,
            bodySerial: header?.bodySerial,
          )
        : StableKey.fromFileStat(
            dcfRadical: '${group.folder}/${group.radical}',
            sizeBytes: ordered.first.sizeBytes,
            modified: ordered.first.modified,
          );

    return PhotoEntity(
      radical: group.radical,
      folder: group.folder,
      key: key,
      files: List.unmodifiable(group.files),
      captureTime: captureTime,
      bodySerial: header?.bodySerial,
      gridPreview: header?.gridPreview,
      viewerPreview: header?.viewerPreview,
      orientation: header?.orientation ?? ExifOrientation.normal,
    );
  }

  /// Returns null when the file cannot be read at all.
  ///
  /// A photograph whose header is corrupt still belongs in the catalogue: it
  /// gets an error tile and remains deletable, which is the action a user is
  /// most likely to want from a file the camera mangled.
  Future<PhotoHeader?> _readHeader(PhotoFile file) async {
    RandomAccessFile? handle;
    try {
      handle = await File(file.path).open();
      final prefix = await handle.read(kHeaderPrefixBytes);
      final result = scanPhotoHeader(prefix, fileLength: file.sizeBytes);
      return switch (result) {
        PreviewScanSuccess(:final header) => header,
        // The bounded read fell short of something the parser needed. It names
        // the length to retry with, so honour that rather than giving up.
        PreviewScanNeedsMoreBytes(:final requiredBytes) =>
          await _retry(handle, file, requiredBytes),
        PreviewScanFailure() => null,
      };
    } on FileSystemException {
      return null;
    } finally {
      await handle?.close();
    }
  }

  Future<PhotoHeader?> _retry(
    RandomAccessFile handle,
    PhotoFile file,
    int requiredBytes,
  ) async {
    if (requiredBytes > file.sizeBytes) return null;
    await handle.setPosition(0);
    final prefix = await handle.read(requiredBytes);
    final result = scanPhotoHeader(prefix, fileLength: file.sizeBytes);
    return result is PreviewScanSuccess ? result.header : null;
  }
}

class _Group {
  _Group(this.folder, this.radical);

  final String folder;
  final String radical;
  final List<PhotoFile> files = [];
}
