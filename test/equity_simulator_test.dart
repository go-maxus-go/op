// import 'dart:math';

// import 'package:flutter_test/flutter_test.dart';
// import 'package:optimal_poker/card.dart';
// import 'package:optimal_poker/equity_simulator.dart';
// import 'package:optimal_poker/hand_evaluator.dart';

// /// Parses concatenated cards, e.g. 'AhKd2c'.
// List<Card> cards(String s) => [
//   for (var i = 0; i < s.length; i += 2) Card(s[i], s[i + 1]),
// ];

// EquitySimulator simulator(
//   List<String> hands, {
//   String board = '',
//   int maxSimulations = 1000,
//   int seed = 1,
// }) => EquitySimulator(
//   hands: [for (final h in hands) cards(h)],
//   board: cards(board),
//   maxSimulations: maxSimulations,
//   random: Random(seed),
// );

// List<double> simulate(
//   List<String> hands, {
//   String board = '',
//   int simulations = 100000,
// }) {
//   final sim = simulator(hands, board: board, maxSimulations: simulations);
//   sim.run(simulations);
//   return sim.equities;
// }

// /// Exact equities computed by enumerating every way to deal the unknown
// /// cards, independently of [EquitySimulator].
// List<double> exactEquities(List<String> hands, {String board = ''}) {
//   final known = [for (final h in hands) ...cards(h), ...cards(board)];
//   final deck = [
//     for (final s in Card.suits)
//       for (final r in Card.ranks)
//         if (!known.contains(Card(r, s))) Card(r, s),
//   ];
//   final shares = List.filled(hands.length, 0.0);
//   var deals = 0;

//   void deal(List<List<Card>> dealtHands, List<Card> dealtBoard) {
//     final used = {...dealtBoard, for (final h in dealtHands) ...h};
//     final handIndex = dealtHands.indexWhere((h) => h.length < 2);
//     if (handIndex == -1 && dealtBoard.length == 5) {
//       final winners = HandEvaluator.winners(dealtHands, dealtBoard);
//       for (final w in winners) {
//         shares[w] += 1 / winners.length;
//       }
//       deals++;
//       return;
//     }
//     for (final card in deck) {
//       if (used.contains(card)) continue;
//       if (handIndex != -1) {
//         final next = [...dealtHands];
//         next[handIndex] = [...next[handIndex], card];
//         deal(next, dealtBoard);
//       } else {
//         deal(dealtHands, [...dealtBoard, card]);
//       }
//     }
//   }

//   deal([for (final h in hands) cards(h)], cards(board));
//   return [for (final s in shares) s / deals];
// }

// void main() {
//   group('validation', () {
//     test('requires at least two hands', () {
//       expect(() => simulator([]), throwsArgumentError);
//       expect(() => simulator(['AhAd']), throwsArgumentError);
//     });

//     test('rejects hands with more than two cards', () {
//       expect(() => simulator(['AhAdAc', 'KhKd']), throwsArgumentError);
//     });

//     test('rejects a board with more than five cards', () {
//       expect(
//         () => simulator(['AhAd', 'KhKd'], board: '2c3c4c5c6c7c'),
//         throwsArgumentError,
//       );
//     });

//     test('rejects duplicate cards', () {
//       expect(() => simulator(['AhAd', 'AhKd']), throwsArgumentError);
//       expect(() => simulator(['AhAh', 'KhKd']), throwsArgumentError);
//       expect(
//         () => simulator(['AhAd', 'KhKd'], board: '2c3cAd'),
//         throwsArgumentError,
//       );
//       expect(
//         () => simulator(['AhAd', 'KhKd'], board: '2c3c2c'),
//         throwsArgumentError,
//       );
//     });

//     test('rejects more hands than one deck can deal', () {
//       expect(() => simulator(List.filled(23, '')), returnsNormally);
//       expect(() => simulator(List.filled(24, '')), throwsArgumentError);
//     });

//     test('rejects a non-positive maxSimulations', () {
//       expect(
//         () => simulator(['AhAd', 'KhKd'], maxSimulations: 0),
//         throwsArgumentError,
//       );
//     });
//   });

//   group('running', () {
//     test('equities are unavailable before any simulation', () {
//       expect(() => simulator(['AhAd', 'KhKd']).equities, throwsStateError);
//     });

//     test('run stops at maxSimulations', () {
//       final sim = simulator(['AhAd', 'KhKd'], maxSimulations: 250);
//       expect(sim.isComplete, isFalse);
//       expect(sim.run(100), 100);
//       expect(sim.simulations, 100);
//       expect(sim.run(100), 100);
//       expect(sim.run(100), 50);
//       expect(sim.simulations, 250);
//       expect(sim.isComplete, isTrue);
//       expect(sim.run(100), 0);
//       expect(sim.simulations, 250);
//     });

//     test('run with a non-positive count does nothing', () {
//       final sim = simulator(['AhAd', 'KhKd']);
//       expect(sim.run(0), 0);
//       expect(sim.run(-5), 0);
//       expect(sim.simulations, 0);
//     });

//     test('equities always sum to one', () {
//       final sim = simulator(['AhAd', 'Kh', '', '7c2d'], maxSimulations: 5000);
//       for (var i = 0; i < 5; i++) {
//         sim.run(1000);
//         final sum = sim.equities.reduce((a, b) => a + b);
//         expect(sum, closeTo(1, 1e-9));
//       }
//     });

//     test('the same seed gives the same result', () {
//       final a = simulator(['AhAd', ''], seed: 42)..run(1000);
//       final b = simulator(['AhAd', ''], seed: 42)..run(1000);
//       expect(a.equities, b.equities);
//     });

//     test('does not modify or depend on the input lists', () {
//       final hand = cards('AhAd');
//       final board = cards('2c3c');
//       final sim = EquitySimulator(
//         hands: [hand, cards('KhKd')],
//         board: board,
//         maxSimulations: 10,
//       );
//       hand.clear();
//       board.clear();
//       expect(sim.hands[0], cards('AhAd'));
//       expect(sim.board, cards('2c3c'));
//       sim.run(10);
//       expect(hand, isEmpty);
//       expect(board, isEmpty);
//       expect(() => sim.hands[0].add(Card('2', 'd')), throwsUnsupportedError);
//     });
//   });

//   group('when every card is known', () {
//     test('a single simulation is exact', () {
//       final sim = simulator(
//         ['AhAd', 'KhKd'],
//         board: '2c7s9dJc3h',
//         maxSimulations: 1000,
//       );
//       expect(sim.maxSimulations, 1);
//       expect(sim.run(1000), 1);
//       expect(sim.isComplete, isTrue);
//       expect(sim.equities, [1, 0]);
//     });

//     test('ties split the pot evenly', () {
//       final sim = simulator(['2h3d', '4c5d', '6h7d'], board: 'AsKsQsJsTs');
//       sim.run(1);
//       expect(sim.equities, [1 / 3, 1 / 3, 1 / 3]);
//     });

//     test('only the tied best hands split the pot', () {
//       final sim = simulator(['Th2d', '8c8h', 'Tc3d'], board: 'AsKdQcJh7s');
//       sim.run(1);
//       expect(sim.equities, [0.5, 0, 0.5]);
//     });
//   });

//   group('matches exact enumeration', () {
//     // 100k simulations give a standard error below 0.0016 for any equity,
//     // so a 0.01 tolerance is more than six standard errors.
//     const tolerance = 0.01;

//     void expectMatchesExact(List<String> hands, {String board = ''}) {
//       final exact = exactEquities(hands, board: board);
//       final simulated = simulate(hands, board: board);
//       for (var i = 0; i < hands.length; i++) {
//         expect(
//           simulated[i],
//           closeTo(exact[i], tolerance),
//           reason: 'hand $i: simulated $simulated, exact $exact',
//         );
//       }
//     }

//     test('river to come, drawing to two outs', () {
//       // Only the two remaining aces save AA: 2/44.
//       final exact = exactEquities(['AsAh', 'KdKh'], board: '2c7d9hKs');
//       expect(exact[0], closeTo(2 / 44, 1e-12));
//       expectMatchesExact(['AsAh', 'KdKh'], board: '2c7d9hKs');
//     });

//     test('turn and river to come with a flush draw', () {
//       expectMatchesExact(['AhKh', 'QcQd'], board: '2h7h9c');
//     });

//     test('one random hole card and the river to come', () {
//       expectMatchesExact(['As', 'KdKc'], board: '2c7d9hQs');
//     });

//     test('a random hand against a made hand on the turn', () {
//       expectMatchesExact(['', 'AhAd'], board: 'Kc7d2h3s');
//     });

//     test('three hands with a split-pot heavy board', () {
//       expectMatchesExact(['Ah2c', 'Ad3c', 'KsQs'], board: 'AsJsTd9c');
//     });

//     test('only some board cards known, e.g. only the turn', () {
//       expectMatchesExact(['AhAd', 'KhKd'], board: 'Ac2s3s4s');
//     });
//   });

//   group('matches well-known preflop equities', () {
//     test('two random hands are even', () {
//       final equities = simulate(['', '']);
//       expect(equities[0], closeTo(0.5, 0.01));
//     });

//     test('three random hands are even', () {
//       for (final equity in simulate(['', '', ''])) {
//         expect(equity, closeTo(1 / 3, 0.01));
//       }
//     });

//     test('AA against a random hand is about 85.2%', () {
//       expect(simulate(['AhAd', ''])[0], closeTo(0.852, 0.01));
//     });

//     test('AA against KK is about 82%', () {
//       expect(simulate(['AhAd', 'KsKc'])[0], closeTo(0.82, 0.01));
//     });

//     test('22 against AKo is a coin flip, about 53%', () {
//       expect(simulate(['2c2d', 'AhKs'])[0], closeTo(0.53, 0.015));
//     });
//   });
// }
