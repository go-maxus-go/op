import 'package:flutter_test/flutter_test.dart';

import 'package:optimal_poker/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PokerTrainingApp());

    // Verify that our Preflop button exists.
    expect(find.text('Preflop'), findsOneWidget);

    // Tap on Preflop button and navigate.
    await tester.tap(find.text('Preflop'));
    await tester.pumpAndSettle(); // Wait for navigation animation.

    // Verify that we are on the Preflop screen and see 'Charts' button.
    expect(find.text('Charts'), findsOneWidget);
  });
}
