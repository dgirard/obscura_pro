import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// How a photograph leaves the card.
enum DeletionMode {
  /// The default. Delete marks; nothing is touched until Empty Trash.
  ///
  /// Right for culling, which is a long run of decisions: the card can be
  /// pulled at any point and nothing has happened to it.
  deferred,

  /// Each deletion copies the originals to the Mac, verifies them, and only
  /// then removes them from the card.
  ///
  /// Slower per frame and safer per frame: it frees the card as you go, and
  /// what leaves is recoverable until you empty the Mac-side trash.
  immediate,
}

/// What the user has chosen. Small, and every field has a defensible default.
@immutable
final class Settings {
  const Settings({
    this.exportFolder,
    this.deletionMode = DeletionMode.deferred,
    this.suppressSpotlight = false,
  });

  /// Null means the dated folder under `~/Pictures/Q3Culling/Exports/`.
  final String? exportFolder;

  final DeletionMode deletionMode;

  /// Whether to write `.metadata_never_index` on the card.
  ///
  /// Off by default and stated rather than assumed: the file is unreliable on
  /// current macOS, and creating it is itself a write to the card. Making that
  /// trade silently would be the wrong way to keep a promise about not writing.
  final bool suppressSpotlight;

  Settings copyWith({
    String? exportFolder,
    bool clearExportFolder = false,
    DeletionMode? deletionMode,
    bool? suppressSpotlight,
  }) =>
      Settings(
        exportFolder:
            clearExportFolder ? null : (exportFolder ?? this.exportFolder),
        deletionMode: deletionMode ?? this.deletionMode,
        suppressSpotlight: suppressSpotlight ?? this.suppressSpotlight,
      );

  Map<String, Object?> toJson() => {
        'exportFolder': exportFolder,
        'deletionMode': deletionMode.name,
        'suppressSpotlight': suppressSpotlight,
      };

  factory Settings.fromJson(Map<String, Object?> json) => Settings(
        exportFolder: json['exportFolder'] as String?,
        deletionMode: DeletionMode.values
                .where((m) => m.name == json['deletionMode'])
                .firstOrNull ??
            DeletionMode.deferred,
        suppressSpotlight: json['suppressSpotlight'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.exportFolder == exportFolder &&
      other.deletionMode == deletionMode &&
      other.suppressSpotlight == suppressSpotlight;

  @override
  int get hashCode => Object.hash(exportFolder, deletionMode, suppressSpotlight);
}

/// Preferences, on the Mac, in a file a human can read.
///
/// JSON beside the bookmarks rather than a row in the database: these are a
/// handful of values that someone recovering a broken install should be able to
/// open in a text editor, and they have nothing to do with any photograph.
class SettingsStore {
  SettingsStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  static const fileName = 'settings.json';

  Future<File> _file() async =>
      File(p.join((await _directory()).path, fileName));

  Future<Settings> load() async {
    final file = await _file();
    if (!await file.exists()) return const Settings();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return const Settings();
      return Settings.fromJson(decoded.cast<String, Object?>());
    } on Object {
      // A corrupt preferences file is worth no more than an absent one, and
      // refusing to launch over it would be absurd.
      return const Settings();
    }
  }

  /// Whether the preferences reached the disk.
  ///
  /// Returns rather than throws, because no preference is worth taking the app
  /// down over — but it does report, because a screen that shows a setting as
  /// active when the write failed is telling the user something untrue about
  /// what the app will do to their card.
  Future<bool> save(Settings settings) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(settings.toJson()),
        flush: true,
      );
      return true;
    } on Object {
      return false;
    }
  }
}

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

class SettingsNotifier extends AsyncNotifier<Settings> {
  @override
  Future<Settings> build() => ref.watch(settingsStoreProvider).load();

  /// Named `save` rather than `update`: AsyncNotifier already has an `update`
  /// with quite different semantics, and shadowing it would be a trap.
  ///
  /// The write is awaited before the state moves. Showing the new value first
  /// and writing afterwards makes the screen agree with the user rather than
  /// with the disk: a failed write left a setting looking active for the rest
  /// of the session and quietly reverting on the next launch.
  Future<bool> save(Settings next) async {
    final written = await ref.read(settingsStoreProvider).save(next);
    if (written) state = AsyncData(next);
    return written;
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
