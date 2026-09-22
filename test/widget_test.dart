import 'package:flutter_test/flutter_test.dart';

import 'package:optimal_poker/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PokerTrainingApp());

    // Verify that our Preflop button exists.
    expect(find.text('Preflop'), findsOneWidget);
  });
}
