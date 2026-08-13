import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/theme.dart';
import 'package:obscura_pro/features/settings/settings_screen.dart';
import 'package:obscura_pro/features/settings/settings_store.dart';
import 'package:obscura_pro/features/volume_select/card_selection.dart';
import 'package:obscura_pro/infra/card_access/bookmark_store.dart';
import 'package:obscura_pro/infra/card_access/models.dart';

import '../../infra/card_access/fakes.dart';

/// Choosing the working directory — the one control that could point this app
/// at the card it promises never to write to.
void main() {
  late RecordingBridge bridge;
  late Directory support;

  setUp(() async {
    bridge = RecordingBridge();
    support = await Directory.systemTemp.createTemp('obscura_settings_ui');
  });

  tearDown(() async {
    if (await support.exists()) await support.delete(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    required String? picks,
    List<MountedVolume> volumes = const [],
  }) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Not the real store: it reads a file, and real file I/O inside
          // `testWidgets` never completes on the test binding's clock.
          settingsProvider.overrideWith(_InMemorySettings.new),
          // Memory-backed for the same reason: the real store persists its
          // entries to a file, and that write never lands under the test
          // binding's clock. The bridge is still the real seam, so what the
          // panel mints is still observed.
          bookmarkStoreProvider.overrideWithValue(_MemoryBookmarks(bridge)),
          volumeChannelProvider
              .overrideWithValue(FakeVolumeChannel(volumes: volumes)),
          directoryPickerProvider.overrideWithValue(() async => picks),
        ],
        child: MaterialApp(
          theme: buildObscuraTheme(),
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  String folderText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('settings-export-folder'))).data!;

  testWidgets('refuses a folder on the card, and changes nothing',
      (tester) async {
    await pump(
      tester,
      picks: '/Volumes/Q3/Exports',
      volumes: [
        const MountedVolume(
          name: 'Q3',
          path: '/Volumes/Q3',
          isRemovable: true,
          isEjectable: true,
        ),
      ],
    );
    final before = folderText(tester);

    await tester.tap(find.byKey(const Key('settings-choose-folder')));
    await tester.pump();
    await tester.pump();

    // The guarantee the app is built on cannot be undone by a file chooser.
    expect(find.byKey(const Key('settings-failure')), findsOneWidget);
    expect(find.textContaining('sur une carte'), findsOneWidget);
    expect(folderText(tester), before);
    // And nothing was remembered about a folder that was refused.
    expect(bridge.calls.where((c) => c.startsWith('encode:')), isEmpty);
  });

  testWidgets('remembers a folder it accepts, in the same turn as the panel',
      (tester) async {
    await pump(tester, picks: support.path);

    await tester.tap(find.byKey(const Key('settings-choose-folder')));
    await tester.pump();
    await tester.pump();

    expect(folderText(tester), support.path);
    // The bookmark is what makes the folder readable next launch; minting it
    // later fails, because the panel's implicit grant is gone by then.
    expect(bridge.calls, contains('encode:${support.path}'));
    expect(find.byKey(const Key('settings-failure')), findsNothing);
  });

  testWidgets('a folder that cannot be remembered is refused, not stored',
      (tester) async {
    bridge.encodeThrows = StateError('no bookmark for you');
    await pump(tester, picks: support.path);
    final before = folderText(tester);

    await tester.tap(find.byKey(const Key('settings-choose-folder')));
    await tester.pump();
    await tester.pump();

    // Storing the path without the grant is what the app used to do; the folder
    // then read as chosen and was unreachable on the next launch.
    expect(find.textContaining('illisible au prochain lancement'), findsOneWidget);
    expect(folderText(tester), before);
  });
}

/// Settings that live in memory for the length of a test.
class _InMemorySettings extends SettingsNotifier {
  @override
  Future<Settings> build() async => const Settings();

  @override
  Future<bool> save(Settings next) async {
    state = AsyncData(next);
    return true;
  }
}

/// A bookmark store that keeps its entries in memory.
class _MemoryBookmarks extends BookmarkStore {
  _MemoryBookmarks(this._bridge)
      : super(bridge: _bridge, storageDirectory: () async => Directory.systemTemp);

  final RecordingBridge _bridge;
  final Map<String, String> entries = {};

  @override
  Future<void> save(String key, String path) async {
    entries[key] = await _bridge.encode(Directory(path));
  }

  @override
  Future<BookmarkResolution> resolve(String key) async {
    final encoded = entries[key];
    if (encoded == null) return const BookmarkAbsent();
    return BookmarkResolved((await _bridge.decode(encoded)).path);
  }
}
