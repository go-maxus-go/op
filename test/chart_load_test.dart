import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/chart_screen.dart';
import 'package:flutter/material.dart';
import 'package:optimal_poker/theme.dart';

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
  });
}
