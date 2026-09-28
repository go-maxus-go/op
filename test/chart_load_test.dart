import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/chart_screen.dart';
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
}
