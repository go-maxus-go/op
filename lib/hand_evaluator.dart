import 'card.dart';
import 'hand.dart';

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
  final List<String> tiebreakers;

  const HandValue(this.category, this.tiebreakers);

  @override
  int compareTo(HandValue other) {
    if (category.index > other.category.index) {
      return 1;
    }
    if (category.index < other.category.index) {
      return -1;
    }

    final thistb = tiebreakers.map((t) => Card.ranks.indexOf(t)).toList();
    final othertb = other.tiebreakers
        .map((t) => Card.ranks.indexOf(t))
        .toList();
    for (var i = 0; i < thistb.length; i++) {
      if (thistb[i] > othertb[i]) {
        return 1;
      }
      if (thistb[i] < othertb[i]) {
        return -1;
      }
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
  String toString() => '${category.name}(${tiebreakers.join()})';
}

/// Texas Hold'em hand evaluation and showdown rules.
class HandEvaluator {
  /// Returns the value of the best five-card hand that can be made from
  /// [cards], which must contain 5 to 7 distinct cards.
  static HandValue evaluate(Hand hand, List<Card> board) {
    if (board.length < 3 || board.length > 5) {
      throw ArgumentError('Invalid board: $board');
    }

    var bestValue = HandValue(HandCategory.highCard, ['7', '5', '4', '3', '2']);

    switch (board.length) {
      case 5:
        for (int i = 0; i < board.length; i++) {
          for (int j = i + 1; j < board.length; j++) {
            final handValue = evaluateFiveCards([
              hand.first,
              hand.second,
              ...List.of(board)
                ..removeAt(j)
                ..removeAt(i),
            ]);
            if (handValue > bestValue) {
              bestValue = handValue;
            }
          }
        }
        for (int i = 0; i < board.length; i++) {
          final handValue = evaluateFiveCards([
            hand.first,
            ...List.of(board)..removeAt(i),
          ]);
          if (handValue > bestValue) {
            bestValue = handValue;
          }
        }
        for (int i = 0; i < board.length; i++) {
          final handValue = evaluateFiveCards([
            hand.second,
            ...List.of(board)..removeAt(i),
          ]);
          if (handValue > bestValue) {
            bestValue = handValue;
          }
        }
        final handValue = evaluateFiveCards(board);
        if (handValue > bestValue) {
          bestValue = handValue;
        }
        break;
      case 4:
        for (int i = 0; i < board.length; i++) {
          final handValue = evaluateFiveCards([
            hand.first,
            hand.second,
            ...List.of(board)..removeAt(i),
          ]);
          ;
          if (handValue > bestValue) {
            bestValue = handValue;
          }
        }
        var handValue = evaluateFiveCards([hand.first, ...board]);
        if (handValue > bestValue) {
          bestValue = handValue;
        }
        handValue = evaluateFiveCards([hand.second, ...board]);
        if (handValue > bestValue) {
          bestValue = handValue;
        }
        break;
      case 3:
        final handValue = evaluateFiveCards([
          hand.first,
          hand.second,
          ...board,
        ]);
        if (handValue > bestValue) {
          bestValue = handValue;
        }
        break;
      default:
        throw ArgumentError('Invalid board: $board');
    }
    return bestValue;
  }

  static HandValue evaluateFiveCards(List<Card> cards) {
    cards = cards.toList()..sort((a, b) => b.compareTo(a));
    if (cards.length != 5) {
      throw ArgumentError('Expected 5 cards, got ${cards.length}');
    }
    if (cards.toSet().length != 5) {
      throw ArgumentError('Duplicate cards: $cards');
    }

    final (isStraight, straightHigh) = _isStraight(cards);
    final isFlush = cards.every((card) => card.suit == cards[0].suit);
    final counts = _countAndSort(cards);

    if (isFlush && isStraight) {
      return HandValue(HandCategory.straightFlush, [straightHigh]);
    }
    if (counts[0].$2 == 4) {
      return HandValue(HandCategory.fourOfAKind, [counts[0].$1, counts[1].$1]);
    }
    if (counts[0].$2 == 3 && counts[1].$2 == 2) {
      return HandValue(HandCategory.fullHouse, [counts[0].$1, counts[1].$1]);
    }
    if (isFlush) {
      return HandValue(HandCategory.flush, cards.map((c) => c.value).toList());
    }
    if (isStraight) {
      return HandValue(HandCategory.straight, [straightHigh]);
    }
    if (counts[0].$2 == 3) {
      return HandValue(HandCategory.threeOfAKind, [
        counts[0].$1,
        counts[1].$1,
        counts[2].$1,
      ]);
    }
    if (counts[0].$2 == 2 && counts[1].$2 == 2) {
      return HandValue(HandCategory.twoPair, [
        counts[0].$1,
        counts[1].$1,
        counts[2].$1,
      ]);
    }
    if (counts[0].$2 == 2 && counts[1].$2 == 1) {
      return HandValue(HandCategory.onePair, [
        counts[0].$1,
        counts[1].$1,
        counts[2].$1,
        counts[3].$1,
      ]);
    }

    return HandValue(HandCategory.highCard, cards.map((c) => c.value).toList());
  }

  static (bool, String) _isStraight(List<Card> cards) {
    var result = true;
    for (var i = 1; i < cards.length; i++) {
      if (Card.ranks.indexOf(cards[i].value) + 1 !=
          Card.ranks.indexOf(cards[i - 1].value)) {
        result = false;
        break;
      }
    }

    if (cards.map((c) => c.value).toList() case ['A', '5', '4', '3', '2']) {
      return (true, cards[1].value);
    }

    return (result, cards[0].value);
  }

  static List<(String, int)> _countAndSort(List<Card> cards) {
    final counts = <String, int>{};
    for (var card in cards) {
      counts[card.value] = (counts[card.value] ?? 0) + 1;
    }
    return counts.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) {
      final result = b.$2.compareTo(a.$2);
      if (result != 0) {
        return result;
      }
      return Card.ranks.indexOf(b.$1).compareTo(Card.ranks.indexOf(a.$1));
    });
  }
}
