import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'dart:math';
import 'utils/range_parser.dart';

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

  bool _hasAnswered = false;
  String? _selectedAction;

  @override
  void initState() {
    super.initState();
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
    _initDeck();
    _deck.shuffle(Random());
    _card1 = _deck[0];
    _card2 = _deck[1];

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
    setState(() {});
  }

  Future<void> _loadChart() async {
    final fileName =
        '${widget.type.toLowerCase()}_${widget.stacks}_${widget.limit.toLowerCase()}_${widget.raise.toLowerCase()}_${widget.chart.toLowerCase()}.yaml';
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
        // Ensure "Fold" is always an option if the chart is sparse
        if (!_uniqueActions.any((a) => a.toLowerCase().contains('fold'))) {
          _uniqueActions.add('Fold');
        }
        _isLoading = false;
        _hasError = false;
        _dealHand();
      });
    } catch (e) {
      debugPrint('Error loading chart: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _onActionSelected(String action) {
    if (_hasAnswered) return;
    setState(() {
      _selectedAction = action;
      _hasAnswered = true;
    });
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

    bool isCorrect = false;
    if (_hasAnswered && _selectedAction != null) {
      final selectedWeight = weights[_selectedAction!] ?? 0;
      isCorrect = selectedWeight > 0;
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
        title: Text('Practice: ${widget.position}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(_card1!.assetPath),
                  const SizedBox(width: 8),
                  Image.asset(_card2!.assetPath),
                ],
              ),
              const SizedBox(height: 32),
              if (!_hasAnswered) ...[
                Text(
                  'What is the correct action?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: sortedActions.map((action) {
                    final color = getButtonColor(action);
                    return ElevatedButton(
                      onPressed: () => _onActionSelected(action),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(140, 80),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
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
                      child: Text(action),
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
                  isCorrect ? 'Correct!' : 'Incorrect',
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
                ...weights.entries
                    .where((e) => e.value > 0)
                    .map(
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
    );
  }
}
