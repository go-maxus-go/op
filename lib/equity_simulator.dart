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
    if (simulation.scores.length != _equities.length) {
      throw ArgumentError(
        'Expected ${_equities.length} scores, got ${simulation.scores.length}',
      );
    }
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
      throw StateError('No simulations have been run');
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

  var _stopRequested = false;

  EquitySimulator(this.hands, this.board, {this.maxSimulations = 10000})
    : results = SimulationResults(hands.length, maxSimulations) {
    if (maxSimulations <= 0) {
      throw ArgumentError('maxSimulations must be positive: $maxSimulations');
    }
    if (hands.isEmpty) {
      throw ArgumentError('At least one hand is required');
    }

    var known = 0;
    for (final hand in hands) {
      if (hand.length > 2) {
        throw ArgumentError('A hand has at most 2 cards: $hand');
      }
      known += hand.length;
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
    known += board.length;
    for (final card in board) {
      if (knownCards.contains(card)) {
        throw ArgumentError('Duplicate card: $card');
      }
      knownCards.add(card);
    }

    final cardsToDraw = hands.length * 2 + 5 - known;
    if (cardsToDraw > 52 - known) {
      throw ArgumentError('Not enough cards left in the deck to deal $hands');
    }
  }

  void run(Function(List<double> equities) callback, {int notifyEvery = 100}) {
    if (results.isComplete) {
      throw StateError(
        'Simulation results are complete: $simulations simulations',
      );
    }

    _stopRequested = false;
    while (simulations < maxSimulations && !_stopRequested) {
      final deck = Deck();
      final dealBoard = [...board];
      final completedHands = <Hand>[];

      for (final hand in hands) {
        final deal = [...hand];
        while (deal.length < 2) {
          deal.add(_draw(deck));
        }
        completedHands.add(Hand(deal[0], deal[1]));
      }

      while (dealBoard.length < 5) {
        dealBoard.add(_draw(deck));
      }

      final evaluations = completedHands
          .map((hand) => HandEvaluator.evaluate(hand, dealBoard))
          .toList();
      results.add(Simulation(evaluations));

      if (simulations++ % notifyEvery == 0) {
        callback(results.equities);
      }
    }

    callback(results.equities);
  }

  void stop() {
    _stopRequested = true;
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
