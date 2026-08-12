import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/app/theme.dart';
import 'package:obscura_pro/features/grid/card_open_banner.dart';
import 'package:obscura_pro/infra/safety/parasite_guard.dart';

/// What the card open found, finally said out loud.
///
/// Every field of `CardOpenReport` was computed on every card open and read by
/// nothing. The loss list especially: it is the single case the app admits it
/// cannot repair, and it was being written to a value nobody looked at.
void main() {
  testWidgets('says nothing about a card that had nothing wrong with it',
      (tester) async {
    await _pump(tester, CardOpenReport.none);

    expect(find.byKey(const Key('card-open-report')), findsNothing);
  });

  testWidgets('names the files that are gone with no verified copy',
      (tester) async {
    await _pump(
      tester,
      const CardOpenReport(
        debrisRemoved: [],
        parasites: [],
        writable: true,
        reconciled: 1,
        losses: ['DCIM/100LEICA/L1000042.DNG'],
      ),
    );

    expect(find.byKey(const Key('card-open-losses')), findsOneWidget);
    expect(
      find.textContaining('L1000042.DNG'),
      findsOneWidget,
      reason: 'a count is not something a photographer can act on',
    );
  });

  testWidgets('warns that a read-only card cannot have its trash emptied',
      (tester) async {
    await _pump(
      tester,
      const CardOpenReport(
        debrisRemoved: [],
        parasites: [],
        writable: false,
        reconciled: 0,
        losses: [],
      ),
    );

    expect(find.byKey(const Key('card-open-read-only')), findsOneWidget);
  });

  testWidgets('reports what the system left, and that it was left alone',
      (tester) async {
    await _pump(
      tester,
      const CardOpenReport(
        debrisRemoved: [],
        parasites: [
          Parasite(
            path: '/Volumes/Q3/.DS_Store',
            relativePath: '.DS_Store',
            kind: ParasiteKind.foreign,
            bytes: 6148,
            isDirectory: false,
          ),
        ],
        writable: true,
        reconciled: 0,
        losses: [],
      ),
    );

    expect(find.byKey(const Key('card-open-parasites')), findsOneWidget);
    // Removing them is a write to the user's card, so the banner reports and
    // does not act.
    expect(find.textContaining('votre décision'), findsOneWidget);
  });

  testWidgets('puts the loss first, whatever else the report holds',
      (tester) async {
    await _pump(
      tester,
      const CardOpenReport(
        debrisRemoved: ['.obscura-tmp-1'],
        parasites: [],
        writable: false,
        reconciled: 2,
        losses: ['DCIM/100LEICA/L1000042.DNG'],
      ),
    );

    final texts = tester
        .widgetList<Text>(find.descendant(
          of: find.byKey(const Key('card-open-report')),
          matching: find.byType(Text),
        ))
        .toList();
    expect(texts.first.key, const Key('card-open-losses'));
  });

  testWidgets('stays put once dismissed, and returns for a different card',
      (tester) async {
    const first = CardOpenReport(
      debrisRemoved: [],
      parasites: [],
      writable: false,
      reconciled: 0,
      losses: [],
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _pump(tester, first, container: container);
    await tester.tap(find.byKey(const Key('card-open-dismiss')));
    await tester.pump();
    expect(find.byKey(const Key('card-open-report')), findsNothing);

    // The next card has its own findings, and being tired of the last card's
    // is not consent to be told nothing about this one.
    await _pump(
      tester,
      const CardOpenReport(
        debrisRemoved: [],
        parasites: [],
        writable: true,
        reconciled: 0,
        losses: ['DCIM/100LEICA/L1000007.DNG'],
      ),
      container: container,
    );

    expect(find.byKey(const Key('card-open-report')), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  CardOpenReport report, {
  ProviderContainer? container,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container ?? ProviderContainer(),
      child: MaterialApp(
        theme: buildObscuraTheme(),
        home: Scaffold(body: CardOpenBanner(report: report)),
      ),
    ),
  );
  await tester.pump();
}
