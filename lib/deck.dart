import 'dart:math';
import 'card.dart';

class Deck {
  final List<Card> _cards = [];
  int _currentIndex = 0;

  Deck({int? seed}) {
    const suits = ['s', 'h', 'c', 'd'];
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

    for (var s in suits) {
      for (var v in values) {
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
