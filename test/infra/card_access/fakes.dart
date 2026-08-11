import 'dart:async';
import 'dart:io';

import 'package:obscura_pro/infra/card_access/bookmark_store.dart';
import 'package:obscura_pro/infra/card_access/models.dart';
import 'package:obscura_pro/infra/card_access/volume_channel.dart';

/// A bookmark bridge that records the start/stop pairing.
///
/// The counters exist because the defect these tests hunt is invisible on the
/// happy path: Apple's warning is about the *missing* stop, so the assertions
/// have to observe the release itself rather than whatever the body returned.
class RecordingBridge implements SecureBookmarkBridge {
  final List<String> calls = <String>[];
  int started = 0;
  int stopped = 0;

  /// Set to make [decode] fail the way a reformatted card makes it fail.
  Object? decodeThrows;

  @override
  Future<String> encode(Directory directory) async {
    calls.add('encode:${directory.path}');
    return 'bm:${directory.path}';
  }

  @override
  Future<Directory> decode(String token) async {
    calls.add('decode:$token');
    final failure = decodeThrows;
    if (failure != null) throw failure;
    return Directory(token.substring('bm:'.length));
  }

  @override
  Future<void> startAccess(Directory directory) async {
    calls.add('start:${directory.path}');
    started++;
  }

  @override
  Future<void> stopAccess(Directory directory) async {
    calls.add('stop:${directory.path}');
    stopped++;
  }
}

class FakeVolumeChannel implements VolumeChannel {
  FakeVolumeChannel({this.volumes = const <MountedVolume>[], this.ejectOutcome});

  List<MountedVolume> volumes;
  EjectOutcome? ejectOutcome;
  final List<String> ejected = <String>[];
  final events = StreamController<VolumeEvent>.broadcast();

  @override
  Future<List<MountedVolume>> listVolumes() async => volumes;

  @override
  Stream<VolumeEvent> watchVolumes() => events.stream;

  @override
  Future<EjectOutcome> eject(String path) async {
    ejected.add(path);
    return ejectOutcome ?? EjectSucceeded(path);
  }
}

MountedVolume fakeVolume(
  String name, {
  String? path,
  bool removable = true,
  bool ejectable = true,
  /// True by default: a card in a Mac's own SD slot is internal, and that is
  /// the ordinary case rather than the exotic one.
  bool internal = true,
  bool root = false,
  int? freeBytes = 32 * 1000 * 1000 * 1000,
}) =>
    MountedVolume(
      name: name,
      path: path ?? '/Volumes/$name',
      isRemovable: removable,
      isEjectable: ejectable,
      isInternal: internal,
      isRoot: root,
      freeBytes: freeBytes,
    );

/// Builds a DCF tree under a fresh temp directory.
Future<Directory> makeCardTree({
  List<String> imageFolders = const ['100LEICA'],
}) async {
  final root = await Directory.systemTemp.createTemp('obscura_card');
  await Directory(p(root, 'DCIM')).create(recursive: true);
  for (final folder in imageFolders) {
    await Directory(p(root, 'DCIM/$folder')).create(recursive: true);
  }
  return root;
}

String p(Directory root, String relative) => '${root.path}/$relative';
