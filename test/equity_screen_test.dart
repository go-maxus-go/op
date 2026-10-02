import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/equity_screen.dart';
import 'package:optimal_poker/range_chart.dart';
import 'package:optimal_poker/theme.dart';

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

void main() {
  testWidgets('shows equities once the background simulation finishes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EquityScreen(maxSimulations: 20000)),
    );
    expect(find.text('Equity: --%'), findsNWidgets(2));

    await pumpUntil(tester, () => shownSimulations(tester) == 20000);

    expect(find.text('Equity: --%'), findsNothing);
    final equities = shownEquities(tester);
    expect(equities, hasLength(2));
    for (final equity in equities) {
      expect(equity, closeTo(50, 2));
    }
  });

  testWidgets('shows partial results while the simulation is running', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EquityScreen(maxSimulations: 1000000)),
    );

    await pumpUntil(tester, () => (shownSimulations(tester) ?? 0) > 0);

    expect(shownSimulations(tester), lessThan(1000000));
    expect(shownEquities(tester), hasLength(2));
  });

  testWidgets('stays interactive while the simulation is running', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EquityScreen(maxSimulations: 1000000)),
    );
    await pumpUntil(tester, () => (shownSimulations(tester) ?? 0) > 0);

    await tester.tap(find.byType(Image).first);
    await tester.pump();

    expect(find.byTooltip('Clear Slot'), findsOneWidget);
    expect(shownSimulations(tester), lessThan(1000000));
  });

  testWidgets('clearing the deal restarts the simulation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: EquityScreen(maxSimulations: 1000000)),
    );
    await pumpUntil(tester, () => (shownSimulations(tester) ?? 0) > 2000);

    await tester.tap(find.byTooltip('Clear All'));
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
    await tester.tap(find.text('Apply'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(RangeChartImage), findsOneWidget);
    expect(find.text('0.45%'), findsOneWidget);

    await tester.tap(find.byTooltip('Reset Hand'));
    await tester.pump();

    expect(find.byType(RangeChartImage), findsNothing);
    expect(find.byTooltip('Reset Hand'), findsNothing);
  });

  testWidgets('leaving the screen stops the simulation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: EquityScreen(maxSimulations: 1000000)),
    );
    await pumpUntil(tester, () => (shownSimulations(tester) ?? 0) > 0);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
