import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/deck.dart';
import 'package:optimal_poker/card.dart';

void main() {
  group('Deck Tests', () {
    test('Deck creates 52 cards', () {
      final deck = Deck(seed: 0);
      int count = 0;
      while (true) {
        try {
          deck.nextCard();
          count++;
        } catch (e) {
          break;
        }
      }
      expect(count, 52);
    });

    test('Deck throws exception when empty', () {
      final deck = Deck(seed: 0);
      for (int i = 0; i < 52; i++) {
        deck.nextCard();
      }
      expect(() => deck.nextCard(), throwsException);
    });

    test('Deck with seed=0 maintains specific order', () {
      final deck = Deck(seed: 0);
      for (var s in Card.suits) {
        for (var v in Card.ranks) {
          final card = deck.nextCard();
          expect(card.value, v);
          expect(card.suit, s);
        }
      }
    });

    test('Deck shuffles randomly with default constructor', () {
      final deck1 = Deck();
      final deck2 = Deck();

      // While it's theoretically possible for two shuffled decks to be identical,
      // the probability is 1 in 52!, which is virtually 0.
      bool isDifferent = false;
      for (int i = 0; i < 52; i++) {
        if (deck1.nextCard() != deck2.nextCard()) {
          isDifferent = true;
          break;
        }
      }

      expect(isDifferent, isTrue);
    });

    test('Deck with specific seed yields deterministic order', () {
      final deck1 = Deck(seed: 42);
      final deck2 = Deck(seed: 42);

      for (int i = 0; i < 52; i++) {
        expect(deck1.nextCard(), equals(deck2.nextCard()));
      }
    });
  });
}
