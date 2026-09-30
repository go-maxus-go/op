import 'card.dart';
import 'hand_evaluator.dart';
import 'deck.dart';
import 'hand.dart';

class Simulation {
  final List<HandValue> values;
  final List<double> scores;

  Simulation(this.values) : scores = calculateScores(values);

  static List<double> calculateScores(List<HandValue> values) {
    final best = values.reduce((l, r) => l.compareTo(r) > 0 ? l : r);
    final winnersCount = values.where((v) => v.compareTo(best) == 0).length;
    final scores = List.filled(values.length, 0.0);
    for (var i = 0; i < values.length; i++) {
      if (values[i] == best) {
        scores[i] = 1.0 / winnersCount;
      }
    }
    return scores;
  }
}

class SimulationResults {
  final List<double> _equities;
  final int maxSimulations;
  var _simulations = 0;

  SimulationResults(int handsCount, this.maxSimulations)
    : _equities = List.filled(handsCount, 0.0);

  void add(Simulation simulation) {
    if (_simulations >= maxSimulations) {
      throw StateError(
        'Simulation results are complete: $_simulations simulations',
      );
    }

    _simulations++;
    for (var i = 0; i < simulation.scores.length; i++) {
      _equities[i] += simulation.scores[i];
    }
  }

  List<double> get equities {
    if (_simulations == 0) {
      return _equities.toList();
    }
    return _equities.map((e) => e / _simulations).toList();
  }

  bool get isComplete => _simulations >= maxSimulations;
}

class EquitySimulator {
  final List<List<Card>> hands;
  final List<Card> board;

  final int maxSimulations;
  var simulations = 0;

  final Set<Card> knownCards = {};

  SimulationResults results;

  EquitySimulator(this.hands, this.board, {this.maxSimulations = 10000})
    : results = SimulationResults(hands.length, maxSimulations) {
    for (final hand in hands) {
      if (hand.length > 2) {
        throw ArgumentError('A hand has at most 2 cards: $hand');
      }
      for (final card in hand) {
        if (knownCards.contains(card)) {
          throw ArgumentError('Duplicate card: $card');
        }
        knownCards.add(card);
      }
    }

    if (board.length > 5) {
      throw ArgumentError('The board has at most 5 cards: $board');
    }
    for (final card in board) {
      if (knownCards.contains(card)) {
        throw ArgumentError('Duplicate card: $card');
      }
      knownCards.add(card);
    }
  }

  void run(Function(List<double> equities) callback, {notifyEvery = 100}) {
    for (simulations = 0; simulations < maxSimulations; simulations++) {
      final deck = Deck();

      final completedHands = <Hand>[];

      for (final hand in hands) {
        while (hand.length < 2) {
          hand.add(_draw(deck));
        }
        completedHands.add(Hand(hand[0], hand[1]));
      }

      while (board.length < 5) {
        board.add(_draw(deck));
      }

      final evaluations = completedHands
          .map((hand) => HandEvaluator.evaluate(hand, board))
          .toList();
      results.add(Simulation(evaluations));

      if (simulations % notifyEvery == 0) {
        callback(results.equities);
      }
    }

    callback(results.equities);
  }

  void stop() {
    simulations = maxSimulations;
  }

  Card _draw(Deck deck) {
    while (true) {
      final card = deck.nextCard();
      if (!knownCards.contains(card)) {
        return card;
      }
    }
  }
}
