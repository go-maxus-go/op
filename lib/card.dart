const values = [
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'T',
  'J',
  'Q',
  'K',
  'A',
];

const suits = ['s', 'h', 'c', 'd'];

class Card {
  final String value;
  final String suit;

  const Card(this.value, this.suit)
    : assert(
        value == '2' ||
            value == '3' ||
            value == '4' ||
            value == '5' ||
            value == '6' ||
            value == '7' ||
            value == '8' ||
            value == '9' ||
            value == 'T' ||
            value == 'J' ||
            value == 'Q' ||
            value == 'K' ||
            value == 'A',
      ),
      assert(suit == 's' || suit == 'h' || suit == 'c' || suit == 'd');

  String get assetPath => 'assets/deck/card_$value$suit.png';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Card &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          suit == other.suit;

  @override
  int get hashCode => value.hashCode ^ suit.hashCode;

  @override
  String toString() => '$value$suit';

  bool sameValue(Card card) => value == card.value;

  bool operator <(Card card) {
    return values.indexOf(value) < values.indexOf(card.value);
  }

  bool operator >(Card card) {
    return values.indexOf(value) > values.indexOf(card.value);
  }

  bool operator <=(Card card) {
    return values.indexOf(value) <= values.indexOf(card.value);
  }

  bool operator >=(Card card) {
    return values.indexOf(value) >= values.indexOf(card.value);
  }

  bool sameSuit(Card card) => suit == card.suit;
}
