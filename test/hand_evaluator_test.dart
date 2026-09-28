import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/card.dart';
import 'package:optimal_poker/hand_evaluator.dart';

/// Parses concatenated cards, e.g. 'AhKd2c'.
List<Card> cards(String s) => [
  for (var i = 0; i < s.length; i += 2) Card(s[i], s[i + 1]),
];

HandValue eval(String s) => HandEvaluator.evaluate(cards(s));

int rank(String r) => Card.ranks.indexOf(r);

List<int> ranks(String s) => [for (final r in s.split('')) rank(r)];

void main() {
  group('HandValue', () {
    test('compares by category first', () {
      const pair = HandValue(HandCategory.onePair, [0, 1, 2, 3]);
      const highCard = HandValue(HandCategory.highCard, [12, 11, 10, 9, 7]);
      expect(pair > highCard, isTrue);
      expect(highCard < pair, isTrue);
      expect(pair.compareTo(highCard), greaterThan(0));
    });

    test('compares tiebreakers in order of significance', () {
      const a = HandValue(HandCategory.onePair, [5, 12, 3, 2]);
      const b = HandValue(HandCategory.onePair, [5, 11, 10, 9]);
      expect(a > b, isTrue);
      expect(b < a, isTrue);
    });

    test('equal values are equal and share a hash code', () {
      const a = HandValue(HandCategory.flush, [12, 10, 8, 4, 2]);
      const b = HandValue(HandCategory.flush, [12, 10, 8, 4, 2]);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a.compareTo(b), 0);
      expect(a > b, isFalse);
      expect(a < b, isFalse);
    });

    test('toString is readable', () {
      expect(eval('AhAdKsKc2d').toString(), 'twoPair(AK2)');
    });
  });

  group('evaluateFive categories', () {
    final cases = {
      'AsKsQsJsTs': (HandCategory.straightFlush, 'A'),
      '9h8h7h6h5h': (HandCategory.straightFlush, '9'),
      '5d4d3d2dAd': (HandCategory.straightFlush, '5'),
      'QcQdQhQs3d': (HandCategory.fourOfAKind, 'Q3'),
      '2c2d2hAsAd': (HandCategory.fullHouse, '2A'),
      'Kh9h7h4h2h': (HandCategory.flush, 'K9742'),
      'Th9c8d7s6h': (HandCategory.straight, 'T'),
      'AhKcQdJsTh': (HandCategory.straight, 'A'),
      'As2c3d4h5s': (HandCategory.straight, '5'),
      '7c7d7hKs2d': (HandCategory.threeOfAKind, '7K2'),
      'JcJd4h4sAd': (HandCategory.twoPair, 'J4A'),
      '9c9dAhKs2d': (HandCategory.onePair, '9AK2'),
      'AcJd8h5s3d': (HandCategory.highCard, 'AJ853'),
    };
    cases.forEach((hand, expected) {
      test('$hand is ${expected.$1.name}', () {
        final value = HandEvaluator.evaluateFive(cards(hand));
        expect(value.category, expected.$1);
        expect(value.tiebreakers, ranks(expected.$2));
      });
    });

    test('card order does not matter', () {
      expect(eval('2d4h4sAdJc'), eval('Jc2d4h4sAd'));
      expect(eval('5s4h3d2cAs'), eval('As2c3d4h5s'));
    });

    test('straights do not wrap around the ace', () {
      expect(eval('QsKdAh2c3s').category, HandCategory.highCard);
      expect(eval('KsAd2h3c4s').category, HandCategory.highCard);
    });

    test('four suited cards are not a flush', () {
      expect(eval('Ah9h7h4h2c').category, HandCategory.highCard);
    });

    test('four to a straight is not a straight', () {
      expect(eval('Th9c8d7sAh').category, HandCategory.highCard);
    });
  });

  group('category order', () {
    test('every category beats the ones below it', () {
      final ascending = [
        eval('AcJd8h5s3d'), // high card
        eval('2c2d3h4s6d'), // pair of twos
        eval('3c3d2h2s4d'), // two pair
        eval('2c2d2h3s4d'), // trips
        eval('As2c3d4h5s'), // wheel
        eval('7h5h4h3h2h'), // seven-high flush
        eval('2c2d2h3s3d'), // full house
        eval('2c2d2h2s3d'), // quads
        eval('5d4d3d2dAd'), // steel wheel
      ];
      for (var i = 0; i < ascending.length; i++) {
        expect(ascending[i].category, HandCategory.values[i]);
        for (var j = 0; j < i; j++) {
          expect(ascending[i] > ascending[j], isTrue, reason: '$i vs $j');
        }
      }
    });

    test('royal flush is the best possible hand', () {
      expect(eval('AsKsQsJsTs') > eval('KhQhJhTh9h'), isTrue);
    });
  });

  group('tiebreakers within a category', () {
    void expectBetter(String better, String worse) {
      expect(eval(better) > eval(worse), isTrue, reason: '$better > $worse');
    }

    void expectTie(String a, String b) {
      expect(eval(a), eval(b), reason: '$a == $b');
    }

    test('straight flush', () {
      expectBetter('6d5d4d3d2d', '5c4c3c2cAc');
      expectTie('9h8h7h6h5h', '9s8s7s6s5s');
    });

    test('four of a kind', () {
      expectBetter('3c3d3h3s2d', '2c2d2h2sAd');
      expectBetter('7c7d7h7sAd', '7c7d7h7sKd');
    });

    test('full house', () {
      expectBetter('3c3d3h2s2d', '2c2d2hAsAd');
      expectBetter('KcKdKhAsAd', 'KcKdKhQsQd');
    });

    test('flush compares all five cards', () {
      expectBetter('Ah9h7h4h3h', 'Ac9c7c4c2c');
      expectBetter('AhKh3h2h4h', 'AcQcJcTc8c');
      expectTie('Ah9h7h4h3h', 'As9s7s4s3s');
    });

    test('straight', () {
      expectBetter('6h5c4d3s2h', '5h4c3d2sAh');
      expectBetter('AhKcQdJsTh', 'KhQcJdTs9h');
      expectTie('Th9c8d7s6h', 'Tc9d8s7h6c');
    });

    test('three of a kind', () {
      expectBetter('3c3d3h2s4d', '2c2d2hAsKd');
      expectBetter('7c7d7hAs2d', '7c7d7hKsQd');
      expectBetter('7c7d7hAs3d', '7c7d7hAs2d');
    });

    test('two pair', () {
      expectBetter('KcKd2h2s3d', 'QcQdJhJsAd');
      expectBetter('KcKd3h3s2d', 'KcKd2h2sAd');
      expectBetter('KcKd3h3sAd', 'KcKd3h3sQd');
      expectTie('KcKd3h3sAd', 'KhKs3c3dAs');
    });

    test('one pair', () {
      expectBetter('3c3d4h5s6d', '2c2dAhKsQd');
      expectBetter('9c9dAhKs2d', '9c9dAhQsJd');
      expectBetter('9c9dAhKs3d', '9c9dAhKs2d');
    });

    test('high card compares all five cards', () {
      expectBetter('AcJd8h5s3d', 'KcQdJh9s7d');
      expectBetter('AcJd8h5s3d', 'AcJd8h5s2d');
      expectTie('AcJd8h5s3d', 'AdJh8s5c3h');
    });
  });

  group('evaluate with 6 or 7 cards', () {
    test('picks the best five cards', () {
      expect(eval('AhAd7c7s2h2dKc'), eval('AhAd7c7sKc'));
    });

    test('three pairs use the best remaining card as kicker', () {
      // The kicker is the third pair's rank when it beats the single card.
      expect(eval('AhAdKcKsQhQd2c').tiebreakers, ranks('AKQ'));
    });

    test('two sets make a full house with the higher set', () {
      final value = eval('9h9d9c5s5h5dAc');
      expect(value.category, HandCategory.fullHouse);
      expect(value.tiebreakers, ranks('95'));
    });

    test('trips plus two pairs use the higher pair', () {
      expect(eval('2h2d2cKsKh3d3c').tiebreakers, ranks('2K'));
    });

    test('quads use the best kicker even if it comes from a pair or trips', () {
      expect(eval('8h8d8c8sKhKd2c').tiebreakers, ranks('8K'));
      expect(eval('8h8d8c8s5h5d5c').tiebreakers, ranks('85'));
    });

    test('a flush beats a straight made from the same cards', () {
      final value = eval('9h8h7h6h2hTc5d');
      expect(value.category, HandCategory.flush);
      expect(value.tiebreakers, ranks('98762'));
    });

    test('six suited cards use the best five', () {
      expect(eval('AhKh9h7h4h2hAs').tiebreakers, ranks('AK974'));
    });

    test('a straight flush beats a higher straight', () {
      final value = eval('9s8s7s6s5sTd4c');
      expect(value.category, HandCategory.straightFlush);
      expect(value.tiebreakers, ranks('9'));
    });

    test('the highest straight is used with six connected cards', () {
      expect(eval('8c7d6h5s4c3d2h').tiebreakers, ranks('8'));
    });

    test('a wheel with a six makes a six-high straight', () {
      expect(eval('Ac2d3h4s5c6dKh').tiebreakers, ranks('6'));
    });

    test('works with 6 cards', () {
      expect(eval('AhAdAcKsKh2d').category, HandCategory.fullHouse);
    });
  });

  group('evaluate validation', () {
    test('rejects fewer than 5 or more than 7 cards', () {
      expect(() => eval('AhKhQhJh'), throwsArgumentError);
      expect(() => eval('AhKhQhJhTh9h8h7h'), throwsArgumentError);
    });

    test('rejects duplicate cards', () {
      expect(() => eval('AhAhQhJhTh'), throwsArgumentError);
    });
  });

  group('winners', () {
    List<int> winners(List<String> hands, String board) =>
        HandEvaluator.winners([for (final h in hands) cards(h)], cards(board));

    test('the best hand wins', () {
      expect(winners(['AhAd', 'KhKd'], '2c7s9dJc3h'), [0]);
      expect(winners(['AhAd', 'KhKd'], '2c7s9dKc3h'), [1]);
    });

    test('a kicker decides', () {
      expect(winners(['AhQd', 'AcJd'], 'As7s9d2c3h'), [0]);
    });

    test('the pot is split when the board plays', () {
      expect(winners(['2h3d', '4c5d'], 'AsKsQsJsTs'), [0, 1]);
    });

    test('the pot is split when the best five cards tie', () {
      // Both play A-A-K-Q-J; the second hole cards do not matter.
      expect(winners(['Ah2d', 'Ac3d'], 'AsKdQcJh7s'), [0, 1]);
    });

    test('only the tied best hands split the pot', () {
      expect(winners(['Ah2d', 'KcKh', 'Ac3d'], 'AsKdQcJh7s'), [1]);
      expect(winners(['Th2d', '8c8h', 'Tc3d'], 'AsKdQcJh7s'), [0, 2]);
    });

    test('works with many hands', () {
      expect(winners(['AhAd', 'KhKd', 'QhQd', 'JhJd', 'ThTd'], '2c3c4s8s9c'), [
        0,
      ]);
    });

    test('rejects invalid input', () {
      expect(() => winners([], 'AsKdQcJh7s'), throwsArgumentError);
      expect(() => winners(['AhAd'], 'AsKdQcJh'), throwsArgumentError);
      expect(() => winners(['Ah'], 'AsKdQcJh7s'), throwsArgumentError);
      expect(
        () => winners(['AhAd', 'AhKd'], '2c3c4s8s9c'),
        throwsArgumentError,
      );
      expect(() => winners(['AhAd'], 'Ad3c4s8s9c'), throwsArgumentError);
    });
  });

  test('all 2,598,960 five-card hands have the known category frequencies '
      'and 7,462 distinct values', () {
    final deck = [
      for (final s in Card.suits)
        for (final r in Card.ranks) Card(r, s),
    ];
    final counts = {for (final c in HandCategory.values) c: 0};
    final distinct = <HandValue>{};
    for (var a = 0; a < 52; a++) {
      for (var b = a + 1; b < 52; b++) {
        for (var c = b + 1; c < 52; c++) {
          for (var d = c + 1; d < 52; d++) {
            for (var e = d + 1; e < 52; e++) {
              final value = HandEvaluator.evaluateFive([
                deck[a],
                deck[b],
                deck[c],
                deck[d],
                deck[e],
              ]);
              counts[value.category] = counts[value.category]! + 1;
              distinct.add(value);
            }
          }
        }
      }
    }
    expect(counts, {
      HandCategory.straightFlush: 40,
      HandCategory.fourOfAKind: 624,
      HandCategory.fullHouse: 3744,
      HandCategory.flush: 5108,
      HandCategory.straight: 10200,
      HandCategory.threeOfAKind: 54912,
      HandCategory.twoPair: 123552,
      HandCategory.onePair: 1098240,
      HandCategory.highCard: 1302540,
    });
    expect(distinct.length, 7462);
  });
}
