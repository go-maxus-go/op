import 'card.dart';

/// Poker hand categories, ordered from weakest to strongest.
enum HandCategory {
  highCard,
  onePair,
  twoPair,
  threeOfAKind,
  straight,
  flush,
  fullHouse,
  fourOfAKind,
  straightFlush,
}

/// The strength of a five-card poker hand. A stronger hand compares greater.
class HandValue implements Comparable<HandValue> {
  final HandCategory category;

  /// Rank indices into [Card.ranks] (0 = '2', 12 = 'A') that break ties
  /// between hands of the same [category], most significant first.
  ///
  /// Hands of the same category always have the same number of tiebreakers.
  final List<int> tiebreakers;

  const HandValue(this.category, this.tiebreakers);

  @override
  int compareTo(HandValue other) {
    if (category != other.category) {
      return category.index - other.category.index;
    }
    for (var i = 0; i < tiebreakers.length; i++) {
      final diff = tiebreakers[i] - other.tiebreakers[i];
      if (diff != 0) return diff;
    }
    return 0;
  }

  bool operator >(HandValue other) => compareTo(other) > 0;
  bool operator <(HandValue other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) => other is HandValue && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(category, Object.hashAll(tiebreakers));

  @override
  String toString() =>
      '${category.name}(${tiebreakers.map((r) => Card.ranks[r]).join()})';
}

/// Texas Hold'em hand evaluation and showdown rules.
class HandEvaluator {
  static const int _ace = 12;
  static const int _five = 3;

  /// Returns the value of the best five-card hand that can be made from
  /// [cards], which must contain 5 to 7 distinct cards.
  static HandValue evaluate(List<Card> cards) {
    if (cards.length < 5 || cards.length > 7) {
      throw ArgumentError('Expected 5 to 7 cards, got ${cards.length}');
    }
    if (cards.toSet().length != cards.length) {
      throw ArgumentError('Duplicate cards: $cards');
    }

    final r = [for (final card in cards) _rank(card)];
    final s = [for (final card in cards) card.suit];
    final n = cards.length;
    HandValue? best;
    for (var a = 0; a < n; a++) {
      for (var b = a + 1; b < n; b++) {
        for (var c = b + 1; c < n; c++) {
          for (var d = c + 1; d < n; d++) {
            for (var e = d + 1; e < n; e++) {
              final value = _evaluateFive(
                [r[a], r[b], r[c], r[d], r[e]],
                [s[a], s[b], s[c], s[d], s[e]],
              );
              if (best == null || value > best) best = value;
            }
          }
        }
      }
    }
    return best!;
  }

  /// Returns the indices of the [hands] that win the pot at showdown on a
  /// complete five-card [board]. More than one index means a split pot.
  static List<int> winners(List<List<Card>> hands, List<Card> board) {
    if (hands.isEmpty) throw ArgumentError('Expected at least one hand');
    if (board.length != 5) {
      throw ArgumentError('Expected a 5-card board, got ${board.length}');
    }
    for (final hand in hands) {
      if (hand.length != 2) {
        throw ArgumentError('Expected 2 hole cards, got $hand');
      }
    }
    final allCards = [...board, for (final hand in hands) ...hand];
    if (allCards.toSet().length != allCards.length) {
      throw ArgumentError('Duplicate cards: $allCards');
    }

    final values = [
      for (final hand in hands) evaluate([...hand, ...board]),
    ];
    final best = values.reduce((a, b) => a > b ? a : b);
    return [
      for (var i = 0; i < values.length; i++)
        if (values[i] == best) i,
    ];
  }

  /// Returns the value of exactly five distinct cards.
  static HandValue evaluateFive(List<Card> cards) {
    if (cards.length != 5) {
      throw ArgumentError('Expected 5 cards, got ${cards.length}');
    }
    if (cards.toSet().length != 5) {
      throw ArgumentError('Duplicate cards: $cards');
    }
    return _evaluateFive(
      [for (final card in cards) _rank(card)],
      [for (final card in cards) card.suit],
    );
  }

  static int _rank(Card card) => Card.ranks.indexOf(card.value);

  /// Returns the value of five distinct cards given as parallel lists of
  /// rank indices and suits. Sorts [ranks] in place.
  static HandValue _evaluateFive(List<int> ranks, List<String> suits) {
    ranks.sort((a, b) => b - a);

    final counts = List.filled(Card.ranks.length, 0);
    final distinct = <int>[];
    for (final rank in ranks) {
      if (counts[rank]++ == 0) distinct.add(rank);
    }
    // Distinct ranks, by number of occurrences and then by rank, descending.
    // E.g. K-K-K-4-4 gives [K, 4] and A-9-9-5-2 gives [9, A, 5, 2].
    final groups = distinct
      ..sort((a, b) {
        final byCount = counts[b] - counts[a];
        return byCount != 0 ? byCount : b - a;
      });
    final largest = counts[groups[0]];
    final secondLargest = groups.length > 1 ? counts[groups[1]] : 0;

    final isFlush = suits.every((suit) => suit == suits[0]);
    final straightHigh = groups.length == 5 ? _straightHigh(ranks) : null;

    if (isFlush && straightHigh != null) {
      return HandValue(HandCategory.straightFlush, [straightHigh]);
    }
    if (largest == 4) {
      return HandValue(HandCategory.fourOfAKind, groups);
    }
    if (largest == 3 && secondLargest == 2) {
      return HandValue(HandCategory.fullHouse, groups);
    }
    if (isFlush) {
      return HandValue(HandCategory.flush, ranks);
    }
    if (straightHigh != null) {
      return HandValue(HandCategory.straight, [straightHigh]);
    }
    if (largest == 3) {
      return HandValue(HandCategory.threeOfAKind, groups);
    }
    if (largest == 2 && secondLargest == 2) {
      return HandValue(HandCategory.twoPair, groups);
    }
    if (largest == 2) {
      return HandValue(HandCategory.onePair, groups);
    }
    return HandValue(HandCategory.highCard, ranks);
  }

  /// Returns the highest rank of the straight formed by five distinct ranks
  /// sorted in descending order, or null if they do not form a straight.
  /// The wheel (A-2-3-4-5) is a five-high straight.
  static int? _straightHigh(List<int> ranks) {
    if (ranks[0] - ranks[4] == 4) return ranks[0];
    if (ranks[0] == _ace && ranks[1] == _five) return _five;
    return null;
  }
}
