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

Finder _fieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

void main() {
  testWidgets('Typing a range selects matching hands on the chart', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const RangeSelectorScreen(initialRange: {})));

    expect(find.text('Selected: 0.00%'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byTooltip('Range'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(_fieldWithLabel('Range name')).controller?.text,
      '0.00%',
    );

    await tester.enterText(_fieldWithLabel('Range hands'), 'AKs');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Selected: 0.30%'), findsOneWidget);
  });

  testWidgets('Selecting a hand fills the range hands field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const RangeSelectorScreen(initialRange: {})));

    await tester.tap(find.text('AA'));
    await tester.pump();

    expect(find.text('Selected: 0.45%'), findsOneWidget);

    await tester.tap(find.byTooltip('Range'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(_fieldWithLabel('Range name')).controller?.text,
      '0.45%',
    );
    expect(
      tester.widget<TextField>(_fieldWithLabel('Range hands')).controller?.text,
      'AA',
    );
  });
}
