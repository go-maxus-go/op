import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/card.dart';

void main() {
  group('Card Tests', () {
    test('Card properties are set correctly', () {
      const card = Card('A', 's');
      expect(card.value, 'A');
      expect(card.suit, 's');
    });

    test('Card assetPath is correct', () {
      const card = Card('T', 'd');
      expect(card.assetPath, 'assets/deck/card_Td.png');
    });

    test('Card equality and hashCode', () {
      const card1 = Card('K', 'c');
      const card2 = Card('K', 'c');
      const card3 = Card('Q', 'c');

      expect(card1, equals(card2));
      expect(card1.hashCode, equals(card2.hashCode));
      
      expect(card1, isNot(equals(card3)));
      expect(card1.hashCode, isNot(equals(card3.hashCode)));
    });

    test('Card toString', () {
      const card = Card('2', 'h');
      expect(card.toString(), '2h');
    });

    test('Card validation throws on invalid value', () {
      expect(() => Card('1', 's'), throwsAssertionError);
      expect(() => Card('X', 's'), throwsAssertionError);
    });

    test('Card validation throws on invalid suit', () {
      expect(() => Card('A', 'x'), throwsAssertionError);
      expect(() => Card('A', '1'), throwsAssertionError);
    });

    test('Card sameValue works correctly', () {
      const card1 = Card('A', 's');
      const card2 = Card('A', 'h');
      const card3 = Card('K', 's');

      expect(card1.sameValue(card2), isTrue);
      expect(card1.sameValue(card3), isFalse);
    });

    test('Card comparison operators work correctly', () {
      const card2 = Card('2', 's');
      const cardT = Card('T', 'h');
      const cardJ = Card('J', 'c');
      const cardA = Card('A', 'd');
      const cardA2 = Card('A', 's');

      // Operator <
      expect(card2 < cardT, isTrue);
      expect(cardT < cardJ, isTrue);
      expect(cardJ < cardA, isTrue);
      expect(cardA < card2, isFalse);
      expect(cardA < cardA2, isFalse); // Same value is not strictly less

      // Operator >
      expect(cardA > cardJ, isTrue);
      expect(cardJ > cardT, isTrue);
      expect(cardT > card2, isTrue);
      expect(card2 > cardA, isFalse);
      expect(cardA > cardA2, isFalse);

      // Operator <=
      expect(card2 <= cardT, isTrue);
      expect(cardA <= cardA2, isTrue);
      expect(cardA <= cardJ, isFalse);

      // Operator >=
      expect(cardT >= card2, isTrue);
      expect(cardA >= cardA2, isTrue);
      expect(cardJ >= cardA, isFalse);
    });

    test('Card sameSuit works correctly', () {
      const card1 = Card('A', 's');
      const card2 = Card('K', 's');
      const card3 = Card('A', 'h');

      expect(card1.sameSuit(card2), isTrue);
      expect(card1.sameSuit(card3), isFalse);
    });
  });
}
