import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/card.dart';
import 'package:optimal_poker/equity_simulator.dart';
import 'package:optimal_poker/hand.dart';
import 'package:optimal_poker/hand_evaluator.dart';

/// Parses concatenated cards, e.g. 'AhKd2c'.
List<Card> cards(String s) => [
  for (var i = 0; i < s.length; i += 2) Card(s[i], s[i + 1]),
];

const aces = HandValue(HandCategory.onePair, ['A', 'K', 'Q', 'J']);
const kings = HandValue(HandCategory.onePair, ['K', 'Q', 'J', 'T']);
const broadway = HandValue(HandCategory.straight, ['A']);

EquitySimulator simulator(
  List<String> ranges, {
  String board = '',
  int maxSimulations = 20,
  Random? random,
}) => EquitySimulator(
  ranges,
  cards(board),
  maxSimulations: maxSimulations,
  random: random,
);

List<String> combos(EquitySimulator sim, int range) => [
  for (final hand in sim.ranges[range]) '$hand',
];

void main() {
  group('Simulation.calculateScores', () {
    test('the best hand takes the pot', () {
      expect(Simulation.calculateScores([kings, aces]), [0, 1]);
    });

    test('tied hands split the pot', () {
      expect(Simulation.calculateScores([broadway, broadway]), [0.5, 0.5]);
    });

    test('only the tied best hands are paid', () {
      expect(Simulation.calculateScores([broadway, kings, broadway]), [
        0.5,
        0,
        0.5,
      ]);
    });

    test('three tied hands share the pot equally', () {
      final scores = Simulation.calculateScores([broadway, broadway, broadway]);
      expect(scores, [1 / 3, 1 / 3, 1 / 3]);
      expect(scores.reduce((a, b) => a + b), closeTo(1, 1e-12));
    });

    test('a single hand wins', () {
      expect(Simulation.calculateScores([aces]), [1]);
    });

    test('rejects an empty showdown', () {
      expect(() => Simulation.calculateScores([]), throwsStateError);
    });
  });

  group('SimulationResults', () {
    test('equities are the mean score of each hand', () {
      final results = SimulationResults(2, 10);
      results.add(Simulation([aces, kings]));
      results.add(Simulation([broadway, broadway]));
      expect(results.equities, [0.75, 0.25]);
      expect(results.isComplete, isFalse);
    });

    test('is complete once maxSimulations have been added', () {
      final results = SimulationResults(1, 2);
      results.add(Simulation([aces]));
      results.add(Simulation([aces]));
      expect(results.isComplete, isTrue);
      expect(() => results.add(Simulation([aces])), throwsStateError);
    });

    test('equities require at least one simulation', () {
      final results = SimulationResults(2, 10);
      expect(() => results.equities, throwsStateError);
    });

    test('rejects a score list for a different number of hands', () {
      final results = SimulationResults(2, 10);
      expect(() => results.add(Simulation([broadway])), throwsArgumentError);
    });
  });

  group('EquitySimulator validation', () {
    test('rejects a hand with more than two cards', () {
      expect(() => simulator(['AhAdAc', 'KsKc']), throwsArgumentError);
    });

    test('rejects a board with more than five cards', () {
      expect(
        () => simulator(['AhAd', 'KsKc'], board: '2c3d4h5s6c7d'),
        throwsArgumentError,
      );
    });

    test('rejects an unparsable range', () {
      expect(() => simulator(['AhAh', 'KsKc']), throwsArgumentError);
      expect(() => simulator(['AK', 'KsKc']), throwsArgumentError);
      expect(() => simulator(['Ax', 'KsKc']), throwsArgumentError);
      expect(() => simulator(['AsKh, 88+, X', 'KsKc']), throwsArgumentError);
    });

    test('rejects a range without combos on the board', () {
      expect(
        () => simulator(['AhAd', 'KsKc'], board: 'Ah'),
        throwsArgumentError,
      );
      expect(
        () => simulator(['As', 'KsKc'], board: '2cAs'),
        throwsArgumentError,
      );
      expect(
        () => simulator(['AhKh, AhKs', 'QQ'], board: 'Ah2c3d'),
        throwsArgumentError,
      );
    });

    test('rejects duplicate board cards', () {
      expect(
        () => simulator(['AhAd', 'KsKc'], board: '2c3dAd'),
        throwsArgumentError,
      );
      expect(
        () => simulator(['AhAd', 'KsKc'], board: '2c3d2c'),
        throwsArgumentError,
      );
    });

    test('rejects an empty list of hands', () {
      expect(() => EquitySimulator([], []), throwsArgumentError);
    });

    test('rejects a deal that cannot be made from one deck', () {
      expect(() => EquitySimulator(List.filled(23, ''), []), returnsNormally);
      expect(
        () => EquitySimulator(List.filled(24, ''), []),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive maxSimulations', () {
      expect(
        () => simulator(['AhAd', 'KsKc'], maxSimulations: 0),
        throwsArgumentError,
      );
      expect(
        () => simulator(['AhAd', 'KsKc'], maxSimulations: -1),
        throwsArgumentError,
      );
    });
  });

  group('known showdowns', () {
    test('pair of aces beats pair of kings', () {
      final sim = simulator(
        ['AhAd', 'KsKc'],
        board: '2c7d9hJc3s',
        maxSimulations: 5,
      );
      sim.run((_) {});
      expect(sim.simulations, 5);
      expect(sim.results.isComplete, isTrue);
      expect(sim.results.equities, [1, 0]);
    });

    test('the second hand wins when it is best', () {
      final sim = simulator(
        ['KsKc', 'AhAd'],
        board: '2c7d9hJc3s',
        maxSimulations: 3,
      );
      sim.run((_) {});
      expect(sim.results.equities, [0, 1]);
    });

    test('a made board is a three-way tie', () {
      final sim = simulator(
        ['2h3d', '4c5s', '6d7c'],
        board: 'AsKsQsJsTs',
        maxSimulations: 4,
      );
      final seen = <List<double>>[];
      sim.run(seen.add, notifyEvery: 100);
      expect(seen, hasLength(2));
      for (final equity in sim.results.equities) {
        expect(equity, closeTo(1 / 3, 1e-12));
      }
    });

    test('only the tied best hands split the pot', () {
      final sim = simulator(
        ['Th2d', '8c8h', 'Tc3d'],
        board: 'AsKdQcJh7s',
        maxSimulations: 2,
      );
      sim.run((_) {});
      expect(sim.results.equities, [0.5, 0, 0.5]);
    });

    test('one fully known hand has equity 1', () {
      final sim = simulator(['AsAh'], board: 'KdQcJh2c3d', maxSimulations: 2);
      sim.run((_) {});
      expect(sim.results.equities, [1]);
    });

    test('a second run is rejected once results are complete', () {
      final sim = simulator(
        ['AhAd', 'KsKc'],
        board: '2c7d9hJc3s',
        maxSimulations: 2,
      );
      sim.run((_) {});
      expect(() => sim.run((_) {}), throwsStateError);
    });

    test('leaves a complete deal unchanged', () {
      final ranges = ['AhAd', 'KsKc'];
      final board = cards('2c7d9hJc3s');
      final sim = EquitySimulator(ranges, board, maxSimulations: 2);
      sim.run((_) {});
      expect(ranges, ['AhAd', 'KsKc']);
      expect(board, cards('2c7d9hJc3s'));
    });
  });

  group('incomplete deals', () {
    test('does not modify the caller lists', () {
      final ranges = ['As', 'KdKh'];
      final board = cards('2c7d9hKs');
      final sim = EquitySimulator(ranges, board, maxSimulations: 5);
      sim.run((_) {});
      expect(ranges, ['As', 'KdKh']);
      expect(board, cards('2c7d9hKs'));
    });

    test('re-deals the river on every simulation', () {
      // Kings have a set. Aces win only when one of the two remaining aces
      // arrives: 2/44.
      final sim = simulator(
        ['AsAh', 'KdKh'],
        board: '2c7d9hKs',
        maxSimulations: 5000,
      );
      sim.run((_) {});
      expect(sim.results.equities[0], closeTo(2 / 44, 0.015));
      expect(sim.results.equities.reduce((a, b) => a + b), closeTo(1, 1e-9));
    });

    test('turn and river are re-dealt', () {
      const hands = ['AhKh', 'QcQd'];
      const board = '2h7h9c';
      final exact = _exactBoardRunouts(hands, board);
      final sim = simulator(hands, board: board, maxSimulations: 4000);
      sim.run((_) {});
      for (var i = 0; i < hands.length; i++) {
        expect(
          sim.results.equities[i],
          closeTo(exact[i], 0.04),
          reason: 'hand $i: simulated ${sim.results.equities}, exact $exact',
        );
      }
    });

    test('stop finishes after the current simulation', () {
      final sim = simulator(
        ['AhAd', 'KsKc'],
        board: '2c7d9hJc3s',
        maxSimulations: 100,
      );
      var calls = 0;
      sim.run((_) {
        calls++;
        if (calls == 1) sim.stop();
      }, notifyEvery: 1);
      expect(sim.simulations, 1);
      expect(sim.results.isComplete, isFalse);
    });
  });

  group('range combos', () {
    test('drops combos that use a board card', () {
      final sim = simulator(['AhKh, AhKs', 'QQ'], board: '2s7hKh');
      expect(combos(sim, 0), ['AhKs']);
    });

    test('a pair keeps only the combos without the board card', () {
      final sim = simulator(['AA', 'KK'], board: 'Ad');
      expect(combos(sim, 0), unorderedEquals(['AsAh', 'AsAc', 'AhAc']));
      expect(combos(sim, 1), hasLength(6));
    });

    test('a single card is every hand holding it', () {
      final sim = simulator(['As', 'Kd'], board: 'KsQc2h');
      expect(combos(sim, 0), hasLength(51 - 3));
      expect(combos(sim, 0), everyElement(contains('As')));
      expect(combos(sim, 0), isNot(contains('AsKs')));
      expect(combos(sim, 1), hasLength(51 - 3));
      expect(combos(sim, 1), everyElement(contains('Kd')));
    });

    test('a single card works for the lowest card too', () {
      final sim = simulator(['2d', 'AA']);
      expect(combos(sim, 0), hasLength(51));
      expect(combos(sim, 0), contains('As2d'));
      expect(combos(sim, 0), contains('2s2d'));
    });

    test('an empty range is any two cards', () {
      expect(combos(simulator(['', '  ']), 0), hasLength(1326));
      expect(combos(simulator(['', '  ']), 1), hasLength(1326));
      expect(
        combos(simulator(['', 'AA'], board: '2c3d4h'), 0),
        hasLength(1176),
      );
    });

    test('duplicate combos are counted once', () {
      final sim = simulator(['AsKh, AKo, AhKs', 'QQ']);
      expect(combos(sim, 0), hasLength(12));
    });

    test('players may share a card of their ranges', () {
      expect(() => simulator(['AhAd', 'AhKd']), returnsNormally);
      expect(() => simulator(['AA', 'AA']), returnsNormally);
    });
  });

  group('range showdowns', () {
    test('a range filtered to one combo always plays it', () {
      // Only AhKs is possible: one pair of kings against queens.
      final sim = simulator(
        ['AhKh, AhKs', 'QcQd'],
        board: '2s7hKh3c4d',
        maxSimulations: 50,
      );
      sim.run((_) {});
      expect(sim.results.equities, [1, 0]);
    });

    test('a combo is picked at random in every simulation', () {
      // Aces win and 72 loses on this board, so the range wins half the time.
      final sim = simulator(
        ['AsAh, 7h2c', 'KsKh'],
        board: '3c4d8sJhQd',
        maxSimulations: 4000,
      );
      sim.run((_) {});
      expect(sim.results.equities[0], closeTo(0.5, 0.05));
    });

    test('shared cards are not dealt to the board', () {
      // Both hands hold the As, so the board can never pair the ace.
      final sim = simulator(
        ['AsKh', 'AsKs'],
        board: 'Qd7c2h',
        maxSimulations: 2000,
      );
      sim.run((_) {});
      final exact = _exactBoardRunouts(['AsKh', 'AsKs'], 'Qd7c2h');
      expect(sim.results.equities[0], closeTo(exact[0], 0.03));
      expect(sim.results.equities[1], closeTo(exact[1], 0.03));
    });

    test('dealt combos are dead cards for the board', () {
      // Kings win only when the last king arrives on the river: 1/44.
      final sim = simulator(
        ['AA', 'KK'],
        board: 'AsKs2c3d',
        maxSimulations: 5000,
      );
      sim.run((_) {});
      expect(sim.results.equities[1], closeTo(1 / 44, 0.01));
    });

    test('aces against kings preflop', () {
      final sim = simulator(['AA', 'KK'], maxSimulations: 5000);
      sim.run((_) {});
      expect(sim.results.equities[0], closeTo(0.82, 0.03));
    });

    test('random hands share the pot equally', () {
      final sim = simulator(['', ''], maxSimulations: 5000);
      sim.run((_) {});
      expect(sim.results.equities[0], closeTo(0.5, 0.03));
    });

    test('the same seed gives the same equities', () {
      List<double> run() {
        final sim = simulator(
          ['QQ+, AKs', 'As', ''],
          board: '2h',
          maxSimulations: 500,
          random: Random(7),
        );
        sim.run((_) {});
        return sim.results.equities;
      }

      expect(run(), run());
    });
  });
}

/// Exact equity of [hands] when only board cards are missing.
List<double> _exactBoardRunouts(List<String> hands, String boardText) {
  final hole = [for (final hand in hands) Hand.fromString(hand)];
  final board = cards(boardText);
  final known = {
    for (final hand in hole) ...[hand.first, hand.second],
    ...board,
  };
  final deck = [
    for (final suit in Card.suits)
      for (final rank in Card.ranks)
        if (!known.contains(Card(rank, suit))) Card(rank, suit),
  ];
  final need = 5 - board.length;
  final shares = List.filled(hands.length, 0.0);
  var deals = 0;

  void deal(int start, List<Card> extra) {
    if (extra.length == need) {
      final full = [...board, ...extra];
      final values = [
        for (final hand in hole) HandEvaluator.evaluate(hand, full),
      ];
      final scores = Simulation.calculateScores(values);
      for (var i = 0; i < scores.length; i++) {
        shares[i] += scores[i];
      }
      deals++;
      return;
    }
    for (var i = start; i < deck.length; i++) {
      deal(i + 1, [...extra, deck[i]]);
    }
  }

  deal(0, []);
  return [for (final share in shares) share / deals];
}
