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

  testWidgets('Leaving the screen returns the selected range', (
    WidgetTester tester,
  ) async {
    Object? result;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const RangeSelectorScreen(initialRange: {}),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AA'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(result, hasLength(6));
  });

  testWidgets('Clear button deselects all hands', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const RangeSelectorScreen(initialRange: {})));

    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.text('AA'));
    await tester.pump();
    expect(find.text('Selected: 0.45%'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear Range'));
    await tester.pump();

    expect(find.text('Selected: 0.00%'), findsOneWidget);
  });

  testWidgets('Locked chart shows combos without changing the range', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const RangeSelectorScreen(initialRange: {})));

    await tester.tap(find.byTooltip('Lock Range'));
    await tester.pump();

    await tester.tap(find.text('AA'));
    await tester.pump();

    expect(find.text('Selected: 0.00%'), findsOneWidget);
    expect(find.text('Combinations for AA'), findsOneWidget);

    await tester.tap(find.byTooltip('Unlock Range'));
    await tester.pump();

    await tester.tap(find.text('AA'));
    await tester.pump();

    expect(find.text('Selected: 0.45%'), findsOneWidget);
  });
}
