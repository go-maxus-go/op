import 'card.dart';

/// Represents an unordered 2-card poker hand combination (combo).
/// e.g. AhKd, 2s2c, etc.
class Hand implements Comparable<Hand> {
  final Card first;
  final Card second;

  /// Creates a Hand with two cards.
  /// Automatically orders the cards so that `first >= second`
  /// (higher rank first, or if same rank, higher suit first).
  Hand(Card c1, Card c2)
    : first = _order(c1, c2).$1,
      second = _order(c1, c2).$2 {
    if (c1 == c2) {
      throw ArgumentError('A hand cannot contain duplicate cards: $c1 and $c2');
    }
  }

  /// Parses a 4-character hand combination string, e.g. "AhKd", "2s2c", "KsQs".
  factory Hand.fromString(String s) {
    if (s.length != 4) {
      throw FormatException(
        'Hand string must be exactly 4 characters (e.g. "AhKd"): "$s"',
      );
    }
    final c1 = Card(s[0], s[1]);
    final c2 = Card(s[2], s[3]);
    return Hand(c1, c2);
  }

  static (Card, Card) _order(Card c1, Card c2) {
    if (c1 > c2) {
      return (c1, c2);
    } else if (c2 > c1) {
      return (c2, c1);
    } else {
      // Same rank, order suits deterministically (s, h, c, d)
      if (Card.suits.indexOf(c1.suit) <= Card.suits.indexOf(c2.suit)) {
        return (c1, c2);
      } else {
        return (c2, c1);
      }
    }
  }

  bool get isPair => first.value == second.value;
  bool get isSuited => !isPair && first.suit == second.suit;
  bool get isOffsuit => !isPair && first.suit != second.suit;

  /// Returns canonical 4-character representation, e.g. "AhKd".
  @override
  String toString() => '$first$second';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hand &&
          runtimeType == other.runtimeType &&
          first == other.first &&
          second == other.second;

  @override
  int get hashCode => Object.hash(first.hashCode, second.hashCode);

  @override
  int compareTo(Hand that) {
    if (Card.ranks.indexOf(first.value) <
        Card.ranks.indexOf(that.first.value)) {
      return -1;
    }

    if (Card.ranks.indexOf(first.value) >
        Card.ranks.indexOf(that.first.value)) {
      return 1;
    }

    if (Card.ranks.indexOf(second.value) <
        Card.ranks.indexOf(that.second.value)) {
      return -1;
    }

    if (Card.ranks.indexOf(second.value) >
        Card.ranks.indexOf(that.second.value)) {
      return 1;
    }

    if (Card.suits.indexOf(first.suit) < Card.suits.indexOf(that.first.suit)) {
      return -1;
    }

    if (Card.suits.indexOf(first.suit) > Card.suits.indexOf(that.first.suit)) {
      return 1;
    }

    if (Card.suits.indexOf(second.suit) <
        Card.suits.indexOf(that.second.suit)) {
      return -1;
    }

    if (Card.suits.indexOf(second.suit) >
        Card.suits.indexOf(that.second.suit)) {
      return 1;
    }

    return 0;
  }
}
