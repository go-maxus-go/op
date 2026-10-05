import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/range_chart.dart';
import 'package:optimal_poker/range_selector_screen.dart';
import 'package:optimal_poker/theme.dart';
import 'package:optimal_poker/user_settings.dart';

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

String? _handsText(WidgetTester tester) =>
    tester.widget<TextField>(_fieldWithLabel('Range hands')).controller?.text;

Future<void> _tapChartHand(WidgetTester tester, String hand) async {
  await tester.tap(
    find.descendant(of: find.byType(GridView), matching: find.text(hand)),
  );
  await tester.pump();
}

void _useTallSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 2400);
  addTearDown(tester.view.reset);
}

void _removeSavedRanges() {
  final ranges = UserSettings.instance.ranges;
  for (final range in ranges.saved) {
    ranges.remove(range.name);
  }
}

Future<void> _clearAndSelect(WidgetTester tester, String hand) async {
  await tester.tap(find.byTooltip('Clear Range'));
  await tester.pump();
  await _tapChartHand(tester, hand);
}

Future<void> _saveAs(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('Save Range'));
  await tester.pumpAndSettle();
  await tester.enterText(_fieldWithLabel('Range name'), name);
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

void main() {
  _expectCellSplit({'AsKs', 'AhKh'}, 'AKs', 0.5);
  _expectCellSplit({'AsKs'}, 'AKs', 0.25);

  tearDown(_removeSavedRanges);

  testWidgets('Typing a range selects matching hands on the chart', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const RangeSelectorScreen(initialRange: {})));

    expect(find.text('Selected: 0.00%'), findsOneWidget);
    expect(find.byTooltip('Range'), findsNothing);

    await tester.enterText(_fieldWithLabel('Range hands'), 'AKs');
    await tester.pump();

    expect(find.text('Selected: 0.30%'), findsOneWidget);

    await tester.enterText(_fieldWithLabel('Range hands'), 'AKx');
    await tester.pump();

    expect(find.text('Invalid range'), findsOneWidget);
    expect(find.text('Selected: 0.30%'), findsOneWidget);
  });

  testWidgets('Selecting a hand fills the range hands field', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const RangeSelectorScreen(initialRange: {})));

    await _tapChartHand(tester, 'AA');

    expect(find.text('Selected: 0.45%'), findsOneWidget);
    expect(_handsText(tester), 'AA');

    await _tapChartHand(tester, 'KK');
    expect(_handsText(tester), 'KK+');
  });

  testWidgets('Saved ranges are listed by name and load on tap', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const RangeSelectorScreen(initialRange: {})));
    expect(find.text('Saved ranges'), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.save))
          .onPressed,
      isNull,
    );

    await _tapChartHand(tester, 'AA');
    await _saveAs(tester, 'premium');
    await _clearAndSelect(tester, 'AKs');
    await _saveAs(tester, 'Broadway');

    expect(find.text('Saved ranges'), findsOneWidget);
    expect(UserSettings.instance.ranges.saved.map((r) => r.name), [
      'Broadway',
      'premium',
    ]);
    final broadwayY = tester.getTopLeft(find.text('Broadway')).dy;
    final premiumY = tester.getTopLeft(find.text('premium')).dy;
    expect(broadwayY, lessThan(premiumY));
    expect(find.text('0.5%'), findsOneWidget);
    expect(find.text('0.3%'), findsOneWidget);

    await tester.tap(find.text('premium'));
    await tester.pump();

    expect(find.text('Selected: 0.45%'), findsOneWidget);
    expect(_handsText(tester), 'AA');
  });

  testWidgets('Saving under a taken name offers to rewrite it', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    UserSettings.instance.ranges.save('mine', 'AA');
    await tester.pumpWidget(_wrap(const RangeSelectorScreen(initialRange: {})));

    await _tapChartHand(tester, 'KK');
    await tester.tap(find.byTooltip('Save Range'));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldWithLabel('Range name'), 'mine');
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    final rewrite = find.widgetWithText(FilledButton, 'Rewrite');
    final context = tester.element(rewrite);
    expect(
      tester.widget<FilledButton>(rewrite).style?.backgroundColor?.resolve({}),
      Theme.of(context).colorScheme.error,
    );

    await tester.tap(rewrite);
    await tester.pumpAndSettle();

    expect(UserSettings.instance.ranges.saved.single.hands, 'KK');
  });

  testWidgets('Long press renames or deletes a saved range', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    UserSettings.instance.ranges.save('first', 'AA');
    UserSettings.instance.ranges.save('second', 'KK');
    await tester.pumpWidget(_wrap(const RangeSelectorScreen(initialRange: {})));

    await tester.longPress(find.text('first'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Range'), findsOneWidget);

    await tester.enterText(_fieldWithLabel('Range name'), 'second');
    await tester.pump();
    expect(find.text('A range with this name already exists'), findsOneWidget);

    await tester.enterText(_fieldWithLabel('Range name'), 'aces');
    await tester.pump();
    expect(find.text('Cancel'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('first'), findsNothing);
    expect(find.text('aces'), findsOneWidget);
    expect(UserSettings.instance.ranges.saved.first.hands, 'AA');

    await tester.longPress(find.text('second'));
    await tester.pumpAndSettle();
    final dialogLeft = tester.getTopLeft(find.byType(AlertDialog)).dx;
    final dialogRight = tester.getTopRight(find.byType(AlertDialog)).dx;
    final deleteX = tester.getCenter(find.text('Delete')).dx;
    final saveX = tester
        .getCenter(find.widgetWithText(FilledButton, 'Save'))
        .dx;
    expect(deleteX - dialogLeft, lessThan(dialogRight - deleteX));
    expect(saveX, greaterThan(deleteX));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('second'), findsNothing);
    expect(UserSettings.instance.ranges.saved.map((r) => r.name), ['aces']);
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

void _expectCellSplit(Set<String> combos, String hand, double share) {
  testWidgets('$hand with ${combos.length} combos is light for $share', (
    tester,
  ) async {
    late LinearGradient gradient;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            gradient = RangeChart.cellGradient(
              context: context,
              row: 0,
              col: 1,
              selectedCombos: combos,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    final light = AppTheme.lightChartColors.suitedColor;
    final dark = light.withValues(alpha: 0.5);
    expect(gradient.colors, [light, light, dark, dark]);
    expect(gradient.stops, [0, share, share, 1]);
  });
}
