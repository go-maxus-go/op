import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/hand.dart';
import 'package:optimal_poker/card.dart';

void main() {
  group('Hand', () {
    test('Constructor orders cards (rank priority)', () {
      final h1 = Hand(const Card('2', 's'), const Card('A', 'h'));
      expect(h1.first, const Card('A', 'h'));
      expect(h1.second, const Card('2', 's'));

      final h2 = Hand(const Card('K', 'd'), const Card('Q', 'c'));
      expect(h2.first, const Card('K', 'd'));
      expect(h2.second, const Card('Q', 'c'));
    });

    test('Constructor orders cards (suit priority for same rank)', () {
      // suits are ordered ['s', 'h', 'c', 'd']
      final h1 = Hand(const Card('A', 'h'), const Card('A', 's'));
      expect(h1.first, const Card('A', 's'));
      expect(h1.second, const Card('A', 'h'));

      final h2 = Hand(const Card('T', 'd'), const Card('T', 'c'));
      expect(h2.first, const Card('T', 'c'));
      expect(h2.second, const Card('T', 'd'));
    });

    test('Constructor throws on duplicate cards', () {
      expect(
        () => Hand(const Card('A', 's'), const Card('A', 's')),
        throwsArgumentError,
      );
    });

    test('Hand.fromString parses correctly', () {
      final hand = Hand.fromString('AsKd');
      expect(hand.first, const Card('A', 's'));
      expect(hand.second, const Card('K', 'd'));
    });

    test('Hand.fromString throws on invalid length', () {
      expect(() => Hand.fromString('AsK'), throwsFormatException);
      expect(() => Hand.fromString('AsKdd'), throwsFormatException);
    });

    test('isPair, isSuited, isOffsuit work correctly', () {
      final pair = Hand.fromString('AsAh');
      expect(pair.isPair, isTrue);
      expect(pair.isSuited, isFalse);
      expect(pair.isOffsuit, isFalse);

      final suited = Hand.fromString('KsQs');
      expect(suited.isPair, isFalse);
      expect(suited.isSuited, isTrue);
      expect(suited.isOffsuit, isFalse);

      final offsuit = Hand.fromString('JsTd');
      expect(offsuit.isPair, isFalse);
      expect(offsuit.isSuited, isFalse);
      expect(offsuit.isOffsuit, isTrue);
    });

    test('toString returns canonical representation', () {
      expect(Hand.fromString('AsKd').toString(), 'AsKd');
      expect(
        Hand(const Card('2', 'd'), const Card('7', 'h')).toString(),
        '7h2d',
      );
    });

    test('Equality and hashCode', () {
      final h1 = Hand.fromString('AsKd');
      final h2 = Hand.fromString('KdAs');
      final h3 = Hand.fromString('AsKh');

      expect(h1, equals(h2));
      expect(h1.hashCode, equals(h2.hashCode));
      expect(h1, isNot(equals(h3)));
    });

    test('compareTo orders hands correctly', () {
      final hands = [
        Hand.fromString('2s2h'),
        Hand.fromString('AsKd'),
        Hand.fromString('KsQs'),
        Hand.fromString('7h2d'),
      ];

      hands.sort();

      expect(hands[0].toString(), '2s2h');
      expect(hands[1].toString(), '7h2d');
      expect(hands[2].toString(), 'KsQs');
      expect(hands[3].toString(), 'AsKd');
    });

    test('compareTo orders by suit when ranks are equal', () {
      final hands = [
        Hand.fromString('AsKs'),
        Hand.fromString('AhKh'),
        Hand.fromString('AcKc'),
        Hand.fromString('AdKd'),
      ];

      // Suits: s=0, h=1, c=2, d=3
      // They are already in order in the list above if we want ascending

      final shuffled = List<Hand>.from(hands)..shuffle();
      shuffled.sort();

      for (int i = 0; i < hands.length; i++) {
        expect(shuffled[i], equals(hands[i]));
      }
    });
  });
}
