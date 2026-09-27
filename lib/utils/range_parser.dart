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

    for (var i = 0; i < Card.suits.length; i++) {
      hands.add('${token[0]}${Card.suits[i]}${token[1]}${Card.suits[i]}');
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
}
