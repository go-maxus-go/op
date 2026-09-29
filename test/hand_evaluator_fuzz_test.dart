import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/card.dart';
import 'package:optimal_poker/hand.dart';
import 'package:optimal_poker/hand_evaluator.dart';

void main() {
  test('best five cards of six or seven match the reference', () {
    final deck = [
      for (final suit in Card.suits)
        for (final rank in Card.ranks) Card(rank, suit),
    ];
    final random = Random(1);
    final failures = <String>[];
    for (var n = 0; n < 2000; n++) {
      final deal = [...deck]..shuffle(random);
      for (final total in [6, 7]) {
        final cards = deal.take(total).toList();
        final hole = Hand(cards[0], cards[1]);
        final board = cards.sublist(2);
        final got = HandEvaluator.evaluate(hole, board);
        final expected = _referenceBest(cards);
        if (got.category != expected.category ||
            !_same(got.tiebreakers, expected.tiebreakers)) {
          failures.add(
            'hole $hole board ${board.join()} -> $got, expected '
            '${expected.category.name}(${expected.tiebreakers.join()})',
          );
          if (failures.length == 8) fail(failures.join('\n'));
        }
      }
    }
    expect(failures, isEmpty);
  });
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

HandValue _referenceBest(List<Card> cards) {
  HandValue? best;
  for (var a = 0; a < cards.length; a++) {
    for (var b = a + 1; b < cards.length; b++) {
      for (var c = b + 1; c < cards.length; c++) {
        for (var d = c + 1; d < cards.length; d++) {
          for (var e = d + 1; e < cards.length; e++) {
            final value = _referenceFive([
              cards[a],
              cards[b],
              cards[c],
              cards[d],
              cards[e],
            ]);
            if (best == null || _cmp(value, best) > 0) best = value;
          }
        }
      }
    }
  }
  return best!;
}

/// Classifies five cards without using [HandEvaluator].
HandValue _referenceFive(List<Card> cards) {
  final ranks = [for (final card in cards) Card.ranks.indexOf(card.value)];
  final flush = cards.every((card) => card.suit == cards.first.suit);
  final straight = _straightHigh(ranks);
  final groups = _groups(ranks);

  if (flush && straight != null) {
    return HandValue(HandCategory.straightFlush, [straight]);
  }
  if (groups[0].$2 == 4) {
    return HandValue(HandCategory.fourOfAKind, [
      Card.ranks[groups[0].$1],
      Card.ranks[groups[1].$1],
    ]);
  }
  if (groups[0].$2 == 3 && groups[1].$2 == 2) {
    return HandValue(HandCategory.fullHouse, [
      Card.ranks[groups[0].$1],
      Card.ranks[groups[1].$1],
    ]);
  }
  if (flush) {
    final ordered = [...ranks]..sort((a, b) => b.compareTo(a));
    return HandValue(HandCategory.flush, [
      for (final rank in ordered) Card.ranks[rank],
    ]);
  }
  if (straight != null) {
    return HandValue(HandCategory.straight, [straight]);
  }
  if (groups[0].$2 == 3) {
    return HandValue(HandCategory.threeOfAKind, [
      for (final group in groups) Card.ranks[group.$1],
    ]);
  }
  if (groups[0].$2 == 2 && groups[1].$2 == 2) {
    return HandValue(HandCategory.twoPair, [
      for (final group in groups) Card.ranks[group.$1],
    ]);
  }
  if (groups[0].$2 == 2) {
    return HandValue(HandCategory.onePair, [
      for (final group in groups) Card.ranks[group.$1],
    ]);
  }
  final ordered = [...ranks]..sort((a, b) => b.compareTo(a));
  return HandValue(HandCategory.highCard, [
    for (final rank in ordered) Card.ranks[rank],
  ]);
}

/// Rank index of the straight's high card, or null when [ranks] is not one.
String? _straightHigh(List<int> ranks) {
  final unique = ranks.toSet();
  if (unique.length != 5) return null;
  if (unique.containsAll(const {12, 3, 2, 1, 0})) return '5';
  final ordered = unique.toList()..sort();
  for (var i = 1; i < ordered.length; i++) {
    if (ordered[i] != ordered[i - 1] + 1) return null;
  }
  return Card.ranks[ordered.last];
}

/// (rank index, count), most copies first and higher rank first within a count.
List<(int, int)> _groups(List<int> ranks) {
  final counts = <int, int>{};
  for (final rank in ranks) {
    counts[rank] = (counts[rank] ?? 0) + 1;
  }
  return counts.entries.map((entry) => (entry.key, entry.value)).toList()
    ..sort((a, b) {
      final byCount = b.$2.compareTo(a.$2);
      if (byCount != 0) return byCount;
      return b.$1.compareTo(a.$1);
    });
}

int _cmp(HandValue a, HandValue b) {
  final byCategory = a.category.index.compareTo(b.category.index);
  if (byCategory != 0) return byCategory;
  final n = min(a.tiebreakers.length, b.tiebreakers.length);
  for (var i = 0; i < n; i++) {
    final byRank = Card.ranks
        .indexOf(a.tiebreakers[i])
        .compareTo(Card.ranks.indexOf(b.tiebreakers[i]));
    if (byRank != 0) return byRank;
  }
  return a.tiebreakers.length.compareTo(b.tiebreakers.length);
}
