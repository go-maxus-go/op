import 'package:flutter_test/flutter_test.dart';

import 'package:optimal_poker/constants.dart';
import 'package:optimal_poker/main.dart';
import 'package:optimal_poker/user_settings.dart';

void _resetConfigurator() {
  UserSettings.instance.configurator
    ..mode = 'Practice'
    ..chart = PokerConstants.chartOPR
    ..position = 'All'
    ..opponentPosition = PokerConstants.positionUTG;
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    _resetConfigurator();
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PokerTrainingApp());

    // Verify that our Preflop button exists.
    expect(find.text('Preflop'), findsOneWidget);

    // Tap on Preflop button and navigate.
    await tester.tap(find.text('Preflop'));
    await tester.pumpAndSettle(); // Wait for navigation animation.

    // Verify we are on Charts Configuration Screen which has the Preflop title
    expect(find.text('Preflop'), findsOneWidget);
    
    // Verify default selections and options are present
    expect(find.text(PokerConstants.type6max), findsOneWidget);
    expect(find.text('Limit'), findsNothing);
    expect(find.text('Stacks'), findsNothing);
    expect(find.text('Raise'), findsNothing);
    expect(find.text(PokerConstants.positionUTG), findsOneWidget);
    expect(find.text(PokerConstants.chartOPR), findsOneWidget);
    expect(find.text(PokerConstants.chartVs3bet), findsOneWidget);
    expect(find.text('Call'), findsNothing);
    expect(find.text('3bet'), findsNothing);
    expect(find.text('4bet'), findsNothing);
    
    // Verify the Next button is present
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Hero'), findsOneWidget);
    expect(find.text('Villain'), findsNothing);
  });

  testWidgets('Vs OPR offers a hero and then a villain', (WidgetTester tester) async {
    _resetConfigurator();
    await tester.pumpWidget(const PokerTrainingApp());
    await tester.tap(find.text('Preflop'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(PokerConstants.chartVsOPR));
    await tester.tap(find.text(PokerConstants.chartVsOPR));
    await tester.pumpAndSettle();

    expect(find.text('Hero'), findsOneWidget);
    expect(find.text('Villain'), findsOneWidget);
    expect(find.text('Raiser'), findsNothing);

    await tester.ensureVisible(find.text('Chart'));
    await tester.tap(find.text('Chart'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(PokerConstants.positionBTN));
    await tester.tap(find.text(PokerConstants.positionBTN));
    await tester.pumpAndSettle();

    expect(find.text(PokerConstants.positionUTG), findsOneWidget);
    expect(find.text(PokerConstants.positionHJ), findsNWidgets(2));
    expect(find.text(PokerConstants.positionCO), findsNWidgets(2));
    expect(find.text(PokerConstants.positionBTN), findsOneWidget);
    expect(find.text(PokerConstants.positionSB), findsOneWidget);
    expect(find.text(PokerConstants.positionBB), findsOneWidget);
  });

  testWidgets('Vs 3bet villains act after the hero open', (
    WidgetTester tester,
  ) async {
    _resetConfigurator();
    await tester.pumpWidget(const PokerTrainingApp());
    await tester.tap(find.text('Preflop'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(PokerConstants.chartVs3bet));
    await tester.tap(find.text(PokerConstants.chartVs3bet));
    await tester.pumpAndSettle();

    expect(find.text('Villain'), findsOneWidget);

    await tester.ensureVisible(find.text('Chart'));
    await tester.tap(find.text('Chart'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(PokerConstants.positionHJ).first);
    await tester.tap(find.text(PokerConstants.positionHJ).first);
    await tester.pumpAndSettle();

    expect(find.text(PokerConstants.positionUTG), findsOneWidget);
    expect(find.text(PokerConstants.positionHJ), findsOneWidget);
    expect(find.text(PokerConstants.positionCO), findsNWidgets(2));
    expect(find.text(PokerConstants.positionBTN), findsNWidgets(2));
    expect(find.text(PokerConstants.positionSB), findsNWidgets(2));
    expect(find.text(PokerConstants.positionBB), findsOneWidget);
  });
}

