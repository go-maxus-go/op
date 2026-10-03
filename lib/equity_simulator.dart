import 'dart:math';

import 'card.dart';
import 'hand_evaluator.dart';
import 'hand.dart';
import 'utils/range_parser.dart';

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
  List<double>? _exact;

  SimulationResults(int handsCount, this.maxSimulations)
    : _equities = List.filled(handsCount, 0.0);

  void add(Simulation simulation) {
    if (simulation.scores.length != _equities.length) {
      throw ArgumentError(
        'Expected ${_equities.length} scores, got ${simulation.scores.length}',
      );
    }
    if (isComplete) {
      throw StateError(
        'Simulation results are complete: $_simulations simulations',
      );
    }

    _simulations++;
    for (var i = 0; i < simulation.scores.length; i++) {
      _equities[i] += simulation.scores[i];
    }
  }

  /// Records [equities] as the final result without dealing.
  void finish(List<double> equities) {
    if (isComplete) {
      throw StateError(
        'Simulation results are complete: $_simulations simulations',
      );
    }
    if (equities.length != _equities.length) {
      throw ArgumentError(
        'Expected ${_equities.length} equities, got ${equities.length}',
      );
    }
    _exact = List<double>.from(equities);
  }

  List<double> get equities {
    final exact = _exact;
    if (exact != null) return List<double>.from(exact);
    if (_simulations == 0) {
      throw StateError('No simulations have been run');
    }
    return _equities.map((e) => e / _simulations).toList();
  }

  bool get isComplete => _exact != null || _simulations >= maxSimulations;
}

/// Monte Carlo equity of ranges such as `88+, AKs`, `AsKh` or `As`.
///
/// Every simulation deals one random combo from each range, then completes
/// the board from the cards that are neither on the board nor dealt to a
/// player. Players may share a card, e.g. `AsKh` vs `AsKs`.
///
/// When every range is the same set of combos, each has equal equity and
/// [run] reports that without dealing.
class EquitySimulator {
  /// The combos of each range that do not use a board card.
  final List<List<Hand>> ranges;
  final List<Card> board;

  final int maxSimulations;
  var simulations = 0;

  SimulationResults results;

  final Random _random;
  var _stopRequested = false;

  /// An empty range stands for any two cards.
  ///
  /// Throws [ArgumentError] when a range cannot be parsed or has no combo
  /// left on [board].
  EquitySimulator(
    List<String> ranges,
    List<Card> board, {
    this.maxSimulations = 10000,
    Random? random,
  }) : board = _validateBoard(board),
       ranges = [for (final range in ranges) combosOnBoard(range, board)],
       results = SimulationResults(ranges.length, maxSimulations),
       _random = random ?? Random() {
    if (maxSimulations <= 0) {
      throw ArgumentError('maxSimulations must be positive: $maxSimulations');
    }
    if (ranges.isEmpty) {
      throw ArgumentError('At least one range is required');
    }
    if (ranges.length * 2 + 5 > _deck.length) {
      throw ArgumentError('Not enough cards in the deck to deal $ranges');
    }
  }

  /// Expands [range] and drops the combos that use a card of [board].
  static List<Hand> combosOnBoard(String range, List<Card> board) {
    final List<Hand> combos;
    if (range.trim().isEmpty) {
      combos = _anyTwoCards;
    } else {
      try {
        combos = RangeParser.rangeToHands(range);
      } catch (e) {
        throw ArgumentError.value(range, 'range', 'Invalid range: $e');
      }
    }

    final possible = [
      for (final hand in combos)
        if (!board.contains(hand.first) && !board.contains(hand.second)) hand,
    ];
    if (possible.isEmpty) {
      throw ArgumentError.value(range, 'range', 'No combos left on $board');
    }
    return possible;
  }

  static List<Card> _validateBoard(List<Card> board) {
    if (board.length > 5) {
      throw ArgumentError('The board has at most 5 cards: $board');
    }
    if (board.toSet().length != board.length) {
      throw ArgumentError('Duplicate card on the board: $board');
    }
    return [...board];
  }

  static final List<Card> _deck = [
    for (final suit in Card.suits)
      for (final rank in Card.ranks) Card(rank, suit),
  ];

  static final List<Hand> _anyTwoCards = [
    for (var i = 0; i < _deck.length; i++)
      for (var j = i + 1; j < _deck.length; j++) Hand(_deck[i], _deck[j]),
  ];

  void run(Function(List<double> equities) callback, {int notifyEvery = 100}) {
    if (results.isComplete) {
      throw StateError(
        'Simulation results are complete: $simulations simulations',
      );
    }

    if (_identicalRanges) {
      results.finish(List.filled(ranges.length, 1 / ranges.length));
      callback(results.equities);
      return;
    }

    _stopRequested = false;
    while (simulations < maxSimulations && !_stopRequested) {
      final dead = {...board};
      final dealtHands = <Hand>[];
      for (final range in ranges) {
        final hand = range[_random.nextInt(range.length)];
        dealtHands.add(hand);
        dead
          ..add(hand.first)
          ..add(hand.second);
      }

      final dealBoard = [...board, ..._draw(5 - board.length, dead)];

      final evaluations = dealtHands
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

  /// True when sampling any range is the same as sampling any other.
  bool get _identicalRanges {
    final first = ranges.first.toSet();
    if (first.length != ranges.first.length) return false;
    for (final range in ranges.skip(1)) {
      if (range.length != first.length) return false;
      final combos = range.toSet();
      if (combos.length != first.length || !first.containsAll(combos)) {
        return false;
      }
    }
    return true;
  }

  /// Draws [count] distinct random cards that are not in [dead].
  List<Card> _draw(int count, Set<Card> dead) {
    final live = [
      for (final card in _deck)
        if (!dead.contains(card)) card,
    ];
    for (var i = 0; i < count; i++) {
      final j = i + _random.nextInt(live.length - i);
      final card = live[j];
      live[j] = live[i];
      live[i] = card;
    }
    return live.sublist(0, count);
  }
}
