import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/chart_screen.dart';
import 'package:optimal_poker/practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:optimal_poker/theme.dart';

/// Returns the weight shown next to [action] in the action popup.
String actionWeight(WidgetTester tester, String action) {
  final row = find.ancestor(
    of: find.text('$action: '),
    matching: find.byType(Row),
  );
  final texts = tester.widgetList<Text>(
    find.descendant(of: row.first, matching: find.byType(Text)),
  );
  return texts.last.data!;
}

void main() {
  testWidgets('Test loading specific chart', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        extensions: [AppTheme.lightChartColors],
      ),
      home: const ChartScreen(
        type: '6max',
        stacks: '100',
        limit: 'NL100',
        raise: '3bb',
        position: 'UTG',
        chart: 'OPR',
      ),
    ));

    await tester.pumpAndSettle();
    
    // Check if error is shown
    expect(find.textContaining('not found'), findsNothing);
    expect(find.text('AA'), findsOneWidget);

    await tester.tap(find.text('77'));
    await tester.pumpAndSettle();

    expect(find.text('Hand: 77'), findsOneWidget);
    expect(actionWeight(tester, 'Raise 3bb'), '50%');
    expect(actionWeight(tester, 'Fold'), '50%');
    // 6 combos of 77, two card images each.
    expect(find.byType(Image), findsNWidgets(12));
  });

  testWidgets('BTN vs UTG loads the hero file and the villain range', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        extensions: [AppTheme.lightChartColors],
      ),
      home: const ChartScreen(
        type: '6max',
        stacks: '100',
        limit: 'NL100',
        raise: '3bb',
        position: 'BTN',
        chart: 'vs OPR',
        villain: 'UTG',
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.textContaining('not found'), findsNothing);
    expect(find.text('BTN vs UTG'), findsOneWidget);

    await tester.tap(find.text('AA'));
    await tester.pumpAndSettle();

    expect(find.text('Hand: AA'), findsOneWidget);
    expect(actionWeight(tester, 'Raise 9bb'), '100%');
  });

  testWidgets('BTN vs BB 3bet chart can be practiced', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PracticeScreen(
        type: '6max',
        stacks: '100',
        limit: 'NL100',
        raise: '3bb',
        position: 'BTN',
        chart: 'vs 3bet',
        villain: 'BB',
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Chart not found.'), findsNothing);
    expect(find.text('Practice: BTN vs BB'), findsOneWidget);
    expect(find.text('Fold'), findsOneWidget);
    expect(find.text('Call 11bb'), findsOneWidget);
    expect(find.text('Raise 28bb'), findsOneWidget);
    // The bet chip draws the amount twice, once for the outline.
    expect(find.text('11'), findsNWidgets(2));
  });
}
