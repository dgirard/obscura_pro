import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/features/settings/settings_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory support;
  late SettingsStore store;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('obscura_settings');
    store = SettingsStore(directory: () async => support);
  });

  tearDown(() async {
    if (await support.exists()) await support.delete(recursive: true);
  });

  test('a fresh install gets the defensible defaults', () async {
    final settings = await store.load();

    // Deferred marking, and nothing written to the card. Both are the choice
    // that costs the user least if they never open this screen.
    expect(settings.deletionMode, DeletionMode.deferred);
    expect(settings.suppressSpotlight, isFalse);
    expect(settings.exportFolder, isNull);
  });

  test('what is chosen survives a restart', () async {
    await store.save(const Settings(
      exportFolder: '/Users/someone/Exports',
      deletionMode: DeletionMode.immediate,
      suppressSpotlight: true,
    ));

    expect(await SettingsStore(directory: () async => support).load(),
        const Settings(
          exportFolder: '/Users/someone/Exports',
          deletionMode: DeletionMode.immediate,
          suppressSpotlight: true,
        ));
  });

  test('is written as something a person can read', () async {
    await store.save(const Settings(deletionMode: DeletionMode.immediate));

    final text = File(p.join(support.path, SettingsStore.fileName)).readAsStringSync();

    // Someone recovering a broken install should be able to open this in a text
    // editor, which is why it is JSON beside the bookmarks and not a database
    // row.
    expect(text, contains('"deletionMode": "immediate"'));
    expect(text, contains('\n'));
  });

  test('a corrupt file falls back to defaults rather than refusing to launch',
      () async {
    File(p.join(support.path, SettingsStore.fileName))
      ..createSync(recursive: true)
      ..writeAsStringSync('{ this is not json');

    expect((await store.load()).deletionMode, DeletionMode.deferred);
  });

  test('an unknown deletion mode degrades to the safe one', () async {
    File(p.join(support.path, SettingsStore.fileName))
      ..createSync(recursive: true)
      ..writeAsStringSync('{"deletionMode": "something_new"}');

    // A file written by a later version must never be read as permission to
    // start removing photographs immediately.
    expect((await store.load()).deletionMode, DeletionMode.deferred);
  });

  test('clearing the export folder returns to the default location', () async {
    const chosen = Settings(exportFolder: '/somewhere');

    expect(chosen.copyWith(clearExportFolder: true).exportFolder, isNull);
  });
}
