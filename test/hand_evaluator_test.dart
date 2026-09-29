import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/card.dart';
import 'package:optimal_poker/hand.dart';
import 'package:optimal_poker/hand_evaluator.dart';

/// Parses concatenated cards, e.g. 'AhKd2c'.
List<Card> cards(String s) => [
  for (var i = 0; i < s.length; i += 2) Card(s[i], s[i + 1]),
];

HandValue five(String s) => HandEvaluator.evaluateFiveCards(cards(s));

void main() {
  group('HandValue', () {
    test('stronger categories beat weaker ones', () {
      const weakestToStrongest = HandCategory.values;
      for (var i = 0; i < weakestToStrongest.length; i++) {
        for (var j = i + 1; j < weakestToStrongest.length; j++) {
          final weaker = HandValue(weakestToStrongest[i], ['A']);
          final stronger = HandValue(weakestToStrongest[j], ['2']);
          expect(stronger, greaterThan(weaker));
          expect(weaker, lessThan(stronger));
          expect(stronger.compareTo(weaker), 1);
          expect(weaker.compareTo(stronger), -1);
        }
      }
    });

    test('identical hands compare equal and share a hash code', () {
      const a = HandValue(HandCategory.straight, ['T']);
      const b = HandValue(HandCategory.straight, ['T']);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a.compareTo(b), 0);
      expect(a, isNot(greaterThan(b)));
      expect(a, isNot(lessThan(b)));
    });

    test('quad aces beat quad kings', () {
      final aces = HandValue(HandCategory.fourOfAKind, ['A', 'K']);
      final kings = HandValue(HandCategory.fourOfAKind, ['K', 'A']);
      expect(aces, greaterThan(kings));
    });

    test('quad kicker breaks a tie when the quad rank matches', () {
      final kingKicker = HandValue(HandCategory.fourOfAKind, ['A', 'K']);
      final queenKicker = HandValue(HandCategory.fourOfAKind, ['A', 'Q']);
      expect(kingKicker, greaterThan(queenKicker));
    });

    test('aces full of deuces beat deuces full of aces', () {
      final acesFull = HandValue(HandCategory.fullHouse, ['A', '2']);
      final deucesFull = HandValue(HandCategory.fullHouse, ['2', 'A']);
      expect(acesFull, greaterThan(deucesFull));
      expect(acesFull, isNot(equals(deucesFull)));
    });

    test('aces full of kings beat aces full of queens', () {
      final kings = HandValue(HandCategory.fullHouse, ['A', 'K']);
      final queens = HandValue(HandCategory.fullHouse, ['A', 'Q']);
      expect(kings, greaterThan(queens));
    });

    test('aces and kings beat kings and queens', () {
      final acesUp = HandValue(HandCategory.twoPair, ['A', 'K', '2']);
      final kingsUp = HandValue(HandCategory.twoPair, ['K', 'Q', 'A']);
      expect(acesUp, greaterThan(kingsUp));
    });

    test('two pair kicker is ranked after both pairs', () {
      final king = HandValue(HandCategory.twoPair, ['A', '2', 'K']);
      final queen = HandValue(HandCategory.twoPair, ['A', '2', 'Q']);
      expect(king, greaterThan(queen));
    });

    test('set of threes beats a set of deuces with taller kickers', () {
      final threes = HandValue(HandCategory.threeOfAKind, ['3', '5', '4']);
      final deuces = HandValue(HandCategory.threeOfAKind, ['2', 'A', 'K']);
      expect(threes, greaterThan(deuces));
    });

    test('pair of threes beats a pair of deuces with taller kickers', () {
      final threes = HandValue(HandCategory.onePair, ['3', '7', '5', '4']);
      final deuces = HandValue(HandCategory.onePair, ['2', 'A', 'K', 'Q']);
      expect(threes, greaterThan(deuces));
    });

    test('pair kicker order is most significant first', () {
      final king = HandValue(HandCategory.onePair, ['A', 'K', '5', '4']);
      final queen = HandValue(HandCategory.onePair, ['A', 'Q', 'J', 'T']);
      expect(king, greaterThan(queen));
    });

    test('flush kickers compare from the top', () {
      final kingHigh = HandValue(HandCategory.flush, ['A', 'K', '9', '5', '2']);
      final queenHigh = HandValue(HandCategory.flush, [
        'A',
        'Q',
        'J',
        'T',
        '9',
      ]);
      expect(kingHigh, greaterThan(queenHigh));
    });

    test('broadway beats a wheel', () {
      final broadway = HandValue(HandCategory.straight, ['A']);
      final wheel = HandValue(HandCategory.straight, ['5']);
      expect(broadway, greaterThan(wheel));
    });

    test('aces and fours beat aces and treys with a king kicker', () {
      final fours = HandValue(HandCategory.twoPair, ['A', '4', '3']);
      final treys = HandValue(HandCategory.twoPair, ['A', '3', 'K']);
      expect(fours, greaterThan(treys));
    });

    test('the second trips kicker breaks a tie', () {
      final five = HandValue(HandCategory.threeOfAKind, ['A', 'K', '5']);
      final four = HandValue(HandCategory.threeOfAKind, ['A', 'K', '4']);
      expect(five, greaterThan(four));
    });

    test('the last pair kicker breaks a tie', () {
      final five = HandValue(HandCategory.onePair, ['A', 'K', 'Q', '5']);
      final four = HandValue(HandCategory.onePair, ['A', 'K', 'Q', '4']);
      expect(five, greaterThan(four));
    });

    test('the last flush card breaks a tie', () {
      final nine = HandValue(HandCategory.flush, ['A', 'K', 'Q', 'J', '9']);
      final eight = HandValue(HandCategory.flush, ['A', 'K', 'Q', 'J', '8']);
      expect(nine, greaterThan(eight));
    });

    test('different tiebreaker lists are not equal', () {
      const shorter = HandValue(HandCategory.onePair, ['A', 'K', 'Q']);
      const longer = HandValue(HandCategory.onePair, ['A', 'K', 'Q', 'J']);
      expect(shorter == longer, isFalse);
      expect(shorter.hashCode, isNot(longer.hashCode));
    });

    test(
      'compareTo is antisymmetric when tiebreaker lists differ in length',
      () {
        const shorter = HandValue(HandCategory.onePair, ['A', 'K', 'Q']);
        const longer = HandValue(HandCategory.onePair, ['A', 'K', 'Q', 'J']);
        expect(longer.compareTo(shorter), -shorter.compareTo(longer));
      },
    );

    test('toString names the category and tiebreakers', () {
      expect(
        const HandValue(HandCategory.fullHouse, ['A', 'K']).toString(),
        'fullHouse(AK)',
      );
    });
  });

  group('evaluateFiveCards categories', () {
    test('royal flush', () {
      final value = five('AsKsQsJsTs');
      expect(value.category, HandCategory.straightFlush);
      expect(value.tiebreakers, ['A']);
    });

    test('steel wheel is a five-high straight flush', () {
      final value = five('Ah2h3h4h5h');
      expect(value.category, HandCategory.straightFlush);
      expect(value.tiebreakers, ['5']);
    });

    test('six-high straight flush beats the steel wheel', () {
      expect(five('6s5s4s3s2s'), greaterThan(five('As5s4s3s2s')));
    });

    test('straight flush beats quads', () {
      expect(five('6s5s4s3s2s'), greaterThan(five('AsAhAdAcKs')));
    });

    test('quads with kicker', () {
      final value = five('AsAhAdAcKs');
      expect(value.category, HandCategory.fourOfAKind);
      expect(value.tiebreakers, ['A', 'K']);
    });

    test('quad aces beat quad kings at showdown', () {
      expect(five('AsAhAdAc2s'), greaterThan(five('KsKhKdKcAs')));
    });

    test('full house trips rank then pair rank', () {
      final value = five('KsKhKdAcAs');
      expect(value.category, HandCategory.fullHouse);
      expect(value.tiebreakers, ['K', 'A']);
      expect(five('AsAhAdKcKs'), greaterThan(value));
    });

    test('full house beats a flush', () {
      expect(five('AsAhAdKcKs'), greaterThan(five('AsQs9s6s2s')));
    });

    test('flush keeps kickers in descending rank', () {
      final value = five('AsQs9s6s2s');
      expect(value.category, HandCategory.flush);
      expect(value.tiebreakers, ['A', 'Q', '9', '6', '2']);
    });

    test('ace-king-queen-jack-nine of hearts is a flush', () {
      final value = five('AhKhQhJh9h');
      expect(value.category, HandCategory.flush);
      expect(value.tiebreakers, ['A', 'K', 'Q', 'J', '9']);
    });

    test('that flush loses to quad deuces', () {
      expect(five('2s2h2d2c3s'), greaterThan(five('AhKhQhJh9h')));
    });

    test('ace-king-queen-jack-nine offsuit is high card', () {
      expect(five('AhKhQhJh9d').category, HandCategory.highCard);
    });

    test('a wheel beats ace high', () {
      expect(five('Ah5c4d3s2h'), greaterThan(five('AsKd8c4h2s')));
    });

    test('a steel wheel beats quad aces', () {
      expect(five('As5s4s3s2s'), greaterThan(five('AhAdAcAsKh')));
    });

    test('broadway straight', () {
      final value = five('AsKdQcJhTs');
      expect(value.category, HandCategory.straight);
      expect(value.tiebreakers, ['A']);
    });

    test('six-high straight beats a wheel', () {
      expect(five('6s5h4d3c2s'), greaterThan(five('Ah5c4d3s2h')));
    });

    test('wheel is five-high, not ace-high', () {
      final value = five('Ah5c4d3s2h');
      expect(value.category, HandCategory.straight);
      expect(value.tiebreakers, ['5']);
    });

    test('ace through nine is not a straight', () {
      final value = five('AsKdQcJh9s');
      expect(value.category, HandCategory.highCard);
      expect(value.tiebreakers, ['A', 'K', 'Q', 'J', '9']);
    });

    test('eight through three with a gap is not a straight', () {
      expect(five('8s7h6d5c3h').category, HandCategory.highCard);
    });

    test('ace-high with a gap under the ace is not a straight', () {
      expect(five('As9h8d7c6s').category, HandCategory.highCard);
    });

    test('a wrapped wheel is not a straight', () {
      expect(five('As6h5d4c3s').category, HandCategory.highCard);
    });

    test('nine-eight-seven-six with a paired six is a pair', () {
      final value = five('9s8h7d6c6s');
      expect(value.category, HandCategory.onePair);
      expect(value.tiebreakers, ['6', '9', '8', '7']);
    });

    test('a pair of deuces beats ace-king-queen-jack-nine', () {
      expect(five('2s2h7d5c4h'), greaterThan(five('AsKdQcJh9s')));
    });

    test('ten-high straight', () {
      final value = five('Ts9h8d7c6s');
      expect(value.category, HandCategory.straight);
      expect(value.tiebreakers, ['T']);
    });

    test('king-high straight beats queen-high', () {
      expect(five('KsQhJdTc9s'), greaterThan(five('QsJhTd9c8s')));
    });

    test('quads beat a full house', () {
      expect(five('AsAhAdAcKs'), greaterThan(five('KsKhKdQcQh')));
    });

    test('a flush beats a straight', () {
      expect(five('AsKs9s6s2s'), greaterThan(five('AsKdQcJhTs')));
    });

    test('aces and fours beat aces and treys at showdown', () {
      expect(five('AsAh4s4h3d'), greaterThan(five('AsAh3s3hKd')));
    });

    test('trip kickers compare after the set', () {
      expect(five('AsAhAdKc2s'), greaterThan(five('AsAhAdQcJs')));
      expect(five('AsAhAdKc5s'), greaterThan(five('AsAhAdKc4s')));
    });

    test('the last pair kicker decides the showdown', () {
      expect(five('AsAhKdQc5s'), greaterThan(five('AsAhKdQc4s')));
    });

    test('straight beats trips', () {
      expect(five('9s8h7d6c5s'), greaterThan(five('AsAhAdKcQs')));
    });

    test('trips rank then kickers', () {
      final value = five('QsQhQdAcKs');
      expect(value.category, HandCategory.threeOfAKind);
      expect(value.tiebreakers, ['Q', 'A', 'K']);
    });

    test('set of aces beats a set of kings', () {
      expect(five('AsAhAd3c2s'), greaterThan(five('KsKhKdAcQs')));
    });

    test('trips beat two pair', () {
      expect(five('2s2h2dAcKs'), greaterThan(five('AsAhKsKhQd')));
    });

    test('two pair ranks the pairs then the kicker', () {
      final value = five('KsKh2s2hAc');
      expect(value.category, HandCategory.twoPair);
      expect(value.tiebreakers, ['K', '2', 'A']);
    });

    test('aces and kings beat kings and queens at showdown', () {
      expect(five('AsAhKsKh2d'), greaterThan(five('KsKhQsQhAc')));
    });

    test('two pair beats one pair', () {
      final twoPair = five('2s2h3c3d4h');
      final pair = five('AsAhKdQcJs');
      expect(pair.category, HandCategory.onePair);
      expect(twoPair, greaterThan(pair));
    });

    test('one pair ranks the pair then the kickers', () {
      final value = five('AsAhKdQcJs');
      expect(value.category, HandCategory.onePair);
      expect(value.tiebreakers, ['A', 'K', 'Q', 'J']);
    });

    test('pair of aces beats pair of kings', () {
      expect(five('AsAh5d4c3s'), greaterThan(five('KsKhAdQcJs')));
    });

    test('one pair beats ace high', () {
      expect(five('2s2h7d5c4h'), greaterThan(five('AsKd9c6h3s')));
    });

    test('ace high beats the worst high card', () {
      final aceHigh = five('As6d4c3h2s');
      final sevenHigh = five('7s5h4d3c2h');
      expect(aceHigh.category, HandCategory.highCard);
      expect(sevenHigh.category, HandCategory.highCard);
      expect(aceHigh.tiebreakers, ['A', '6', '4', '3', '2']);
      expect(sevenHigh.tiebreakers, ['7', '5', '4', '3', '2']);
      expect(aceHigh, greaterThan(sevenHigh));
    });

    test('card order does not change the value', () {
      expect(five('2h3h4h5hAh'), equals(five('Ah5h4h3h2h')));
      expect(five('KcKdKhAsAc'), equals(five('AsAcKcKdKh')));
    });

    test('does not mutate the caller list', () {
      final hand = cards('2cAsKdQhJs');
      final original = [...hand];
      HandEvaluator.evaluateFiveCards(hand);
      expect(hand, original);
    });

    test('two pair aces and kings beat a pair of aces', () {
      final pair = five('AsAhKdQcJs');
      final twoPair = five('AsAdKsKhQd');
      expect(twoPair, greaterThan(pair));
    });

    test('that comparison does not throw in either direction', () {
      final pair = five('AsAhKdQcJs');
      final twoPair = five('AsAdKsKhQd');
      expect(() => pair.compareTo(twoPair), returnsNormally);
      expect(() => twoPair.compareTo(pair), returnsNormally);
    });
  });

  group('evaluateFiveCards validation', () {
    test('rejects a hand that is not five cards', () {
      expect(() => five('AsKsQsJs'), throwsArgumentError);
      expect(() => five('AsKsQsJsTs9s'), throwsArgumentError);
      expect(
        () => HandEvaluator.evaluateFiveCards(const []),
        throwsArgumentError,
      );
    });

    test('rejects duplicate cards', () {
      expect(() => five('AsAhAdAcAs'), throwsArgumentError);
      expect(() => five('AhAhKdQcJs'), throwsArgumentError);
    });
  });

  group('evaluate', () {
    HandValue showdown(String hole, String board) =>
        HandEvaluator.evaluate(Hand.fromString(hole), cards(board));

    test('flop uses both hole cards and the three board cards', () {
      final value = showdown('AsKs', 'QsJsTs');
      expect(value.category, HandCategory.straightFlush);
      expect(value.tiebreakers, ['A']);
    });

    test('turn can use the higher hole card and every board card', () {
      final value = showdown('Ah2c', 'KhQhJh9h');
      expect(value.category, HandCategory.flush);
      expect(value.tiebreakers, ['A', 'K', 'Q', 'J', '9']);
    });

    test('turn keeps both hole cards and drops one board card', () {
      final value = showdown('Ah5h', 'KhQhJh2c');
      expect(value.category, HandCategory.flush);
      expect(value.tiebreakers, ['A', 'K', 'Q', 'J', '5']);
    });

    test('turn can play only the lower hole card', () {
      final value = showdown('As9h', 'KhQhJh8h');
      expect(value.category, HandCategory.flush);
      expect(value.tiebreakers, ['K', 'Q', 'J', '9', '8']);
    });

    test('turn plays the later suit of a pocket pair', () {
      final value = showdown('AdAs', '2d3d4d5d');
      expect(value.category, HandCategory.straightFlush);
      expect(value.tiebreakers, ['5']);
    });

    test('river royal flush using both hole cards', () {
      final value = showdown('AsKs', 'QsJsTs2c3d');
      expect(value.category, HandCategory.straightFlush);
      expect(value.tiebreakers, ['A']);
    });

    test('river quads can leave a hole card out', () {
      final value = showdown('As2c', 'AhAdAcKdQh');
      expect(value.category, HandCategory.fourOfAKind);
      expect(value.tiebreakers, ['A', 'K']);
    });

    test('river can play only the lower hole card', () {
      final value = showdown('As9h', 'KhQhJh8h2d');
      expect(value.category, HandCategory.flush);
      expect(value.tiebreakers, ['K', 'Q', 'J', '9', '8']);
    });

    test('river full house can require the lower hole card', () {
      final value = showdown('AsKd', 'KcKh2d2c2h');
      expect(value.category, HandCategory.fullHouse);
      expect(value.tiebreakers, ['K', '2']);
    });

    test('player can play the board', () {
      final value = showdown('2c3d', 'AsKsQsJsTs');
      expect(value.category, HandCategory.straightFlush);
      expect(value.tiebreakers, ['A']);
    });

    test('picks a full house out of seven cards', () {
      final value = showdown('AsAh', 'AdKdKcQsJs');
      expect(value.category, HandCategory.fullHouse);
      expect(value.tiebreakers, ['A', 'K']);
    });

    test('two hands that both play the board tie', () {
      final board = cards('KsQhJdTc9s');
      final a = HandEvaluator.evaluate(Hand.fromString('2c3d'), board);
      final b = HandEvaluator.evaluate(Hand.fromString('7h4s'), board);
      expect(a.category, HandCategory.straight);
      expect(a, equals(b));
    });

    test('matches five-card evaluation on the flop', () {
      final hole = Hand.fromString('9h8h');
      final board = cards('7h6h5d');
      expect(
        HandEvaluator.evaluate(hole, board),
        HandEvaluator.evaluateFiveCards([hole.first, hole.second, ...board]),
      );
    });

    test('rejects a board that shares a card with the hole cards', () {
      expect(
        () => showdown('AsKd', 'AsQhJc'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('Duplicate'),
          ),
        ),
      );
      expect(
        () => showdown('AsKd', 'As2c3d4h5s'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('Duplicate'),
          ),
        ),
      );
    });

    test('rejects duplicate board cards', () {
      expect(
        () => showdown('AsKd', 'QhQhJc'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('Duplicate'),
          ),
        ),
      );
      expect(
        () => showdown('AsKd', 'AsQhJcTd'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('Duplicate'),
          ),
        ),
      );
      expect(
        () => showdown('AsKd', 'QhQhJcTd9s'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('Duplicate'),
          ),
        ),
      );
    });

    test('flop of seven-five-four-three-two is that high card', () {
      final value = showdown('7s5h', '4d3c2s');
      expect(value.category, HandCategory.highCard);
      expect(value.tiebreakers, ['7', '5', '4', '3', '2']);
    });

    test('does not mutate the board', () {
      final board = cards('KsQhJdTc9s');
      final original = [...board];
      HandEvaluator.evaluate(Hand.fromString('2c3d'), board);
      expect(board, original);
    });

    test('rejects totals other than 5, 6, or 7 cards', () {
      expect(() => showdown('AsKd', ''), throwsArgumentError);
      expect(() => showdown('AsKd', 'Qh'), throwsArgumentError);
      expect(() => showdown('AsKd', 'QhJc'), throwsArgumentError);
      expect(() => showdown('AsKd', 'QhJcTd9s8h2c'), throwsArgumentError);
    });
  });
}
