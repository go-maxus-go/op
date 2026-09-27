import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/range_selector_screen.dart';
import 'package:optimal_poker/theme.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: AppTheme.lightColorScheme,
      useMaterial3: true,
      extensions: [AppTheme.lightChartColors],
    ),
    home: child,
  );
}

void main() {
  testWidgets('Typing a range selects matching hands on the chart', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const RangeSelectorScreen(initialRange: {})),
    );

    expect(find.text('Selected: 0.00%'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'AKs');
    await tester.pump();

    expect(find.text('Selected: 0.30%'), findsOneWidget);
  });

  testWidgets('Selecting a hand updates the range text field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const RangeSelectorScreen(initialRange: {})),
    );

    await tester.tap(find.text('AA'));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'AA');
    expect(find.text('Selected: 0.45%'), findsOneWidget);
  });
}
