import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'utils/range_parser.dart';
import 'theme.dart';

class ChartScreen extends StatefulWidget {
  final String type;
  final String limit;
  final String stacks;
  final String raise;
  final String position;
  final String chart;

  const ChartScreen({
    super.key,
    required this.type,
    required this.limit,
    required this.stacks,
    required this.raise,
    required this.position,
    required this.chart,
  });

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  // Map of hand string (e.g., "AKs") to map of action and its weight (0-100)
  Map<String, Map<String, int>> _handActionWeights = {};
  Set<String> _uniqueActions = {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  Future<void> _loadChart() async {
    final fileName = '${widget.type.toLowerCase()}_${widget.stacks}_${widget.limit.toLowerCase()}_${widget.raise.toLowerCase()}_${widget.chart.toLowerCase()}.yaml';
    try {
      final yamlString = await rootBundle.loadString('assets/charts/$fileName');
      final yamlDoc = loadYaml(yamlString);

      Map<String, Map<String, int>> newWeights = {};
      Set<String> newUniqueActions = {};

      if (yamlDoc is YamlMap && yamlDoc.containsKey(widget.position)) {
        final handsList = yamlDoc[widget.position];
        if (handsList is YamlList) {
          for (var item in handsList) {
            if (item is YamlMap) {
              final handString = item.keys.first.toString();
              final actions = item[handString];

              Map<String, int> currentHandWeights = {};

              if (actions is YamlList) {
                for (var actionItem in actions) {
                  if (actionItem is YamlMap) {
                    final actionName = actionItem.keys.first.toString();
                    newUniqueActions.add(actionName);
                    final weight =
                        int.tryParse(actionItem[actionName].toString()) ?? 0;
                    if (weight > 0) {
                      currentHandWeights[actionName] = weight;
                    }
                  }
                }
              }

              final parsedHands = RangeParser.parseHandRange(handString);
              for (var hand in parsedHands) {
                if (!newWeights.containsKey(hand)) {
                  newWeights[hand] = {};
                }
                currentHandWeights.forEach((action, weight) {
                  newWeights[hand]![action] =
                      (newWeights[hand]![action] ?? 0) + weight;
                });
              }
            }
          }
        }
      }

      setState(() {
        _handActionWeights = newWeights;
        _uniqueActions = newUniqueActions;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      debugPrint('Error loading chart: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String _getHandAt(int row, int col) {
    final r1Index = 12 - row;
    final r2Index = 12 - col;

    final r1 = RangeParser.ranks[r1Index];
    final r2 = RangeParser.ranks[r2Index];

    if (row == col) {
      return '$r1$r2';
    } else if (col > row) {
      return '$r1${r2}s';
    } else {
      return '$r2${r1}o';
    }
  }

  Color _getColorForAction(String actionName, ChartColors colors) {
    final lowerAction = actionName.toLowerCase();
    if (lowerAction.contains('fold')) return colors.foldColor;
    if (lowerAction.contains('call')) return colors.callColor;
    if (lowerAction.contains('raise')) return colors.raiseColor;
    if (lowerAction.contains('all-in') || lowerAction.contains('shove')) {
      return colors.allInColor;
    }
    return colors.defaultColor;
  }

  Widget _buildCellBackground(
    Map<String, int> actionWeights,
    ChartColors colors,
  ) {
    List<Widget> bars = [];
    int totalWeight = 0;

    // Sort actions or just process non-folds first
    actionWeights.forEach((action, weight) {
      if (action.toLowerCase().contains('fold') || weight <= 0) return;

      totalWeight += weight;
      bars.add(
        Expanded(
          flex: weight,
          child: Container(color: _getColorForAction(action, colors)),
        ),
      );
    });

    // Fill remainder with Fold color (background)
    int remaining = 100 - totalWeight;
    if (remaining > 0) {
      bars.add(
        Expanded(
          flex: remaining,
          child: Container(color: colors.foldColor),
        ),
      );
    }

    if (bars.isEmpty) {
      return Container(color: colors.foldColor);
    }

    return Row(children: bars);
  }

  Map<String, double> _calculateActionFrequencies() {
    if (_handActionWeights.isEmpty) return {};

    Map<String, double> actionCombos = {};
    int totalCombos = 1326;

    for (int row = 0; row < 13; row++) {
      for (int col = 0; col < 13; col++) {
        int combos = 0;
        if (row == col) {
          combos = 6;
        } else if (col > row) {
          combos = 4;
        } else {
          combos = 12;
        }

        String hand = _getHandAt(row, col);
        Map<String, int> weights = _handActionWeights[hand] ?? {};

        // To properly handle missing "Fold" weights, we assume anything not explicitly accounted for is a Fold.
        int nonFoldTotal = 0;
        weights.forEach((action, weight) {
          if (!action.toLowerCase().contains('fold')) {
            nonFoldTotal += weight;
            actionCombos[action] = (actionCombos[action] ?? 0) + (combos * weight / 100);
          }
        });

        int foldWeight = weights.entries
            .where((e) => e.key.toLowerCase().contains('fold'))
            .fold(0, (sum, e) => sum + e.value);
            
        // Fallback: if there's no explicitly defined fold but actions don't sum to 100
        if (foldWeight == 0 && nonFoldTotal < 100) {
          foldWeight = 100 - nonFoldTotal;
        }

        if (foldWeight > 0) {
           // We might need to map it to a standard "Fold" label if it's implicitly calculated
           String foldLabel = _uniqueActions.firstWhere((a) => a.toLowerCase().contains('fold'), orElse: () => 'Fold');
           actionCombos[foldLabel] = (actionCombos[foldLabel] ?? 0) + (combos * foldWeight / 100);
        }
      }
    }

    Map<String, double> actionFrequencies = {};
    actionCombos.forEach((action, combos) {
      actionFrequencies[action] = (combos / totalCombos) * 100;
    });

    return actionFrequencies;
  }

  Widget _buildLegend(ChartColors colors) {
    if (_uniqueActions.isEmpty) return const SizedBox.shrink();

    // Sort actions to show Fold last, or consistently order them
    final sortedActions = _uniqueActions.toList()
      ..sort((a, b) {
        if (a.toLowerCase().contains('fold')) return 1;
        if (b.toLowerCase().contains('fold')) return -1;
        return a.compareTo(b);
      });

    final frequencies = _calculateActionFrequencies();

    return Wrap(
      spacing: 16.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.center,
      children: sortedActions.map((action) {
        final double freq = frequencies[action] ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _getColorForAction(action, colors),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text('$action (${freq.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 14)),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartColors = Theme.of(context).extension<ChartColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.position} Chart'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? const Center(
              child: Text(
                'Chart configuration not found.\nTry a different combination.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final gridSize =
                            constraints.maxWidth < constraints.maxHeight
                            ? constraints.maxWidth
                            : constraints.maxHeight;

                        return Center(
                          child: SizedBox(
                            width: gridSize,
                            height: gridSize,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 13,
                                    childAspectRatio: 1.0,
                                    crossAxisSpacing: 1,
                                    mainAxisSpacing: 1,
                                  ),
                              itemCount: 13 * 13,
                              itemBuilder: (context, index) {
                                int row = index ~/ 13;
                                int col = index % 13;
                                String hand = _getHandAt(row, col);
                                Map<String, int> actionWeights =
                                    _handActionWeights[hand] ?? {};

                                int foldWeight = actionWeights.entries
                                    .where(
                                      (e) =>
                                          e.key.toLowerCase().contains('fold'),
                                    )
                                    .fold(0, (sum, e) => sum + e.value);

                                bool isMostlyFolded =
                                    (foldWeight >= 100) ||
                                    actionWeights.isEmpty;

                                return Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      _buildCellBackground(
                                        actionWeights,
                                        chartColors,
                                      ),
                                      Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            hand,
                                            style: TextStyle(
                                              color: isMostlyFolded
                                                  ? Colors.grey.shade400
                                                  : Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              shadows: const [
                                                Shadow(
                                                  blurRadius: 2.0,
                                                  color: Colors.black87,
                                                  offset: Offset(1.0, 1.0),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLegend(chartColors),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
