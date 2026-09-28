import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'dart:math';
import 'utils/chart_parser.dart';
import 'chart_screen.dart';
import 'poker_table_view.dart';
import 'action_popup.dart';
import 'card.dart';
import 'deck.dart';
import 'user_settings.dart';

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

class _PracticeScreenState extends State<PracticeScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  PositionChart _chart = const PositionChart(
    comboActions: {},
    uniqueActions: {PositionChart.foldLabel},
  );
  Set<String> get _uniqueActions => _chart.uniqueActions;

  Deck? _deck;
  Card? _card1;
  Card? _card2;
  String? _currentHand;
  final Map<String, List<Card>> _playerHands = {};

  bool _hasAnswered = false;
  String? _selectedAction;
  final PracticeSettings _settings = UserSettings.instance.practice;
  bool get _autoAdvance => _settings.autoAdvance;
  bool get _displayInDollars => _settings.displayInDollars;
  bool get _showOpponentCards => _settings.showOpponentCards;
  bool _isProcessing = false;
  bool _isHintVisible = false;
  Rect? _hintButtonRect;

  int _totalHands = 0;
  int _correctHands = 0;
  int _vpipCount = 0;
  int _pfrCount = 0;

  YamlMap? _yamlDoc;
  YamlMap? _raiserYamlDoc;
  PositionChart? _raiserChart;
  String? _raiserPosition;
  late String _currentPosition;
  List<String> _positionCycle = [];
  int _positionIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.chart.startsWith('vs_') && widget.chart.endsWith('_opr')) {
      _raiserPosition = widget.chart.split('_')[1].toUpperCase();
    }

    if (widget.position == 'All') {
      if (_raiserPosition != null) {
        final allPos = ['UTG', 'HJ', 'CO', 'BTN', 'SB', 'BB'];
        final oppIndex = allPos.indexOf(_raiserPosition!);
        _positionCycle = allPos.sublist(oppIndex + 1);
      } else {
        _positionCycle = [
          if (widget.chart != 'OPR') 'BB',
          'SB',
          'BTN',
          'CO',
          'HJ',
          'UTG',
        ];
      }
      _positionIndex = 0;
      _currentPosition = _positionCycle[_positionIndex];
    } else {
      _currentPosition = widget.position;
    }
    _loadChart();
  }

  bool _simulateRaiser(List<Card> cards) {
    if (_raiserPosition == null || _raiserChart == null) return true;
    final action = _raiserChart!.actionForCards(cards[0], cards[1]);
    return !action.toLowerCase().contains('fold');
  }

  void _dealHand() {
    if (widget.position == 'All' && _yamlDoc != null && _card1 != null) {
      _positionIndex = (_positionIndex + 1) % _positionCycle.length;
      _currentPosition = _positionCycle[_positionIndex];
      _parseChartForPosition();
    }

    while (true) {
      _deck = Deck();

      _playerHands.clear();
      for (var pos in ['SB', 'BB', 'UTG', 'HJ', 'CO', 'BTN']) {
        _playerHands[pos] = [_deck!.nextCard(), _deck!.nextCard()];
      }

      if (_raiserPosition != null) {
        final raiserCards = _playerHands[_raiserPosition!];
        if (raiserCards != null && !_simulateRaiser(raiserCards)) {
          continue;
        }
      }

      _card1 = _playerHands[_currentPosition]![0];
      _card2 = _playerHands[_currentPosition]![1];
      break;
    }

    int i1 = Card.ranks.indexOf(_card1!.value);
    int i2 = Card.ranks.indexOf(_card2!.value);

    if (i1 == i2) {
      _currentHand = '${_card1!.value}${_card2!.value}';
    } else if (i1 > i2) {
      _currentHand =
          '${_card1!.value}${_card2!.value}${_card1!.suit == _card2!.suit ? "s" : "o"}';
    } else {
      _currentHand =
          '${_card2!.value}${_card1!.value}${_card1!.suit == _card2!.suit ? "s" : "o"}';
    }

    _hasAnswered = false;
    _selectedAction = null;
    _isProcessing = false;
    _isHintVisible = false;
    setState(() {});
  }

  Future<void> _loadChart() async {
    final fileName =
        '${widget.type.toLowerCase()}_${widget.stacks}_${widget.limit.toLowerCase()}_${widget.raise.toLowerCase()}_${widget.chart.toLowerCase()}.yaml';
    try {
      final yamlString = await rootBundle.loadString('assets/$fileName');
      _yamlDoc = loadYaml(yamlString);

      if (_raiserPosition != null) {
        final raiserFileName =
            '${widget.type.toLowerCase()}_${widget.stacks}_${widget.limit.toLowerCase()}_${widget.raise.toLowerCase()}_opr.yaml';
        final raiserYamlString = await rootBundle.loadString(
          'assets/$raiserFileName',
        );
        _raiserYamlDoc = loadYaml(raiserYamlString);
        _parseRaiserChart();
      }

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

  void _parseRaiserChart() {
    if (_raiserYamlDoc == null || _raiserPosition == null) return;
    _raiserChart = ChartParser.parse(_raiserYamlDoc, _raiserPosition!);
  }

  void _parseChartForPosition() {
    if (_yamlDoc == null) return;
    _chart = ChartParser.parse(_yamlDoc, _currentPosition);
  }

  String? _getCorrectAction() {
    if (_card1 == null || _card2 == null) return null;
    return _chart.actionForCards(_card1!, _card2!);
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
    final isPfr =
        lowerAction.contains('raise') ||
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
    if (_card1 == null || _card2 == null) return {};
    final action = _chart.actionForCards(_card1!, _card2!);
    return {action: 100};
  }

  List<MapEntry<String, int>> _getSortedWeightEntries(
    Map<String, int> weights,
  ) {
    return weights.entries.where((e) => e.value > 0).toList()..sort((a, b) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings & Stats',
            onPressed: _showStatsBottomSheet,
          ),
        ],
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
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: 300 + PokerTableView.heroExtraHeight,
                        maxHeight: max(
                              300,
                              MediaQuery.of(context).size.height * 0.45,
                            ) +
                            PokerTableView.heroExtraHeight,
                      ),
                      child: PokerTableView(
                        heroPosition: _currentPosition,
                        chartType: widget.chart,
                        raise: widget.raise,
                        limit: widget.limit,
                        displayInDollars: _displayInDollars,
                        showOpponentCards: _showOpponentCards,
                        playerHands: _playerHands,
                        heroTrailing: Builder(
                          builder: (buttonContext) {
                            return IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 40,
                                height: 40,
                              ),
                              icon: const Icon(
                                Icons.lightbulb_outline,
                                size: 28,
                              ),
                              color: Colors.amber,
                              tooltip: 'Show Hint',
                              onPressed: () {
                                final RenderBox box =
                                    buttonContext.findRenderObject()
                                        as RenderBox;
                                final position = box.localToGlobal(
                                  Offset.zero,
                                );
                                setState(() {
                                  _hintButtonRect = position & box.size;
                                  _isHintVisible = !_isHintVisible;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_hasAnswered) ...[
                      Row(
                        children: sortedActions.map((action) {
                          final color = getButtonColor(action);
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: ElevatedButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _onActionSelected(action),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 60),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
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
            if (_isHintVisible &&
                _hintButtonRect != null &&
                _currentHand != null)
              ActionPopup(
                cellRect: _hintButtonRect!,
                hand: _currentHand!,
                comboActions: _chart.comboActions,
                uniqueActions: _chart.uniqueActions,
              ),
          ],
        ),
      ),
    );
  }

  void _showStatsBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final vpip = _totalHands > 0
                ? (_vpipCount / _totalHands * 100)
                : 0.0;
            final pfr = _totalHands > 0 ? (_pfrCount / _totalHands * 100) : 0.0;
            final accuracy = _totalHands > 0
                ? (_correctHands / _totalHands * 100)
                : 0.0;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Practice Stats & Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCompactStatItem('Hands', '$_totalHands'),
                        _buildCompactStatItem(
                          'Accuracy',
                          '${accuracy.toStringAsFixed(0)}%',
                        ),
                        _buildCompactStatItem(
                          'VPIP',
                          '${vpip.toStringAsFixed(1)}%',
                        ),
                        _buildCompactStatItem(
                          'PFR',
                          '${pfr.toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Auto Advance'),
                      subtitle: const Text(
                        'Deal next hand immediately upon correct answer',
                      ),
                      value: _autoAdvance,
                      onChanged: (val) {
                        setState(() => _settings.autoAdvance = val);
                        setModalState(() {});
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Display in Dollars'),
                      subtitle: const Text('Show bets in \$ instead of bb'),
                      value: _displayInDollars,
                      onChanged: (val) {
                        setState(() => _settings.displayInDollars = val);
                        setModalState(() {});
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text("Show Opponents' Cards"),
                      subtitle: const Text(
                        'Reveal other players\' hands instead of card backs',
                      ),
                      value: _showOpponentCards,
                      onChanged: (val) {
                        setState(() => _settings.showOpponentCards = val);
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompactStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
