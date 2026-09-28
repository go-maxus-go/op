import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/equity_screen.dart';

void main() {
  testWidgets('shows equities once the simulation runs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EquityScreen()));
    expect(find.text('Equity: --%'), findsNWidgets(2));

    await tester.pumpAndSettle();
    expect(find.text('Equity: --%'), findsNothing);
    expect(find.text('Simulations: 100000'), findsOneWidget);

    final equities = tester
        .widgetList<Text>(find.textContaining(RegExp(r'^Equity: \d')))
        .map(
          (text) => double.parse(text.data!.split(' ')[1].replaceAll('%', '')),
        )
        .toList();
    expect(equities, hasLength(2));
    for (final equity in equities) {
      expect(equity, closeTo(50, 1));
    }
  });
}
