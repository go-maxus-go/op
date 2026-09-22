import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'utils/range_parser.dart';

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
  // Map of hand string (e.g., "AKs") to weight (0-100)
  Map<String, int> _handWeights = {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  Future<void> _loadChart() async {
    final fileName = '${widget.type.toLowerCase()}_${widget.stacks}_${widget.limit.toLowerCase()}_${widget.raise.toLowerCase()}_${widget.position.toLowerCase()}_${widget.chart.toLowerCase()}.yaml';
    try {
      final yamlString = await rootBundle.loadString('assets/charts/$fileName');
      final yamlDoc = loadYaml(yamlString);
      
      Map<String, int> newWeights = {};
      
      if (yamlDoc is YamlMap && yamlDoc.containsKey('hands')) {
        final handsList = yamlDoc['hands'];
        if (handsList is YamlList) {
          for (var item in handsList) {
            if (item is YamlMap) {
              final handString = item.keys.first.toString();
              final actions = item[handString];
              int nonFoldWeight = 0;
              
              if (actions is YamlList) {
                for (var actionItem in actions) {
                  if (actionItem is YamlMap) {
                    final actionName = actionItem.keys.first.toString();
                    final weight = int.tryParse(actionItem[actionName].toString()) ?? 0;
                    if (actionName.toLowerCase() != 'fold') {
                      nonFoldWeight += weight;
                    }
                  }
                }
              }
              
              final parsedHands = RangeParser.parseHandRange(handString);
              for (var hand in parsedHands) {
                newWeights[hand] = (newWeights[hand] ?? 0) + nonFoldWeight;
                if (newWeights[hand]! > 100) newWeights[hand] = 100;
              }
            }
          }
        }
      }

      setState(() {
        _handWeights = newWeights;
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
    // ranks = ['2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A']
    // A is at index 12, 2 is at index 0.
    // In standard grids, A is at top left (row 0, col 0).
    final r1Index = 12 - row;
    final r2Index = 12 - col;
    
    final r1 = RangeParser.ranks[r1Index];
    final r2 = RangeParser.ranks[r2Index];

    if (row == col) {
      return '$r1$r2';
    } else if (col > row) {
      // Suited (top right)
      return '$r1${r2}s';
    } else {
      // Offsuit (bottom left)
      return '$r2${r1}o';
    }
  }

  Color _getColorForWeight(int weight) {
    if (weight == 0) return Colors.grey.shade800;
    
    // Base color is green. The opacity/intensity scales with weight.
    return Colors.green.withValues(alpha: weight / 100.0);
  }

  @override
  Widget build(BuildContext context) {
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gridSize = constraints.maxWidth < constraints.maxHeight 
                      ? constraints.maxWidth 
                      : constraints.maxHeight;
                  
                  return Center(
                    child: SizedBox(
                      width: gridSize,
                      height: gridSize,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                          int weight = _handWeights[hand] ?? 0;
                          
                          return Container(
                            decoration: BoxDecoration(
                              color: _getColorForWeight(weight),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                hand,
                                style: TextStyle(
                                  color: weight > 0 ? Colors.white : Colors.grey.shade400,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
