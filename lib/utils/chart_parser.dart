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

  /// Amount of the bet this chart calls, such as `11` from `Call 11bb`.
  String? get callAmount {
    final size = RegExp(r'call\s+(\d+(?:\.\d+)?)\s*bb', caseSensitive: false);
    for (final action in uniqueActions) {
      final match = size.firstMatch(action);
      if (match != null) return match.group(1);
    }
    return null;
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
  static String _chartKey(String chart) =>
      chart.toLowerCase().replaceAll(' ', '_');

  /// True for the vs open-raise chart (`vs OPR`).
  ///
  /// The file is stored per hero, and each villain who opened is a position key.
  static bool isVsOpr(String chart) => _chartKey(chart) == 'vs_opr';

  /// True for the vs 3-bet chart (`vs 3bet`).
  ///
  /// The file is stored per hero, and each villain who 3-bet is a position key.
  static bool isVs3bet(String chart) => _chartKey(chart) == 'vs_3bet';

  /// Charts stored as one file per hero, with villains as the position keys.
  static bool isPerHero(String chart) => isVsOpr(chart) || isVs3bet(chart);

  /// Asset path of a chart, e.g. `assets/6max/100bb/OPR/nl100_3bb.yaml`,
  /// `assets/6max/100bb/vs_OPR/BTN/nl100_3bb.yaml` for hero BTN facing an open,
  /// or `assets/6max/100bb/vs_3bet/BTN/nl100_3bb.yaml` facing a 3-bet.
  ///
  /// [hero] selects the file for a vs OPR or vs 3bet chart.
  static String assetPath({
    required String type,
    required String stacks,
    required String limit,
    required String raise,
    required String chart,
    String? hero,
  }) {
    final String chartDir;
    if (isVsOpr(chart)) {
      chartDir = 'vs_OPR/${hero!.toUpperCase()}';
    } else if (isVs3bet(chart)) {
      chartDir = 'vs_3bet/${hero!.toUpperCase()}';
    } else {
      chartDir = chart;
    }
    return 'assets/${type.toLowerCase()}/${stacks}bb/$chartDir/'
        '${limit.toLowerCase()}_${raise.toLowerCase()}.yaml';
  }

  /// Parses the actions of [position]. When ranges of several actions
  /// overlap, a combo gets the first declared action.
  static PositionChart parse(dynamic yamlDoc, String position) {
    final comboActions = <String, String>{};
    final uniqueActions = <String>{PositionChart.foldLabel};
    final claimedCombos = <String>{};

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
            claimedCombos,
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
    Set<String> claimedCombos,
  ) {
    uniqueActions.add(actionName);
    final isFold = actionName.toLowerCase().contains('fold');
    for (final combo in RangeParser.expandRangeToComboSet(rangeStr)) {
      if (claimedCombos.add(combo) && !isFold) {
        comboActions[combo] = actionName;
      }
    }
  }
}
