import '../card.dart';
import '../hand.dart';

/// Range Format Specification:
///
/// Pairs:
/// - `22`: any pair of 22 (all 6 combos: 2s2h, 2s2c, 2s2d, 2h2c, 2h2d, 2c2d).
/// - `88+`: any pair of 88 and higher.
///
/// Offsuits:
/// - `AKo`: any Ace and King with different suits (all 12 offsuit combos).
/// - `Q8o+`: any offsuit combo keeping top card Q: Q8o, Q9o, QTo, QJo.
///
/// Suited:
/// - `AKs`: any suited combo of AK (AsKs, AhKh, AcKc, AdKd - 4 combos).
/// - `Q8s+`: suited hands with top card A and second card T or higher: ATs, AJs, AQs, AKs.
///
/// Full hand:
/// - `AsKh`: full hand.
///
/// Single card:
/// - `As`: any hand holding the Ace of spades (all 51 combos).
class RangeParser {
  static List<String> parseHandRange(String rangeStr) {
    final List<String> tokens = [];
    for (final collapsedToken in splitTokens(rangeStr)) {
      tokens.addAll(expandPlus(collapsedToken));
    }
    return tokens;
  }

  static List<Hand> rangeToHands(String rangeStr) {
    final List<Hand> hands = [];
    for (final hand in expandRange(rangeStr)) {
      hands.add(Hand(Card(hand[0], hand[1]), Card(hand[2], hand[3])));
    }
    final result = hands.toSet().toList();
    result.sort();
    return result;
  }

  static List<String> expandRange(String rangeStr) {
    final List<String> hands = [];
    for (final collapsedToken in splitTokens(rangeStr)) {
      for (final token in expandPlus(collapsedToken)) {
        final List<String> expandedHands = [];
        expandedHands.addAll(expandPairToken(token));
        expandedHands.addAll(expandOffsuitToken(token));
        expandedHands.addAll(expandSuitToken(token));
        expandedHands.addAll(expandCardToken(token));

        hands.addAll(expandedHands);
        if (expandedHands.isEmpty) {
          validateHandToken(token);
          hands.add(token);
        }
      }
    }
    return hands;
  }

  static List<String> expandPlus(String token) {
    final error = 'Invalid token $token';
    if (!token.endsWith('+')) {
      return [token];
    }
    final List<String> tokens = [];

    // Expand a pair
    if (token.length == 2 || token[0] == token[1]) {
      final index = Card.ranks.indexOf(token[0]);
      if (index < 0) {
        throw error;
      }

      for (var i = Card.ranks.length - 1; i >= index; i--) {
        tokens.add('${Card.ranks[i]}${Card.ranks[i]}');
      }
      return tokens;
    }

    if (token.length != 4 || (token[2] != 's' && token[2] != 'o')) {
      throw error;
    }

    final indexHigh = Card.ranks.indexOf(token[0]);
    if (indexHigh < 0) {
      throw error;
    }

    final indexLow = Card.ranks.indexOf(token[1]);
    if (indexLow < 0 || indexLow >= indexHigh) {
      throw error;
    }

    for (var i = indexHigh - 1; i >= indexLow; i--) {
      tokens.add('${token[0]}${Card.ranks[i]}${token[2]}');
    }

    return tokens;
  }

  static List<String> splitTokens(String rangeStr) {
    rangeStr = rangeStr.trim();
    if (rangeStr.isEmpty) {
      return [];
    }

    final List<String> tokens = [];
    for (var token in rangeStr.split(',')) {
      token = token.trim();
      if (token.isNotEmpty) {
        tokens.add(token.trim());
      }
    }

    return tokens;
  }

  static List<String> expandPairToken(String token) {
    final List<String> hands = [];
    if (token.length != 2 || token[0] != token[1]) {
      return hands;
    }
    if (!Card.ranks.contains(token[0])) {
      throw 'Invalid rank ${token[0]}';
    }

    for (var i = 0; i < Card.suits.length - 1; i++) {
      for (var j = i + 1; j < Card.suits.length; j++) {
        hands.add('${token[0]}${Card.suits[i]}${token[0]}${Card.suits[j]}');
      }
    }
    return hands;
  }

  static List<String> expandOffsuitToken(String token) {
    final List<String> hands = [];
    if (token.length != 3 || token[2] != 'o') {
      return hands;
    }
    if (!Card.ranks.contains(token[0]) || !Card.ranks.contains(token[1])) {
      throw 'Invalid rank $token';
    }
    if (token[0] == token[1]) {
      throw 'Invalid hand $token';
    }

    for (var i = 0; i < Card.suits.length; i++) {
      for (var j = 0; j < Card.suits.length; j++) {
        if (i != j) {
          hands.add('${token[0]}${Card.suits[i]}${token[1]}${Card.suits[j]}');
        }
      }
    }

    return hands;
  }

  static List<String> expandSuitToken(String token) {
    final List<String> hands = [];
    if (token.length != 3 || token[2] != 's') {
      return hands;
    }
    if (!Card.ranks.contains(token[0]) || !Card.ranks.contains(token[1])) {
      throw 'Invalid rank $token';
    }
    if (token[0] == token[1]) {
      throw 'Invalid hand $token';
    }

    for (var i = 0; i < Card.suits.length; i++) {
      hands.add('${token[0]}${Card.suits[i]}${token[1]}${Card.suits[i]}');
    }

    return hands;
  }

  /// Expands a single card (`As`) to every combo holding it, higher rank first.
  static List<String> expandCardToken(String token) {
    final List<String> hands = [];
    if (token.length != 2 || !Card.suits.contains(token[1])) {
      return hands;
    }
    if (!Card.ranks.contains(token[0])) {
      throw 'Invalid card $token';
    }

    for (final rank in Card.ranks.reversed) {
      for (final suit in Card.suits) {
        if (rank != token[0] || suit != token[1]) {
          hands.add(normalizeCombo('$token$rank$suit'));
        }
      }
    }
    return hands;
  }

  static void validateHandToken(String token) {
    final error = 'Invalid hand $token';
    if (token.length != 4) {
      throw error;
    }
    if (token[0] == token[2] && token[1] == token[3]) {
      throw error;
    }
    if (!Card.ranks.contains(token[0]) || !Card.ranks.contains(token[2])) {
      throw error;
    }
    if (!Card.suits.contains(token[1]) || !Card.suits.contains(token[3])) {
      throw error;
    }
  }

  /// Canonical combo form: higher rank first; pairs use suit order from [Card.suits].
  static String normalizeCombo(String combo) {
    validateHandToken(combo);
    final r1 = combo[0];
    final s1 = combo[1];
    final r2 = combo[2];
    final s2 = combo[3];
    final rank1 = Card.ranks.indexOf(r1);
    final rank2 = Card.ranks.indexOf(r2);
    if (rank1 < rank2) {
      return '$r2$s2$r1$s1';
    }
    if (rank1 == rank2 && Card.suits.indexOf(s1) > Card.suits.indexOf(s2)) {
      return '$r2$s2$r1$s1';
    }
    return combo;
  }

  static Set<String> expandRangeToComboSet(String rangeStr) {
    return expandRange(rangeStr).map(normalizeCombo).toSet();
  }

  /// Visual layout of exact combos for a 13x13 grid hand (`AA`, `AKs`, `AKo`).
  static List<List<String>> comboLayoutForHand(String hand) {
    if (hand.length == 2) {
      final r = hand[0];
      return [
        ['${r}s${r}h', '${r}s${r}c', '${r}s${r}d'],
        ['${r}h${r}c', '${r}h${r}d', '${r}c${r}d'],
      ];
    } else if (hand.endsWith('s')) {
      final r1 = hand[0];
      final r2 = hand[1];
      return [
        ['${r1}s${r2}s', '${r1}h${r2}h', '${r1}c${r2}c', '${r1}d${r2}d'],
      ];
    } else {
      final r1 = hand[0];
      final r2 = hand[1];
      return [
        ['${r1}s${r2}h', '${r1}s${r2}c', '${r1}s${r2}d'],
        ['${r1}h${r2}s', '${r1}h${r2}c', '${r1}h${r2}d'],
        ['${r1}c${r2}s', '${r1}c${r2}h', '${r1}c${r2}d'],
        ['${r1}d${r2}s', '${r1}d${r2}h', '${r1}d${r2}c'],
      ];
    }
  }

  /// Converts selected combos back to a compact range string (`QQ+`, `AJs+`, `AsKh`).
  static String rangeFromCombos(Iterable<String> comboIterable) {
    final combos = <String>{};
    for (final combo in comboIterable) {
      combos.add(normalizeCombo(combo));
    }

    final ranksHighToLow = Card.ranks.reversed.toList();
    final tokens = <String>[];

    _flushFullySelectedRun(
      tokens: tokens,
      ranksHighToLow: ranksHighToLow,
      combos: combos,
      isPair: true,
      highIndex: 0,
      suited: false,
    );

    for (var hi = 0; hi < ranksHighToLow.length; hi++) {
      _flushFullySelectedRun(
        tokens: tokens,
        ranksHighToLow: ranksHighToLow,
        combos: combos,
        isPair: false,
        highIndex: hi,
        suited: true,
      );
      _flushFullySelectedRun(
        tokens: tokens,
        ranksHighToLow: ranksHighToLow,
        combos: combos,
        isPair: false,
        highIndex: hi,
        suited: false,
      );
    }

    return tokens.join(', ');
  }

  static void _flushFullySelectedRun({
    required List<String> tokens,
    required List<String> ranksHighToLow,
    required Set<String> combos,
    required bool isPair,
    required int highIndex,
    required bool suited,
  }) {
    int? runStart;

    void flush(int endExclusive) {
      final startIndex = runStart;
      if (startIndex == null) {
        return;
      }
      if (isPair) {
        if (startIndex == 0 && endExclusive - 1 != 0) {
          final low = ranksHighToLow[endExclusive - 1];
          tokens.add('$low$low+');
        } else {
          for (var i = startIndex; i < endExclusive; i++) {
            final rank = ranksHighToLow[i];
            tokens.add('$rank$rank');
          }
        }
      } else {
        final high = ranksHighToLow[highIndex];
        final suffix = suited ? 's' : 'o';
        if (startIndex == highIndex + 1 && endExclusive - 1 != startIndex) {
          final low = ranksHighToLow[endExclusive - 1];
          tokens.add('$high$low$suffix+');
        } else {
          for (var i = startIndex; i < endExclusive; i++) {
            tokens.add('$high${ranksHighToLow[i]}$suffix');
          }
        }
      }
      runStart = null;
    }

    final start = isPair ? 0 : highIndex + 1;
    for (var i = start; i < ranksHighToLow.length; i++) {
      final token = isPair
          ? '${ranksHighToLow[i]}${ranksHighToLow[i]}'
          : '${ranksHighToLow[highIndex]}${ranksHighToLow[i]}${suited ? 's' : 'o'}';
      final handCombos = isPair
          ? expandPairToken(token)
          : (suited ? expandSuitToken(token) : expandOffsuitToken(token));
      var selectedCount = 0;
      for (final combo in handCombos) {
        if (combos.contains(combo)) {
          selectedCount++;
        }
      }

      if (selectedCount == handCombos.length) {
        runStart ??= i;
      } else {
        flush(i);
        if (selectedCount > 0) {
          for (final combo in handCombos) {
            if (combos.contains(combo)) {
              tokens.add(combo);
            }
          }
        }
      }
    }
    flush(ranksHighToLow.length);
  }
}
