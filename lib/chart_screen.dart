import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'utils/chart_parser.dart';
import 'theme.dart';
import 'action_popup.dart';
import 'card.dart' as c;

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
  PositionChart _chart = const PositionChart(
    comboActions: {},
    uniqueActions: {PositionChart.foldLabel},
  );
  bool _isLoading = true;
  bool _hasError = false;

  String? _selectedHand;
  Rect? _selectedCellRect;

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  Future<void> _loadChart() async {
    final fileName =
        '${widget.type.toLowerCase()}_${widget.stacks}_${widget.limit.toLowerCase()}_${widget.raise.toLowerCase()}_${widget.chart.toLowerCase()}.yaml';
    try {
      final yamlString = await rootBundle.loadString('assets/$fileName');
      final yamlDoc = loadYaml(yamlString);
      final parsed = ChartParser.parse(yamlDoc, widget.position);

      setState(() {
        _chart = parsed;
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

    final r1 = c.Card.ranks[r1Index];
    final r2 = c.Card.ranks[r2Index];

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

  Widget _buildCellBackground(String hand, ChartColors colors) {
    final actionCounts = _chart.actionCountsForHand(hand);
    List<Widget> bars = [];
    int nonFoldTotal = 0;
    int comboTotal = 0;

    final sortedActions = actionCounts.keys.toList()
      ..sort((a, b) {
        int getPriority(String action) {
          final lower = action.toLowerCase();
          if (lower.contains('all-in') || lower.contains('shove')) return 0;
          if (lower.contains('raise')) return 1;
          if (lower.contains('call')) return 2;
          if (lower.contains('fold')) return 3;
          return 4;
        }

        return getPriority(a).compareTo(getPriority(b));
      });

    for (var action in sortedActions) {
      final count = actionCounts[action] ?? 0;
      comboTotal += count;
      if (action.toLowerCase().contains('fold') || count <= 0) continue;

      nonFoldTotal += count;
      bars.add(
        Expanded(
          flex: count,
          child: Container(color: _getColorForAction(action, colors)),
        ),
      );
    }

    final remaining = comboTotal - nonFoldTotal;
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

  Widget _buildLegend(ChartColors colors) {
    if (_chart.uniqueActions.isEmpty) return const SizedBox.shrink();

    // Sort actions to show Raise, Call, then Fold
    final sortedActions = _chart.uniqueActions.toList()
      ..sort((a, b) {
        int getWeight(String action) {
          final l = action.toLowerCase();
          if (l.contains('raise')) return 0;
          if (l.contains('call')) return 1;
          if (l.contains('fold')) return 2;
          return 3;
        }

        final wa = getWeight(a);
        final wb = getWeight(b);
        if (wa != wb) return wa.compareTo(wb);
        return a.compareTo(b);
      });

    final frequencies = _chart.actionFrequencies();

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
            Text(
              '$action (${freq.toStringAsFixed(1)}%)',
              style: const TextStyle(fontSize: 14),
            ),
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
          : Builder(
              builder: (scaffoldContext) {
                return GestureDetector(
                  onTap: () {
                    if (_selectedHand != null) {
                      setState(() {
                        _selectedHand = null;
                        _selectedCellRect = null;
                      });
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final gridSize =
                                      constraints.maxWidth <
                                          constraints.maxHeight
                                      ? constraints.maxWidth
                                      : constraints.maxHeight;

                                  return Center(
                                    child: SizedBox(
                                      width: gridSize,
                                      height: gridSize,
                                      child: GridView.builder(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
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
                                          final actionCounts = _chart
                                              .actionCountsForHand(hand);
                                          final comboTotal = actionCounts
                                              .values
                                              .fold<int>(
                                                0,
                                                (sum, count) => sum + count,
                                              );
                                          final foldCount =
                                              actionCounts.entries
                                                  .where(
                                                    (e) => e.key
                                                        .toLowerCase()
                                                        .contains('fold'),
                                                  )
                                                  .fold(
                                                    0,
                                                    (sum, e) => sum + e.value,
                                                  );
                                          final bool isMostlyFolded =
                                              comboTotal == 0 ||
                                              foldCount == comboTotal;

                                          return Builder(
                                            builder: (cellContext) {
                                              return GestureDetector(
                                                onTap: () {
                                                  final RenderBox overlay =
                                                      scaffoldContext
                                                              .findRenderObject()
                                                          as RenderBox;
                                                  final RenderBox box =
                                                      cellContext
                                                              .findRenderObject()
                                                          as RenderBox;
                                                  final position = box
                                                      .localToGlobal(
                                                        Offset.zero,
                                                        ancestor: overlay,
                                                      );
                                                  final cellRect =
                                                      position & box.size;
                                                  setState(() {
                                                    if (_selectedHand == hand) {
                                                      _selectedHand = null;
                                                      _selectedCellRect = null;
                                                    } else {
                                                      _selectedHand = hand;
                                                      _selectedCellRect =
                                                          cellRect;
                                                    }
                                                  });
                                                },
                                                child: Container(
                                                  clipBehavior: Clip.antiAlias,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          2,
                                                        ),
                                                  ),
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      _buildCellBackground(
                                                        hand,
                                                        chartColors,
                                                      ),
                                                      Center(
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          child: Text(
                                                            hand,
                                                            style: TextStyle(
                                                              color:
                                                                  isMostlyFolded
                                                                  ? Colors
                                                                        .grey
                                                                        .shade400
                                                                  : Colors
                                                                        .white,
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              shadows: const [
                                                                Shadow(
                                                                  blurRadius:
                                                                      2.0,
                                                                  color: Colors
                                                                      .black87,
                                                                  offset:
                                                                      Offset(
                                                                        1.0,
                                                                        1.0,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
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
                      if (_selectedHand != null && _selectedCellRect != null)
                        ActionPopup(
                          cellRect: _selectedCellRect!,
                          hand: _selectedHand!,
                          comboActions: _chart.comboActions,
                          uniqueActions: _chart.uniqueActions,
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
