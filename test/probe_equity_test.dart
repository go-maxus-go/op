import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/equity_screen.dart';
import 'package:optimal_poker/theme.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
}

void dump(WidgetTester tester, String label) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .where((d) => d != null && (d.contains('Equity') || d.contains('Sim')))
      .toList();
  // ignore: avoid_print
  print('$label: $texts');
}

Future<void> pick(WidgetTester tester, int slot, int keyboardIndex) async {
  await tester.tap(find.byType(Image).at(slot));
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
  await tester.tap(find.byType(Image).at(keyboardIndex));
  await tester.pump();
  await tester.tap(find.text('Hands'));
  await tester.pump();
}

void main() {
  setUp(() {});

  testWidgets('probe', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: AppTheme.lightColorScheme,
          extensions: [AppTheme.lightChartColors],
        ),
        home: const EquityScreen(),
      ),
    );
    await settle(tester);
    dump(tester, 'initial');

    await pick(tester, 5, 22);
    await settle(tester);
    dump(tester, 'one card vs empty');

    await tester.tap(find.text('Range').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('AA'));
    await tester.pump();
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    dump(tester, 'card vs AA');
  });
}
