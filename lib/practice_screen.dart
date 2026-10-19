import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'dart:math';
import 'utils/chart_parser.dart';
import 'chart_screen.dart';
import 'poker_table_view.dart';
import 'action_popup.dart';
import 'card.dart';
import 'constants.dart';
import 'deck.dart';
import 'user_settings.dart';

class PracticeScreen extends StatefulWidget {
  final String type;
  final String limit;
  final String stacks;
  final String raise;
  final String position;
  final String chart;

  /// Villain in the hand. The opener for vs OPR, or the 3-bettor for vs 3bet.
  final String? villain;

  const PracticeScreen({
    super.key,
    required this.type,
    required this.limit,
    required this.stacks,
    required this.raise,
    required this.position,
    required this.chart,
    this.villain,
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
  final Map<String, YamlMap> _heroDocs = {};
  YamlMap? _oprDoc;
  YamlMap? _villainVsOpenDoc;
  final Map<String, PositionChart> _openCharts = {};
  final Map<String, PositionChart?> _threeBetCharts = {};
  PositionChart? _villainChart;
  late String _currentPosition;
  List<String> _positionCycle = [];
  int _positionIndex = 0;

  @override
  void initState() {
    super.initState();

    if (widget.position == 'All') {
      if (widget.villain != null) {
        final allPos = ['UTG', 'HJ', 'CO', 'BTN', 'SB', 'BB'];
        final villainIndex = allPos.indexOf(widget.villain!);
        // Vs 3bet: hero opened, so cycle seats before the 3-bettor.
        // Vs OPR: hero faces an open, so cycle seats after the opener.
        _positionCycle = ChartParser.isVs3bet(widget.chart)
            ? allPos.sublist(0, villainIndex)
            : allPos.sublist(villainIndex + 1);
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

  bool _villainOpens(List<Card> cards) {
    if (widget.villain == null || _villainChart == null) return true;
    final action = _villainChart!.actionForCards(cards[0], cards[1]);
    return !action.toLowerCase().contains('fold');
  }

  bool _heroOpened(List<Card> cards) {
    if (_oprDoc == null) return true;
    final chart = _openCharts.putIfAbsent(
      _currentPosition,
      () => ChartParser.parse(_oprDoc, _currentPosition),
    );
    if (chart.comboActions.isEmpty) return true;
    final action = chart.actionForCards(cards[0], cards[1]);
    return !action.toLowerCase().contains('fold');
  }

  /// True when [cards] 3-bet the hero's open. A missing chart, or one with no
  /// raise, does not reject the hand.
  bool _villainThreeBet(List<Card> cards) {
    final chart = _threeBetCharts.putIfAbsent(_currentPosition, () {
      final doc = _villainVsOpenDoc;
      if (doc == null || !doc.containsKey(_currentPosition)) return null;
      final parsed = ChartParser.parse(doc, _currentPosition);
      final hasRaise = parsed.comboActions.values.any(
        (action) => action.toLowerCase().contains('raise'),
      );
      return hasRaise ? parsed : null;
    });
    if (chart == null) return true;
    final action = chart.actionForCards(cards[0], cards[1]);
    return action.toLowerCase().contains('raise');
  }

  void _dealHand() {
    if (widget.position == 'All' && _card1 != null && _positionCycle.length > 1) {
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

      if (ChartParser.isVs3bet(widget.chart)) {
        final heroCards = _playerHands[_currentPosition];
        if (heroCards != null && !_heroOpened(heroCards)) continue;
        final villainCards = _playerHands[widget.villain!];
        if (villainCards != null && !_villainThreeBet(villainCards)) continue;
      } else if (widget.villain != null) {
        final villainCards = _playerHands[widget.villain!];
        if (villainCards != null && !_villainOpens(villainCards)) {
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
    String pathFor(String chart, {String? hero}) => ChartParser.assetPath(
      type: widget.type,
      stacks: widget.stacks,
      limit: widget.limit,
      raise: widget.raise,
      chart: chart,
      hero: hero,
    );
    try {
      if (ChartParser.isPerHero(widget.chart)) {
        final heroes = widget.position == 'All'
            ? List<String>.from(_positionCycle)
            : [widget.position];
        final loaded = <String>[];
        for (final hero in heroes) {
          try {
            final yamlString = await rootBundle.loadString(
              pathFor(widget.chart, hero: hero),
            );
            final doc = loadYaml(yamlString);
            if (doc is YamlMap && doc.containsKey(widget.villain)) {
              _heroDocs[hero] = doc;
              loaded.add(hero);
            }
          } catch (e) {
            debugPrint('Missing ${widget.chart} chart for $hero: $e');
          }
        }
        if (loaded.isEmpty) {
          throw StateError('No ${widget.chart} chart for ${widget.villain}');
        }
        if (widget.position == 'All') {
          _positionCycle = loaded;
          _positionIndex = 0;
          _currentPosition = _positionCycle.first;
        }
        final openYaml = await rootBundle.loadString(
          pathFor(PokerConstants.chartOPR),
        );
        final openDoc = loadYaml(openYaml);
        if (ChartParser.isVs3bet(widget.chart)) {
          if (openDoc is YamlMap) _oprDoc = openDoc;
          try {
            final villainYaml = await rootBundle.loadString(
              pathFor(PokerConstants.chartVsOPR, hero: widget.villain),
            );
            final villainDoc = loadYaml(villainYaml);
            if (villainDoc is YamlMap) _villainVsOpenDoc = villainDoc;
          } catch (e) {
            debugPrint('Missing vs OPR chart for ${widget.villain}: $e');
          }
        } else if (openDoc is YamlMap) {
          _villainChart = ChartParser.parse(openDoc, widget.villain!);
        }
      } else {
        final yamlString = await rootBundle.loadString(pathFor(widget.chart));
        _yamlDoc = loadYaml(yamlString);
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

  void _parseChartForPosition() {
    if (ChartParser.isPerHero(widget.chart)) {
      _chart = ChartParser.parse(_heroDocs[_currentPosition], widget.villain!);
      return;
    }
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
            Text(
              widget.villain == null
                  ? 'Practice: $_currentPosition'
                  : 'Practice: $_currentPosition vs ${widget.villain}',
            ),
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
                      villain: widget.villain,
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
                        villainPosition: widget.villain,
                        villainBet: ChartParser.isVs3bet(widget.chart)
                            ? _chart.callAmount
                            : null,
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
