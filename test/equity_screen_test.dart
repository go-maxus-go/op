import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/equity_screen.dart';
import 'package:optimal_poker/range_chart.dart';
import 'package:optimal_poker/theme.dart';
import 'package:optimal_poker/user_settings.dart';

/// Lets the background isolate deliver messages until [done] holds.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final clock = Stopwatch()..start();
  while (!done()) {
    if (clock.elapsed > timeout) fail('Timed out waiting for the simulation');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

int? shownSimulations(WidgetTester tester) {
  final finder = find.textContaining('Simulations: ');
  if (finder.evaluate().isEmpty) return null;
  final text = tester.widget<Text>(finder).data!;
  return int.parse(text.substring('Simulations: '.length));
}

List<double> shownEquities(WidgetTester tester) => tester
    .widgetList<Text>(find.textContaining(RegExp(r'^Equity: \d')))
    .map((text) => double.parse(text.data!.split(' ')[1].replaceAll('%', '')))
    .toList();

void useTallSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 2400);
  addTearDown(tester.view.reset);
}

/// Deals one hole card so the two starting ranges are no longer the same.
///
/// The card is taken from the second keyboard row, leaving the first row's
/// first card free for tests that deal a board card next.
Future<void> dealFirstHoleCard(WidgetTester tester) async {
  await tester.tap(find.byType(Image).at(5));
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
  await tester.tap(find.byType(Image).at(22));
  await tester.pump();
  await tester.tap(find.text('Hands'));
  await tester.pump();
}

void main() {
  testWidgets('shows equities once the background simulation finishes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EquityScreen(maxSimulations: 20000)),
    );
    expect(find.text('Equity: --%'), findsNWidgets(2));

    await pumpUntil(tester, () => shownEquities(tester).length == 2);

    expect(find.text('Equity: --%'), findsNothing);
    expect(shownSimulations(tester), 0);
    expect(shownEquities(tester), [50, 50]);
  });

  testWidgets('shows partial results while the simulation is running', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(home: EquityScreen(maxSimulations: 1000000)),
    );
    await dealFirstHoleCard(tester);

    await pumpUntil(tester, () => (shownSimulations(tester) ?? 0) > 0);

    expect(shownSimulations(tester), lessThan(1000000));
    expect(shownEquities(tester), hasLength(2));
  });

  testWidgets('stays interactive while the simulation is running', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(home: EquityScreen(maxSimulations: 1000000)),
    );
    await dealFirstHoleCard(tester);
    await pumpUntil(tester, () => (shownSimulations(tester) ?? 0) > 0);

    await tester.tap(find.byType(Image).first);
    await tester.pump();

    expect(find.byTooltip('Clear Slot'), findsOneWidget);
    expect(shownSimulations(tester), lessThan(1000000));
  });

  testWidgets('changing the board restarts the simulation', (tester) async {
    useTallSurface(tester);

    await tester.pumpWidget(
      const MaterialApp(home: EquityScreen(maxSimulations: 1000000)),
    );
    await dealFirstHoleCard(tester);
    await pumpUntil(tester, () => (shownSimulations(tester) ?? 0) > 0);

    await tester.tap(find.byType(Image).first);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    // Board and hand slots come before the card keyboard. The first keyboard
    // card was already dealt to a hand.
    await tester.tap(find.byType(Image).at(10));
    await tester.pump();

    await pumpUntil(tester, () => (shownSimulations(tester) ?? 0) > 2000);

    // The keyboard stays open on the next board slot.
    await tester.tap(find.byType(Image).at(11));
    await tester.pump();

    expect(shownSimulations(tester), 0);
    expect(find.text('Equity: --%'), findsNWidgets(2));

    await pumpUntil(tester, () => (shownSimulations(tester) ?? 0) > 0);
    expect(shownEquities(tester), hasLength(2));
  });

  testWidgets('applied range is shown as a chart and can be reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: AppTheme.lightColorScheme,
          extensions: [AppTheme.lightChartColors],
        ),
        home: const EquityScreen(maxSimulations: 1000),
      ),
    );
    expect(find.byType(RangeChartImage), findsNothing);

    await tester.tap(find.text('Range').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('AA'));
    await tester.pump();
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(RangeChartImage), findsOneWidget);
    expect(find.text('0.5%'), findsOneWidget);

    await tester.tap(find.byType(RangeChartImage));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Select Range'), findsOneWidget);
    expect(find.text('Selected: 0.45%'), findsOneWidget);

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RangeChartImage), findsOneWidget);

    await tester.tap(find.byTooltip('Reset Hand'));
    await tester.pump();

    expect(find.byType(RangeChartImage), findsNothing);
    expect(find.byTooltip('Reset Hand'), findsNothing);
  });

  testWidgets('leaving the screen stops the simulation', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(home: EquityScreen(maxSimulations: 1000000)),
    );
    await dealFirstHoleCard(tester);
    await pumpUntil(tester, () => (shownSimulations(tester) ?? 0) > 0);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('settings choose how many simulations to run', (tester) async {
    useTallSurface(tester);
    UserSettings.instance.equity.simulations =
        EquitySettings.defaultSimulations;
    addTearDown(
      () => UserSettings.instance.equity.simulations =
          EquitySettings.defaultSimulations,
    );

    await tester.pumpWidget(const MaterialApp(home: EquityScreen()));
    await dealFirstHoleCard(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Simulation number'), findsOneWidget);
    expect(find.text('1k'), findsOneWidget);
    expect(find.text('10k'), findsOneWidget);
    expect(find.text('100k'), findsOneWidget);
    expect(
      tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue,
      10000,
    );

    await tester.tap(find.text('1k'));
    await tester.pump();

    await pumpUntil(tester, () => shownSimulations(tester) == 1000);
    expect(shownEquities(tester), hasLength(2));
    expect(UserSettings.instance.equity.simulations, 1000);
  });

  testWidgets('hide button closes the card keyboard', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(home: EquityScreen(maxSimulations: 1000)),
    );

    await tester.tap(find.byType(Image).first);
    await tester.pump();
    expect(find.byTooltip('Hide Keyboard'), findsOneWidget);
    expect(find.byTooltip('Clear Slot'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide Keyboard'));
    await tester.pump();

    expect(find.byTooltip('Hide Keyboard'), findsNothing);
    expect(find.byTooltip('Clear Slot'), findsNothing);
  });

  testWidgets('back hides the card keyboard before leaving', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const EquityScreen(maxSimulations: 1000),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byType(Image).first);
    await tester.pump();
    expect(find.byTooltip('Clear Slot'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byTooltip('Clear Slot'), findsNothing);
    expect(find.text('Equity Calculator'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Equity Calculator'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
