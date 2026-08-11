/// The verified file operations every card write goes through (R21, CARTE-3).
///
/// Two rules shape everything here.
///
/// **Nothing is believed without being observed.** An unlink is not done
/// because `delete()` returned; it is done because a subsequent `stat` says the
/// file is gone. A copy is not good because `copy()` returned; it is good
/// because the destination was read back and hashed to the same value as the
/// source. Every function below returns what was observed, never what was
/// attempted.
///
/// **The read-back is the guarantee, not the flush.** `F_FULLFSYNC` is not
/// reachable from Dart without FFI, and KTD-14 already records that card
/// readers commonly ignore it and that exFAT has no journal — so a durability
/// claim resting on a flush would be a claim this app cannot keep. What it can
/// keep is this: no original is ever unlinked until its copy has been read back
/// off the destination and hashed to the same bytes. That survives an app
/// crash, which is the failure that actually happens; it does not survive the
/// power being cut mid-write, and nothing at this layer could.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Prefix for any file this app writes to a card.
///
/// A DCF name is eight characters from `[A-Z0-9_]` followed by an extension, so
/// a name starting with `~` cannot collide with one the camera wrote and cannot
/// be mistaken for a photograph by the scan. Stranded debris is therefore
/// always identifiable as ours, which is what lets the card-safety pass clean
/// it up without guessing.
const String kCardTempPrefix = '~OBSCURA-';

/// What was observed after trying to remove a file.
sealed class UnlinkOutcome {
  const UnlinkOutcome();
}

/// The file was there and is now verifiably gone.
final class Unlinked extends UnlinkOutcome {
  const Unlinked(this.bytesFreed);
  final int bytesFreed;
}

/// There was nothing to remove.
///
/// Not an error: an interrupted run that already unlinked this file, then
/// crashed before recording it, lands here on the retry, and that is exactly
/// the case reconciliation exists to resolve.
final class AlreadyAbsent extends UnlinkOutcome {
  const AlreadyAbsent();
}

/// The volume went away mid-operation (CARTE-5).
///
/// Distinct from an ordinary failure because the response is different: the
/// whole run stops, and every entity it touched becomes uncertain rather than
/// failed, because nothing can be observed about a card that is not there.
final class VolumeGone extends UnlinkOutcome {
  const VolumeGone(this.path);
  final String path;
}

/// The delete was attempted and the file is still there.
final class UnlinkFailed extends UnlinkOutcome {
  const UnlinkFailed(this.reason);
  final String reason;
}

/// Removes [file] and proves it is gone.
///
/// The proof is a second `stat`. A delete that reports success while the entry
/// survives — a read-only volume mounted read-write by a stale handle, a
/// reader that swallows the error — must not be recorded as a deletion, because
/// the row that says "deleted" is the only thing standing between the user and
/// a file they believe they removed.
Future<UnlinkOutcome> verifiedUnlink(File file) async {
  final int size;
  try {
    final stat = await file.stat();
    if (stat.type == FileSystemEntityType.notFound) return const AlreadyAbsent();
    size = stat.size;
  } on FileSystemException catch (error) {
    return _volumeGoneOr(file.path, error, (r) => UnlinkFailed(r));
  }

  try {
    await file.delete();
  } on PathNotFoundException {
    return const AlreadyAbsent();
  } on FileSystemException catch (error) {
    return _volumeGoneOr(file.path, error, (r) => UnlinkFailed(r));
  }

  try {
    if (await file.exists()) {
      return UnlinkFailed('${file.path} still exists after delete');
    }
  } on FileSystemException catch (error) {
    return _volumeGoneOr(file.path, error, (r) => UnlinkFailed(r));
  }

  return Unlinked(size);
}

/// What was observed after trying to place a copy.
sealed class CopyOutcome {
  const CopyOutcome();
}

/// The copy exists at [path] and has been read back and hashed to [hash],
/// matching the source.
final class CopyVerified extends CopyOutcome {
  const CopyVerified({required this.path, required this.hash, required this.bytes});
  final String path;
  final String hash;
  final int bytes;
}

/// The copy was written but does not match the source, and has been removed.
///
/// A truncated copy is worse than no copy: it looks like a backup and is not
/// one. Leaving it would let a later reconciliation adopt it as the rescued
/// original.
final class CopyCorrupt extends CopyOutcome {
  const CopyCorrupt({required this.expected, required this.actual});
  final String expected;
  final String actual;
}

final class CopySourceMissing extends CopyOutcome {
  const CopySourceMissing(this.path);
  final String path;
}

final class CopyFailed extends CopyOutcome {
  const CopyFailed(this.reason);
  final String reason;
}

/// Copies [source] to [destination] and proves the bytes arrived.
///
/// Written through a temporary name and renamed into place, so a destination
/// path either does not exist or holds a complete file — never a half-written
/// one that a later run would mistake for a finished copy. The source is hashed
/// while it is read, and the destination is hashed by reading it back off the
/// disk it was just written to, which is what makes the comparison worth
/// anything.
Future<CopyOutcome> copyVerified({
  required File source,
  required File destination,
  String? tempName,
}) async {
  final String sourceHash;
  final int sourceBytes;
  try {
    if (!await source.exists()) return CopySourceMissing(source.path);
    sourceHash = await hashOf(source);
    sourceBytes = await source.length();
  } on FileSystemException catch (error) {
    return _volumeGoneOr(source.path, error, (r) => CopyFailed(r));
  }

  // On a card the temp name must be the reserved one, so that debris left by a
  // crash is identifiable as ours rather than looking like a camera file.
  final temp = tempName == null
      ? File('${destination.path}.part')
      : File(p.join(destination.parent.path, tempName));
  try {
    await destination.parent.create(recursive: true);
    if (await temp.exists()) await temp.delete();
    await source.copy(temp.path);

    // Best effort, and named as such. On the Mac side this is a real fsync; it
    // is not F_FULLFSYNC and makes no power-loss promise.
    final handle = await temp.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }

    final copiedHash = await hashOf(temp);
    if (copiedHash != sourceHash) {
      await temp.delete();
      return CopyCorrupt(expected: sourceHash, actual: copiedHash);
    }

    await temp.rename(destination.path);
    return CopyVerified(
      path: destination.path,
      hash: sourceHash,
      bytes: sourceBytes,
    );
  } on FileSystemException catch (error) {
    // Leave nothing half-written behind, whatever went wrong.
    try {
      if (await temp.exists()) await temp.delete();
    } on FileSystemException {
      // Nothing more can be done, and reporting the original failure matters
      // more than reporting the failure to clean up after it.
    }
    return _volumeGoneOr(source.path, error, (r) => CopyFailed(r));
  }
}

/// SHA-256 of a file's contents, hex, streamed.
///
/// Streamed because a Q3 DNG is around 84 MB and reading a batch of them into
/// memory to hash would cost more than the copy being verified.
Future<String> hashOf(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}

/// Whether [a] and [b] hold the same bytes.
Future<bool> sameContents(File a, File b) async {
  if (!await a.exists() || !await b.exists()) return false;
  if (await a.length() != await b.length()) return false;
  return await hashOf(a) == await hashOf(b);
}

/// A temp name on the card that cannot be confused with a camera file.
String cardTempNameFor(String finalName) => '$kCardTempPrefix$finalName';

/// Whether [name] is a temp file this app left behind.
bool isCardTempName(String name) => name.startsWith(kCardTempPrefix);

/// Writes [bytes] to [destination] through a temp file and a rename.
///
/// Used by restore, which is the only path that puts a file back on a card.
/// The temp name is the reserved one, so a crash between write and rename
/// leaves debris the card-safety pass can recognise and remove — rather than
/// something a photographer would find on their card and not dare touch.
Future<CopyOutcome> writeVerified({
  required File destination,
  required Uint8List bytes,
  required String expectedHash,
}) async {
  final temp = File(p.join(
    destination.parent.path,
    cardTempNameFor(p.basename(destination.path)),
  ));
  try {
    if (await temp.exists()) await temp.delete();
    final handle = await temp.open(mode: FileMode.writeOnly);
    try {
      await handle.writeFrom(bytes);
      await handle.flush();
    } finally {
      await handle.close();
    }

    final written = await hashOf(temp);
    if (written != expectedHash) {
      await temp.delete();
      return CopyCorrupt(expected: expectedHash, actual: written);
    }

    await temp.rename(destination.path);
    return CopyVerified(
      path: destination.path,
      hash: expectedHash,
      bytes: bytes.length,
    );
  } on FileSystemException catch (error) {
    try {
      if (await temp.exists()) await temp.delete();
    } on FileSystemException {
      // See copyVerified.
    }
    return _volumeGoneOr(destination.path, error, (r) => CopyFailed(r));
  }
}

/// Distinguishes "the card is not there any more" from an ordinary I/O failure.
///
/// The two need different answers: a vanished volume stops the whole run and
/// leaves entities uncertain, because nothing can be observed about a card that
/// is gone, while a single failed operation is just that.
T _volumeGoneOr<T>(
  String path,
  FileSystemException error,
  T Function(String reason) otherwise,
) {
  final code = error.osError?.errorCode;
  // ENOENT on a path whose volume root has gone, ENODEV, and EIO are what a
  // pulled card produces; the volume check is what tells them apart from a
  // missing file on a card that is still mounted.
  const vanished = {5, 6, 19, 65, 66};
  if (vanished.contains(code) || !_volumeStillMounted(path)) {
    return VolumeGone(path) as T;
  }
  return otherwise('${error.message}${code == null ? '' : ' (errno $code)'}');
}

/// Whether the volume [path] sits on is still mounted.
///
/// Checked by walking up to the volume root rather than by asking the system
/// for a list: the question is only ever about one path, and a directory
/// listing of `/Volumes` says nothing about whether *this* mount survived.
bool _volumeStillMounted(String path) {
  final root = volumeRootOf(path);
  if (root == null) return true;
  return Directory(root).existsSync();
}

/// `/Volumes/Untitled` for anything beneath it, or null for a path that is not
/// on a mounted volume.
String? volumeRootOf(String path) {
  final parts = p.split(p.normalize(path));
  if (parts.length < 3 || parts[1] != 'Volumes') return null;
  return p.joinAll(parts.take(3));
}
