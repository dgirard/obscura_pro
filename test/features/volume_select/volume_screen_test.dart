import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/theme.dart';
import 'package:obscura_pro/features/volume_select/card_selection.dart';
import 'package:obscura_pro/features/volume_select/volume_screen.dart';
import 'package:obscura_pro/infra/card_access/bookmark_store.dart';
import 'package:obscura_pro/infra/card_access/card_access_service.dart';

import '../../infra/card_access/fakes.dart';

void main() {
  late Directory storage;
  late RecordingBridge bridge;
  late FakeVolumeChannel channel;

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('obscura_screen');
    bridge = RecordingBridge();
    channel = FakeVolumeChannel();
  });

  tearDown(() async {
    if (await storage.exists()) await storage.delete(recursive: true);
  });

  Widget harness({String? picks}) {
    final bookmarks =
        BookmarkStore(bridge: bridge, storageDirectory: () async => storage);
    return ProviderScope(
      overrides: [
        cardAccessServiceProvider.overrideWithValue(
          CardAccessService(
            channel: channel,
            bookmarks: bookmarks,
            directoryPicker: () async => picks,
          ),
        ),
      ],
      child: MaterialApp(
        theme: buildObscuraTheme(),
        home: const Scaffold(body: VolumeScreen()),
      ),
    );
  }

  testWidgets('lists the cards that are plugged in', (tester) async {
    channel.volumes = [
      fakeVolume('LEICA Q3', freeBytes: 45000000000),
      fakeVolume('Macintosh HD',
          path: '/', removable: false, ejectable: false, internal: true),
    ];

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('volume-list')), findsOneWidget);
    expect(find.text('LEICA Q3'), findsOneWidget);
    // The startup disk is filtered out rather than offered for the user to avoid.
    expect(find.text('Macintosh HD'), findsNothing);
    expect(find.text('45 Go libres'), findsOneWidget);
  });

  testWidgets('tells the user when no card is plugged in', (tester) async {
    channel.volumes = [];

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('no-volumes')), findsOneWidget);
    expect(find.byKey(const Key('volume-list')), findsNothing);
  });

  // The wrong-folder path is proven in card_access_service_test rather than
  // here: driving it through the widget tree means real filesystem I/O inside
  // testWidgets' fake-async clock, which does not complete. The rendering of
  // that state is one Text widget; the decision behind it is what matters, and
  // it is tested where it is made.

  testWidgets('keeps the picker reachable even with cards listed', (tester) async {
    channel.volumes = [fakeVolume('LEICA Q3')];

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Seeing a volume is not the same as being allowed to read it: the sandbox
    // grant only exists once the user has picked it in the panel.
    expect(find.byKey(const Key('open-panel')), findsOneWidget);
  });
}
