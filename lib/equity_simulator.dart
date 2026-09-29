import 'dart:math';

import 'card.dart';
import 'hand_evaluator.dart';

/// Monte Carlo equity calculator for Texas Hold'em.
///
/// Each hand may have 0 to 2 known hole cards and the board 0 to 5 known
/// cards. In every simulation the missing cards are dealt at random from the
/// cards that are not known, and the pot is split evenly between the winners.
///
/// Call [run] repeatedly to refine [equities] until [isComplete].
class EquitySimulator {
  final List<List<Card>> hands;
  final List<Card> board;

  /// The number of simulations after which [isComplete] becomes true.
  ///
  /// When every card is known the outcome is fixed, so a single simulation
  /// is exact and this is 1.
  final int maxSimulations;

  final Random _random;

  /// Cards not known to be in any hand or on the board.
  final List<Card> _deck;

  /// The number of cards dealt from [_deck] in each simulation.
  final int _unknownCount;

  /// Sum over all simulations of each hand's share of the pot.
  final List<double> _potShares;

  int _simulations = 0;

  EquitySimulator({
    required List<List<Card>> hands,
    List<Card> board = const [],
    required int maxSimulations,
    Random? random,
  }) : _deck = _remainingDeck(hands, board),
       hands = List<List<Card>>.unmodifiable(
         hands.map(List<Card>.unmodifiable),
       ),
       board = List<Card>.unmodifiable(board),
       _random = random ?? Random(),
       _unknownCount = _unknownCardCount(hands, board),
       _potShares = List.filled(hands.length, 0),
       maxSimulations = _unknownCardCount(hands, board) == 0
           ? 1
           : maxSimulations {
    if (maxSimulations < 1) {
      throw ArgumentError('maxSimulations must be positive: $maxSimulations');
    }
  }

  static int _unknownCardCount(List<List<Card>> hands, List<Card> board) =>
      hands.length * 2 +
      5 -
      board.length -
      hands.fold(0, (sum, hand) => sum + hand.length);

  /// Validates the known cards and returns the cards that are left.
  static List<Card> _remainingDeck(List<List<Card>> hands, List<Card> board) {
    if (hands.length < 2) {
      throw ArgumentError('Expected at least 2 hands, got ${hands.length}');
    }
    for (final hand in hands) {
      if (hand.length > 2) {
        throw ArgumentError('A hand has at most 2 cards: $hand');
      }
    }
    if (board.length > 5) {
      throw ArgumentError('The board has at most 5 cards: $board');
    }
    final known = [...board, for (final hand in hands) ...hand];
    if (known.toSet().length != known.length) {
      throw ArgumentError('Duplicate cards: $known');
    }
    if (hands.length * 2 + 5 > Card.ranks.length * Card.suits.length) {
      throw ArgumentError('Too many hands for one deck: ${hands.length}');
    }
    return [
      for (final suit in Card.suits)
        for (final rank in Card.ranks)
          if (!known.contains(Card(rank, suit))) Card(rank, suit),
    ];
  }

  /// The number of simulations run so far.
  int get simulations => _simulations;

  bool get isComplete => _simulations >= maxSimulations;

  /// Each hand's expected share of the pot, between 0 and 1, in the order of
  /// [hands]. The equities sum to 1.
  List<double> get equities {
    if (_simulations == 0) {
      throw StateError('No simulations have been run yet');
    }
    return [for (final share in _potShares) share / _simulations];
  }

  /// Runs up to [count] more simulations without exceeding [maxSimulations].
  /// Returns the number of simulations that were run.
  int run(int count) {
    final toRun = min(count, maxSimulations - _simulations);
    for (var i = 0; i < toRun; i++) {
      _simulateOnce();
    }
    return max(toRun, 0);
  }

  void _simulateOnce() {
    // Partial Fisher-Yates shuffle: moves a uniformly random selection of
    // _unknownCount distinct cards to the front of the deck.
    for (var i = 0; i < _unknownCount; i++) {
      final j = i + _random.nextInt(_deck.length - i);
      final card = _deck[i];
      _deck[i] = _deck[j];
      _deck[j] = card;
    }

    var next = 0;
    final dealtHands = [
      for (final hand in hands)
        [...hand, for (var i = hand.length; i < 2; i++) _deck[next++]],
    ];
    final dealtBoard = [
      ...board,
      for (var i = board.length; i < 5; i++) _deck[next++],
    ];

    // final winners = HandEvaluator.winners(dealtHands, dealtBoard);
    // for (final winner in winners) {
    //   _potShares[winner] += 1 / winners.length;
    // }
    _simulations++;
  }
}
