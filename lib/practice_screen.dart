import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'dart:math';
import 'utils/range_parser.dart';
import 'chart_screen.dart';
import 'poker_table_view.dart';
import 'action_popup.dart';

class PracticeScreen extends StatefulWidget {
  final String type;
  final String limit;
  final String stacks;
  final String raise;
  final String position;
  final String chart;

  const PracticeScreen({
    super.key,
    required this.type,
    required this.limit,
    required this.stacks,
    required this.raise,
    required this.position,
    required this.chart,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class PlayingCard {
  final String rank;
  final String suit;
  PlayingCard(this.rank, this.suit);
  String get assetPath => 'assets/deck/card_$rank$suit.png';
}

class _PracticeScreenState extends State<PracticeScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, Map<String, int>> _handActionWeights = {};
  Set<String> _uniqueActions = {};

  List<PlayingCard> _deck = [];
  PlayingCard? _card1;
  PlayingCard? _card2;
  String? _currentHand;
  final Map<String, List<PlayingCard>> _playerHands = {};
  int _currentRng = 50;

  bool _hasAnswered = false;
  String? _selectedAction;
  bool _autoAdvance = true;
  bool _isProcessing = false;
  bool _isHintVisible = false;
  Rect? _hintButtonRect;

  int _totalHands = 0;
  int _correctHands = 0;
  int _vpipCount = 0;
  int _pfrCount = 0;

  YamlMap? _yamlDoc;
  late String _currentPosition;
  List<String> _positionCycle = [];
  int _positionIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.position == 'All') {
      _positionCycle = [
        if (widget.chart != 'OPR') 'BB',
        'SB',
        'BTN',
        'CO',
        'HJ',
        'UTG',
      ];
      _positionIndex = 0;
      _currentPosition = _positionCycle[_positionIndex];
    } else {
      _currentPosition = widget.position;
    }
    _loadChart();
  }

  void _initDeck() {
    const suits = ['c', 'd', 'h', 's'];
    _deck = [];
    for (var r in RangeParser.ranks) {
      for (var s in suits) {
        _deck.add(PlayingCard(r, s));
      }
    }
  }

  void _dealHand() {
    if (widget.position == 'All' && _yamlDoc != null && _card1 != null) {
      _positionIndex = (_positionIndex + 1) % _positionCycle.length;
      _currentPosition = _positionCycle[_positionIndex];
      _parseChartForPosition();
    }

    _initDeck();
    _deck.shuffle(Random());
    _card1 = _deck[0];
    _card2 = _deck[1];
    _currentRng = Random().nextInt(100) + 1;

    _playerHands.clear();
    int deckIndex = 2;
    for (var pos in ['SB', 'BB', 'UTG', 'HJ', 'CO', 'BTN']) {
      if (pos == _currentPosition) {
        _playerHands[pos] = [_deck[0], _deck[1]];
      } else {
        _playerHands[pos] = [_deck[deckIndex], _deck[deckIndex + 1]];
        deckIndex += 2;
      }
    }

    int i1 = RangeParser.rankIndex(_card1!.rank);
    int i2 = RangeParser.rankIndex(_card2!.rank);

    if (i1 == i2) {
      _currentHand = '${_card1!.rank}${_card2!.rank}';
    } else if (i1 > i2) {
      _currentHand =
          '${_card1!.rank}${_card2!.rank}${_card1!.suit == _card2!.suit ? "s" : "o"}';
    } else {
      _currentHand =
          '${_card2!.rank}${_card1!.rank}${_card1!.suit == _card2!.suit ? "s" : "o"}';
    }

    _hasAnswered = false;
    _selectedAction = null;
    _isProcessing = false;
    setState(() {});
  }

  Future<void> _loadChart() async {
    final fileName =
        '${widget.type.toLowerCase()}_${widget.stacks}_${widget.limit.toLowerCase()}_${widget.raise.toLowerCase()}_${widget.chart.toLowerCase()}.yaml';
    try {
      final yamlString = await rootBundle.loadString('assets/charts/$fileName');
      _yamlDoc = loadYaml(yamlString);
      
      _parseChartForPosition();
      
      _dealHand();
      
      setState(() {
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

  void _parseChartForPosition() {
    if (_yamlDoc == null) return;
    
    Map<String, Map<String, int>> newWeights = {};
    Set<String> newUniqueActions = {};

    if (_yamlDoc is YamlMap && _yamlDoc!.containsKey(_currentPosition)) {
      final handsList = _yamlDoc![_currentPosition];
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

    _handActionWeights = newWeights;
    _uniqueActions = newUniqueActions;
    if (!_uniqueActions.any((a) => a.toLowerCase().contains('fold'))) {
      _uniqueActions.add('Fold');
    }
  }

  String? _getCorrectAction() {
    final weights = _getCurrentHandWeights();
    if (weights.isEmpty) return null;

    final List<String> evaluationOrder = weights.keys.toList()
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

    int cumulative = 0;
    for (String action in evaluationOrder) {
      cumulative += weights[action] ?? 0;
      if (_currentRng <= cumulative) {
        return action;
      }
    }
    return evaluationOrder.last;
  }

  void _onActionSelected(String action) async {
    if (_hasAnswered || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final correctAction = _getCorrectAction();
    final isCorrect = action == correctAction;

    final lowerAction = action.toLowerCase();
    final isVpip = !lowerAction.contains('fold');
    final isPfr = lowerAction.contains('raise') ||
        lowerAction.contains('all-in') ||
        lowerAction.contains('shove');

    if (isCorrect && _autoAdvance) {
      setState(() {
        _totalHands++;
        _correctHands++;
        if (isVpip) _vpipCount++;
        if (isPfr) _pfrCount++;
      });
      _dealHand();
    } else {
      setState(() {
        _selectedAction = action;
        _hasAnswered = true;
        _totalHands++;
        if (isCorrect) _correctHands++;
        if (isVpip) _vpipCount++;
        if (isPfr) _pfrCount++;
        _isProcessing = false;
      });
    }
  }

  Map<String, int> _getCurrentHandWeights() {
    if (_currentHand == null) return {};
    final weights = _handActionWeights[_currentHand!] ?? {};

    int foldWeight = weights.entries
        .where((e) => e.key.toLowerCase().contains('fold'))
        .fold(0, (sum, e) => sum + e.value);

    int nonFoldTotal = 0;
    weights.forEach((k, v) {
      if (!k.toLowerCase().contains('fold')) {
        nonFoldTotal += v;
      }
    });

    Map<String, int> fullWeights = Map.from(weights);

    if (foldWeight == 0 && nonFoldTotal < 100) {
      String foldLabel = _uniqueActions.firstWhere(
        (a) => a.toLowerCase().contains('fold'),
        orElse: () => 'Fold',
      );
      fullWeights[foldLabel] = 100 - nonFoldTotal;
    }

    return fullWeights;
  }

  List<MapEntry<String, int>> _getSortedWeightEntries(Map<String, int> weights) {
    return weights.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) {
        int getPriority(String action) {
          final lower = action.toLowerCase();
          if (lower.contains('all-in') || lower.contains('shove')) return 0;
          if (lower.contains('raise')) return 1;
          if (lower.contains('call')) return 2;
          if (lower.contains('fold')) return 3;
          return 4;
        }
        return getPriority(a.key).compareTo(getPriority(b.key));
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice')),
        body: const Center(child: Text('Chart not found.')),
      );
    }

    if (_card1 == null || _card2 == null) {
      return const SizedBox.shrink();
    }

    final weights = _getCurrentHandWeights();
    final correctAction = _getCorrectAction();

    bool isCorrect = false;
    if (_hasAnswered && _selectedAction != null) {
      isCorrect = _selectedAction == correctAction;
    }

    // Sort actions: Fold, Call, Raise
    final sortedActions = _uniqueActions.toList()
      ..sort((a, b) {
        int getPriority(String action) {
          final lower = action.toLowerCase();
          if (lower.contains('fold')) return 0;
          if (lower.contains('call')) return 1;
          if (lower.contains('raise')) return 2;
          if (lower.contains('all-in') || lower.contains('shove')) return 3;
          return 4;
        }

        return getPriority(a).compareTo(getPriority(b));
      });

    Color getButtonColor(String action) {
      final lower = action.toLowerCase();
      if (lower.contains('fold')) return Colors.blue;
      if (lower.contains('call')) return Colors.green;
      if (lower.contains('raise')) return Colors.red;
      if (lower.contains('all-in') || lower.contains('shove')) {
        return Colors.deepOrange;
      }
      return Colors.grey;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Practice: $_currentPosition'),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.bar_chart, size: 24),
              tooltip: 'View Chart',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChartScreen(
                      type: widget.type,
                      limit: widget.limit,
                      stacks: widget.stacks,
                      raise: widget.raise,
                      position: _currentPosition,
                      chart: widget.chart,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () {
          if (_isHintVisible) {
            setState(() {
              _isHintVisible = false;
            });
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCompactStats(),
              const SizedBox(height: 16),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: PokerTableView(
                  heroPosition: _currentPosition,
                  chartType: widget.chart,
                  playerHands: _playerHands,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Color.lerp(Colors.red, Colors.blue, _currentRng / 100.0)?.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Color.lerp(Colors.red, Colors.blue, _currentRng / 100.0)!,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      'RNG: $_currentRng',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color.lerp(Colors.red, Colors.blue, _currentRng / 100.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Builder(
                    builder: (buttonContext) {
                      return IconButton(
                        icon: const Icon(Icons.lightbulb_outline, size: 32),
                        color: Colors.amber,
                        tooltip: 'Show Hint',
                        onPressed: _hasAnswered
                            ? null
                            : () {
                                final RenderBox box = buttonContext.findRenderObject() as RenderBox;
                                final position = box.localToGlobal(Offset.zero);
                                setState(() {
                                  _hintButtonRect = position & box.size;
                                  _isHintVisible = !_isHintVisible;
                                });
                              },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_hasAnswered) ...[
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: sortedActions.map((action) {
                    final color = getButtonColor(action);
                    return ElevatedButton(
                      onPressed: _isProcessing ? null : () => _onActionSelected(action),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        fixedSize: const Size(160, 80),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            action,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ] else ...[
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  isCorrect ? 'Correct!' : 'Should be $correctAction',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Hand: $_currentHand',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                // Show probabilities
                ..._getSortedWeightEntries(weights).map(
                      (e) => Text(
                        '${e.key}: ${e.value}%',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _dealHand,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 80),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 20,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Next Hand'),
                ),
              ],
            ],
          ),
        ),
      ),
      if (_isHintVisible && _hintButtonRect != null && _currentHand != null)
        ActionPopup(
          cellRect: _hintButtonRect!,
          hand: _currentHand!,
          actionWeights: _getCurrentHandWeights(),
          uniqueActions: _uniqueActions,
        ),
    ],
  ),
),
    );
  }

  Widget _buildCompactStats() {
    final vpip = _totalHands > 0 ? (_vpipCount / _totalHands * 100) : 0.0;
    final pfr = _totalHands > 0 ? (_pfrCount / _totalHands * 100) : 0.0;
    final accuracy = _totalHands > 0 ? (_correctHands / _totalHands * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCompactStatItem('Hands', '$_totalHands'),
                  const SizedBox(width: 16),
                  _buildCompactStatItem('Accuracy', '${accuracy.toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCompactStatItem('VPIP', '${vpip.toStringAsFixed(1)}%'),
                  const SizedBox(width: 16),
                  _buildCompactStatItem('PFR', '${pfr.toStringAsFixed(1)}%'),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),
          Column(
            children: [
              const Text(
                'Auto\nAdvance',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: _autoAdvance,
                  onChanged: (val) => setState(() => _autoAdvance = val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
