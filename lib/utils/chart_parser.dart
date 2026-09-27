import 'package:yaml/yaml.dart';

import '../card.dart';
import 'range_parser.dart';

class PositionChart {
  static const foldLabel = 'Fold';

  /// Normalized 4-character combo (`AsKh`) to a non-fold action.
  final Map<String, String> comboActions;
  final Set<String> uniqueActions;

  const PositionChart({
    required this.comboActions,
    required this.uniqueActions,
  });

  String actionForCombo(String combo) {
    return comboActions[RangeParser.normalizeCombo(combo)] ?? foldLabel;
  }

  String actionForCards(Card first, Card second) {
    return actionForCombo(
      '${first.value}${first.suit}${second.value}${second.suit}',
    );
  }

  Map<String, int> actionCountsForHand(String gridHand) {
    final counts = <String, int>{};
    for (final combo in RangeParser.expandRange(gridHand)) {
      final action = actionForCombo(combo);
      counts[action] = (counts[action] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> actionWeightsForHand(String gridHand) {
    final counts = actionCountsForHand(gridHand);
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) {
      return {};
    }
    return counts.map(
      (action, count) => MapEntry(action, ((count / total) * 100).round()),
    );
  }

  Map<String, double> actionFrequencies() {
    const totalCombos = 1326;
    final counts = <String, double>{};
    for (final action in comboActions.values) {
      counts[action] = (counts[action] ?? 0) + 1;
    }
    final assigned = comboActions.length;
    counts[foldLabel] = (counts[foldLabel] ?? 0) + (totalCombos - assigned);
    return counts.map(
      (action, count) => MapEntry(action, (count / totalCombos) * 100),
    );
  }
}

class ChartParser {
  static PositionChart parse(dynamic yamlDoc, String position) {
    final comboActions = <String, String>{};
    final uniqueActions = <String>{PositionChart.foldLabel};

    if (yamlDoc is YamlMap && yamlDoc.containsKey(position)) {
      final handsList = yamlDoc[position];
      if (handsList is YamlList) {
        for (final item in handsList) {
          if (item is! YamlMap || item.isEmpty) {
            continue;
          }
          final actionName = item.keys.first.toString();
          final value = item[item.keys.first];
          if (value is YamlList) {
            continue;
          }
          _parseRangeAction(
            actionName,
            value.toString(),
            comboActions,
            uniqueActions,
          );
        }
      }
    }

    return PositionChart(
      comboActions: comboActions,
      uniqueActions: uniqueActions,
    );
  }

  static void _parseRangeAction(
    String actionName,
    String rangeStr,
    Map<String, String> comboActions,
    Set<String> uniqueActions,
  ) {
    uniqueActions.add(actionName);
    if (actionName.toLowerCase().contains('fold')) {
      return;
    }
    for (final combo in RangeParser.expandRangeToComboSet(rangeStr)) {
      comboActions[combo] = actionName;
    }
  }
}
