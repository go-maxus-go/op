import 'dart:math';
import 'card.dart';

class Deck {
  final List<Card> _cards = [];
  int _currentIndex = 0;

  Deck({int? seed}) {
    for (var s in Card.suits) {
      for (var v in Card.ranks) {
        _cards.add(Card(v, s));
      }
    }

    if (seed != 0) {
      _cards.shuffle(seed != null ? Random(seed) : Random());
    }
  }

  Card nextCard() {
    if (_currentIndex >= _cards.length) {
      throw Exception('No more cards in the deck');
    }
    return _cards[_currentIndex++];
  }
}
