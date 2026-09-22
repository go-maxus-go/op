class RangeParser {
  static const List<String> ranks = [
    '2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A'
  ];

  static int rankIndex(String r) => ranks.indexOf(r);

  static List<String> parseHandRange(String rangeStr) {
    rangeStr = rangeStr.trim();
    if (rangeStr.isEmpty) return [];

    if (rangeStr.endsWith('+')) {
      return _parsePlus(rangeStr.substring(0, rangeStr.length - 1));
    } else {
      return [_parseSingle(rangeStr)];
    }
  }

  static String _parseSingle(String hand) {
    return hand; // Just returns "54s", "88", "AKo"
  }

  static List<String> _parsePlus(String baseHand) {
    if (baseHand.length == 2) {
      // e.g., "88"
      int rIdx = rankIndex(baseHand[0]);
      List<String> res = [];
      for (int i = rIdx; i < ranks.length; i++) {
        res.add('${ranks[i]}${ranks[i]}');
      }
      return res;
    } else if (baseHand.length == 3) {
      String r1 = baseHand[0];
      String r2 = baseHand[1];
      String suit = baseHand[2];
      int i1 = rankIndex(r1);
      int i2 = rankIndex(r2);

      List<String> res = [];
      if (i1 == i2 + 1) {
        // e.g., "87s" -> consecutive. increment both
        int curr1 = i1;
        int curr2 = i2;
        while (curr1 < ranks.length) {
          res.add('${ranks[curr1]}${ranks[curr2]}$suit');
          curr1++;
          curr2++;
        }
      } else {
        // e.g., "A9s" -> increment only the second card until it hits r1 - 1
        int curr2 = i2;
        while (curr2 < i1) {
          res.add('$r1${ranks[curr2]}$suit');
          curr2++;
        }
      }
      return res;
    }
    return ['$baseHand+'];
  }

  static List<String> parseLine(String line) {
    List<String> result = [];
    final parts = line.split(',');
    for (var p in parts) {
      result.addAll(parseHandRange(p));
    }
    return result;
  }
}
