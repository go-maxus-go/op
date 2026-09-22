import 'package:flutter_test/flutter_test.dart';

import 'package:optimal_poker/constants.dart';
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

    // Tap on Charts button and navigate to ChartsConfiguratorScreen.
    await tester.tap(find.text('Charts'));
    await tester.pumpAndSettle();

    // Verify we are on Charts Configuration Screen
    expect(find.text('Chart Configuration'), findsOneWidget);
    
    // Verify default selections and options are present
    expect(find.text(PokerConstants.type6max), findsOneWidget);
    expect(find.text(PokerConstants.limitNL50), findsOneWidget);
    expect(find.text(PokerConstants.limitNL100), findsOneWidget);
    expect(find.text(PokerConstants.limitNL200), findsOneWidget);
    expect(find.text(PokerConstants.stacks100), findsOneWidget);
    expect(find.text(PokerConstants.raise3bb), findsOneWidget);
    expect(find.text(PokerConstants.positionUTG), findsOneWidget);
    expect(find.text(PokerConstants.chartOPR), findsOneWidget);
    
    // Verify the Next button is present
    expect(find.text('Next'), findsOneWidget);
  });
}

