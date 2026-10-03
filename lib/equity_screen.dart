import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Card;
import 'background_equity_simulation.dart';
import 'card.dart';
import 'deck.dart';
import 'range_chart.dart';
import 'range_selector_screen.dart';
import 'user_settings.dart';

class EquityHand {
  List<Card?> cards = [null, null];
  Set<String> range = {};
}

class EquityScreen extends StatefulWidget {
  /// When set, used instead of the saved simulation count.
  final int? maxSimulations;

  const EquityScreen({super.key, this.maxSimulations});

  @override
  State<EquityScreen> createState() => _EquityScreenState();
}

abstract class SelectionTarget {
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectionTarget && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class BoardTarget extends SelectionTarget {
  final int index;
  BoardTarget(this.index);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BoardTarget && index == other.index;

  @override
  int get hashCode => index.hashCode;
}

class HandTarget extends SelectionTarget {
  final int handIndex;
  final int cardIndex;
  HandTarget(this.handIndex, this.cardIndex);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HandTarget &&
          handIndex == other.handIndex &&
          cardIndex == other.cardIndex;

  @override
  int get hashCode => handIndex.hashCode ^ cardIndex.hashCode;
}

class _EquityScreenState extends State<EquityScreen> {
  static const int _maxHands = 10;

  final List<Card?> _board = List.filled(5, null);
  final List<EquityHand> _hands = [EquityHand(), EquityHand()];

  SelectionTarget? _currentSelection;

  late int _maxSimulations;

  BackgroundEquitySimulation? _simulation;

  /// Incremented on every recalculation so a worker that finishes starting
  /// after the deal has changed is stopped instead of adopted.
  var _generation = 0;

  /// Null when the equity cannot be calculated, e.g. when a range has no
  /// combos left on the board.
  EquityProgress? _progress;
  var _isCalculating = false;

  @override
  void initState() {
    super.initState();
    _maxSimulations =
        widget.maxSimulations ?? UserSettings.instance.equity.simulations;
    _recalculate();
  }

  @override
  void dispose() {
    _generation++;
    _simulation?.stop();
    _simulation = null;
    super.dispose();
  }

  /// Stops the current simulation and starts one for the hands and board.
  void _recalculate() {
    final generation = ++_generation;
    _simulation?.stop();
    _simulation = null;
    _progress = null;
    _isCalculating = false;

    final Future<BackgroundEquitySimulation> starting;
    try {
      starting = BackgroundEquitySimulation.start(
        ranges: [
          for (final hand in _hands)
            hand.range.isNotEmpty
                ? hand.range.join(', ')
                : hand.cards.whereType<Card>().join(),
        ],
        board: _board.whereType<Card>().toList(),
        maxSimulations: _maxSimulations,
        onProgress: (progress) {
          if (!mounted || generation != _generation) return;
          setState(() {
            _progress = progress;
            _isCalculating = !progress.isComplete;
          });
        },
        onError: (_) {
          if (!mounted || generation != _generation) return;
          setState(() => _isCalculating = false);
        },
      );
    } on ArgumentError {
      return;
    }
    _isCalculating = true;
    starting.then(
      (simulation) {
        if (!mounted || generation != _generation) {
          simulation.stop();
        } else {
          _simulation = simulation;
        }
      },
      onError: (Object _) {
        if (!mounted || generation != _generation) return;
        setState(() => _isCalculating = false);
      },
    );
  }

  String _equityText(int handIndex) {
    final progress = _progress;
    if (progress == null ||
        (progress.simulations == 0 && !progress.isComplete)) {
      return 'Equity: --%';
    }
    final equity = progress.equities[handIndex] * 100;
    return 'Equity: ${equity.toStringAsFixed(1)}%';
  }

  Set<Card> get _selectedCards {
    final set = <Card>{};
    for (var card in _board) {
      if (card != null) set.add(card);
    }
    for (var hand in _hands) {
      for (var card in hand.cards) {
        if (card != null) set.add(card);
      }
    }
    return set;
  }

  void _onCardSelectedFromKeyboard(Card? card) {
    if (_currentSelection == null) return;

    setState(() {
      final target = _currentSelection!;
      if (target is BoardTarget) {
        _board[target.index] = card;
        if (card != null) {
          // Auto-advance logic
          if (target.index < 4) {
            _currentSelection = BoardTarget(target.index + 1);
          } else {
            _currentSelection = null;
          }
        } else {
          // Auto-step back logic
          if (target.index > 0) {
            _currentSelection = BoardTarget(target.index - 1);
          }
        }
      } else if (target is HandTarget) {
        _hands[target.handIndex].cards[target.cardIndex] = card;
        if (card != null) {
          // Auto-advance logic
          if (target.cardIndex == 0) {
            _currentSelection = HandTarget(target.handIndex, 1);
          } else if (target.handIndex < _hands.length - 1) {
            _currentSelection = HandTarget(target.handIndex + 1, 0);
          } else {
            _currentSelection = null;
          }
        } else {
          // Auto-step back logic
          if (target.cardIndex == 1) {
            _currentSelection = HandTarget(target.handIndex, 0);
          } else if (target.handIndex > 0) {
            _currentSelection = HandTarget(target.handIndex - 1, 1);
          }
        }
      }
      _recalculate();
    });
  }

  void _addHand() {
    setState(() {
      _hands.add(EquityHand());
      _recalculate();
    });
  }

  String _rangePercentText(Set<String> range) {
    return '${(range.length / 1326 * 100).toStringAsFixed(1)}%';
  }

  void _resetHand(int index) {
    setState(() {
      _hands[index]
        ..range = {}
        ..cards = [null, null];
      _recalculate();
    });
  }

  void _removeHand(int index) {
    setState(() {
      _hands.removeAt(index);
      if (_currentSelection is HandTarget) {
        final target = _currentSelection as HandTarget;
        if (target.handIndex == index) {
          _currentSelection = null;
        } else if (target.handIndex > index) {
          _currentSelection = HandTarget(
            target.handIndex - 1,
            target.cardIndex,
          );
        }
      }
      _recalculate();
    });
  }

  Widget _buildCardSlot({
    required Card? card,
    required SelectionTarget target,
    String? label,
  }) {
    final isSelected = _currentSelection == target;
    final width = 50.0;
    final height = 70.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_currentSelection == target) {
            _currentSelection = null; // Toggle off
          } else {
            _currentSelection = target;
          }
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.transparent,
              border: isSelected
                  ? Border.all(color: Colors.blue, width: 3)
                  : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: AspectRatio(
                aspectRatio: Card.faceAspectRatio,
                child: Image.asset(
                  card?.assetPath ?? Card.backAssetPath,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Board',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCardSlot(card: _board[0], target: BoardTarget(0)),
              const SizedBox(width: 4),
              _buildCardSlot(card: _board[1], target: BoardTarget(1)),
              const SizedBox(width: 4),
              _buildCardSlot(card: _board[2], target: BoardTarget(2)),
              const SizedBox(width: 16),
              _buildCardSlot(card: _board[3], target: BoardTarget(3)),
              const SizedBox(width: 16),
              _buildCardSlot(card: _board[4], target: BoardTarget(4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHands() {
    return Expanded(
      child: ListView.builder(
        itemCount: _hands.length + (_hands.length < _maxHands ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _hands.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextButton.icon(
                onPressed: _addHand,
                icon: const Icon(Icons.add),
                label: const Text('Add Hand'),
              ),
            );
          }
          final hand = _hands[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                if (hand.range.isNotEmpty)
                  SizedBox(
                    width: 104,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RangeChartImage(range: hand.range, size: 52),
                        const SizedBox(height: 2),
                        Text(
                          _rangePercentText(hand.range),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _buildCardSlot(
                    card: hand.cards[0],
                    target: HandTarget(index, 0),
                  ),
                  const SizedBox(width: 4),
                  _buildCardSlot(
                    card: hand.cards[1],
                    target: HandTarget(index, 1),
                  ),
                ],
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RangeSelectorScreen(initialRange: hand.range),
                      ),
                    );
                    if (result is Set<String> &&
                        !setEquals(result, hand.range)) {
                      setState(() {
                        hand.range = result;
                        if (result.isNotEmpty) {
                          hand.cards = [
                            null,
                            null,
                          ]; // Clear specific cards if range is selected
                          if (_currentSelection is HandTarget &&
                              (_currentSelection as HandTarget).handIndex ==
                                  index) {
                            _currentSelection = null;
                          }
                        }
                        _recalculate();
                      });
                    }
                  },
                  child: const Text('Range'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _equityText(index),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hand.range.isNotEmpty || hand.cards.any((c) => c != null))
                  IconButton(
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Reset Hand',
                    onPressed: () => _resetHand(index),
                  ),
                if (_hands.length > 2)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _removeHand(index),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _hideKeyboard() {
    if (_currentSelection == null) return;
    setState(() => _currentSelection = null);
  }

  Widget _buildKeyboard() {
    if (_currentSelection == null) {
      return const SizedBox.shrink();
    }

    // Generate cards in order using Deck with seed 0
    final deck = Deck(seed: 0);
    final allCards = <Card>[];
    for (int i = 0; i < 52; i++) {
      allCards.add(deck.nextCard());
    }

    final selectedCards = _selectedCards;

    // We know Deck with seed 0 produces exactly 4 suits * 13 values
    // So we can just split into 4 rows of 13.
    final rows = <Widget>[];
    for (int i = 0; i < 4; i++) {
      final rowCards = allCards.sublist(i * 13, (i + 1) * 13);
      final rowWidgets = rowCards.map((card) {
        final isUsed = selectedCards.contains(card);
        return Expanded(
          child: GestureDetector(
            onTap: isUsed ? null : () => _onCardSelectedFromKeyboard(card),
            child: Opacity(
              opacity: isUsed ? 0.3 : 1.0,
              child: Container(
                margin: const EdgeInsets.all(1.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Image.asset(card.assetPath, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      }).toList();

      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: rowWidgets,
        ),
      );
    }

    return GestureDetector(
      onTap:
          () {}, // Consume tap to prevent background GestureDetector from hiding keyboard
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(
                          maxHeight: 32,
                          maxWidth: 32,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: _hideKeyboard,
                        icon: const Icon(
                          Icons.keyboard_hide,
                          color: Colors.grey,
                          size: 20,
                        ),
                        tooltip: 'Hide Keyboard',
                      ),
                      const Spacer(),
                      IconButton(
                        constraints: const BoxConstraints(
                          maxHeight: 32,
                          maxWidth: 32,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => _onCardSelectedFromKeyboard(null),
                        icon: const Icon(
                          Icons.backspace,
                          color: Colors.grey,
                          size: 20,
                        ),
                        tooltip: 'Clear Slot',
                      ),
                    ],
                  ),
                ),
                ...rows,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Simulation number',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<int>(
                      groupValue: _maxSimulations,
                      onChanged: (value) {
                        if (value == null || value == _maxSimulations) return;
                        setState(() {
                          _maxSimulations = value;
                          UserSettings.instance.equity.simulations = value;
                          _recalculate();
                        });
                        setModalState(() {});
                      },
                      child: Column(
                        children: [
                          for (final count in EquitySettings.simulationCounts)
                            RadioListTile<int>(
                              contentPadding: EdgeInsets.zero,
                              title: Text(_simulationCountLabel(count)),
                              value: count,
                            ),
                        ],
                      ),
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

  String _simulationCountLabel(int count) => '${count ~/ 1000}k';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentSelection == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _hideKeyboard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Equity Calculator'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: _showSettings,
            ),
          ],
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: _hideKeyboard,
            behavior: HitTestBehavior.translucent,
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildBoard(),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Hands',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_isCalculating || _progress != null)
                              Text(
                                'Simulations: ${_progress?.simulations ?? 0}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildHands(),
                      ],
                    ),
                  ),
                ),
                _buildKeyboard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
