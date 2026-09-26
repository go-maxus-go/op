import 'package:flutter/material.dart' hide Card;
import 'utils/range_parser.dart';
import 'theme.dart';
import 'card.dart';

class RangeSelectorScreen extends StatefulWidget {
  final Set<String> initialRange;

  const RangeSelectorScreen({super.key, required this.initialRange});

  @override
  State<RangeSelectorScreen> createState() => _RangeSelectorScreenState();
}

class _RangeSelectorScreenState extends State<RangeSelectorScreen> {
  late Set<String> _selectedCombos;
  bool _isSelecting = true;
  final Set<String> _draggedHands = {};
  String? _activeHand;

  @override
  void initState() {
    super.initState();
    _selectedCombos = Set<String>.from(widget.initialRange);
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

  List<String> _getCombosForHand(String hand) {
    if (hand.length == 2) {
      final r = hand[0];
      return ['${r}s${r}h', '${r}s${r}c', '${r}s${r}d', '${r}h${r}c', '${r}h${r}d', '${r}c${r}d'];
    } else if (hand.endsWith('s')) {
      final r1 = hand[0];
      final r2 = hand[1];
      return ['${r1}s${r2}s', '${r1}h${r2}h', '${r1}c${r2}c', '${r1}d${r2}d'];
    } else {
      final r1 = hand[0];
      final r2 = hand[1];
      final suits = ['s', 'h', 'c', 'd'];
      final combos = <String>[];
      for (var s1 in suits) {
        for (var s2 in suits) {
          if (s1 != s2) {
            combos.add('$r1$s1$r2$s2');
          }
        }
      }
      return combos;
    }
  }

  List<List<String>> _getComboLayoutForHand(String hand) {
    if (hand.length == 2) {
      final r = hand[0];
      return [
        ['${r}s${r}h', '${r}s${r}c', '${r}s${r}d'],
        ['${r}h${r}c', '${r}h${r}d', '${r}c${r}d'],
      ];
    } else if (hand.endsWith('s')) {
      final r1 = hand[0];
      final r2 = hand[1];
      return [
        ['${r1}s${r2}s', '${r1}h${r2}h', '${r1}c${r2}c', '${r1}d${r2}d'],
      ];
    } else {
      final r1 = hand[0];
      final r2 = hand[1];
      return [
        ['${r1}s${r2}h', '${r1}s${r2}c', '${r1}s${r2}d'],
        ['${r1}h${r2}s', '${r1}h${r2}c', '${r1}h${r2}d'],
        ['${r1}c${r2}s', '${r1}c${r2}h', '${r1}c${r2}d'],
        ['${r1}d${r2}s', '${r1}d${r2}h', '${r1}d${r2}c'],
      ];
    }
  }

  void _handleDrag(Offset localPosition, double gridSize) {
    final double cellSize = (gridSize - 12) / 13;
    final int col = (localPosition.dx / (cellSize + 1)).floor();
    final int row = (localPosition.dy / (cellSize + 1)).floor();

    if (row >= 0 && row < 13 && col >= 0 && col < 13) {
      String hand = _getHandAt(row, col);
      if (!_draggedHands.contains(hand)) {
        _draggedHands.add(hand);
        setState(() {
          _activeHand = hand;
          final combos = _getCombosForHand(hand);
          if (_isSelecting) {
            _selectedCombos.addAll(combos);
          } else {
            _selectedCombos.removeAll(combos);
          }
        });
      }
    }
  }

  void _startDrag(Offset localPosition, double gridSize) {
    final double cellSize = (gridSize - 12) / 13;
    final int col = (localPosition.dx / (cellSize + 1)).floor();
    final int row = (localPosition.dy / (cellSize + 1)).floor();

    if (row >= 0 && row < 13 && col >= 0 && col < 13) {
      String hand = _getHandAt(row, col);
      final combos = _getCombosForHand(hand);
      _isSelecting = !combos.every((c) => _selectedCombos.contains(c));
      _draggedHands.clear();
      _handleDrag(localPosition, gridSize);
    }
  }

  void _clearRange() {
    setState(() {
      _selectedCombos.clear();
      _activeHand = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chartColors = Theme.of(context).extension<ChartColors>()!;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Range'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearRange,
            tooltip: 'Clear Range',
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, _selectedCombos);
            },
            tooltip: 'Done',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = constraints.maxWidth;
                    // Cap at 800 for desktop, otherwise take full width
                    final gridSize = screenWidth > 800 ? 800.0 : screenWidth;

                    return Center(
                      child: Listener(
                        onPointerDown: (event) => _startDrag(event.localPosition, gridSize),
                        onPointerMove: (event) => _handleDrag(event.localPosition, gridSize),
                        onPointerUp: (event) => _draggedHands.clear(),
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
                              final combos = _getCombosForHand(hand);
                              final selectedCount = combos.where((c) => _selectedCombos.contains(c)).length;
                              final isFullySelected = selectedCount == combos.length;
                              final isPartiallySelected = selectedCount > 0 && selectedCount < combos.length;
                              final isSelected = selectedCount > 0;

                              Color selectedColor;
                              if (row == col) {
                                selectedColor = chartColors.pairColor;
                              } else if (col > row) {
                                selectedColor = chartColors.suitedColor;
                              } else {
                                selectedColor = chartColors.offsuitColor;
                              }

                              BoxDecoration decoration;
                              if (isFullySelected) {
                                decoration = BoxDecoration(
                                  color: selectedColor,
                                  borderRadius: BorderRadius.circular(2),
                                  border: _activeHand == hand ? Border.all(color: Colors.white, width: 2) : null,
                                );
                              } else if (isPartiallySelected) {
                                decoration = BoxDecoration(
                                  color: selectedColor.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(2),
                                  border: _activeHand == hand ? Border.all(color: Colors.white, width: 2) : null,
                                );
                              } else {
                                decoration = BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(2),
                                  border: _activeHand == hand ? Border.all(color: Colors.white, width: 2) : null,
                                );
                              }

                              return Container(
                                decoration: decoration,
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      hand,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : null,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Builder(
                  builder: (context) {
                    double percentage = (_selectedCombos.length / 1326) * 100;
                    return Text(
                      'Selected: ${percentage.toStringAsFixed(2)}%',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              if (_activeHand != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Combinations for $_activeHand', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final comboRows = _getComboLayoutForHand(_activeHand!);
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: comboRows.map((row) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: row.map((combo) {
                                      final isSelected = _selectedCombos.contains(combo);
                                      final c1 = Card(combo[0], combo[1]);
                                      final c2 = Card(combo[2], combo[3]);

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedCombos.remove(combo);
                                            } else {
                                              _selectedCombos.add(combo);
                                            }
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.blue.withValues(alpha: 0.2)
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected ? Colors.blue : Colors.grey,
                                              width: isSelected ? 2 : 1,
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Image.asset(c1.assetPath, width: 45, height: 63),
                                              const SizedBox(width: 2),
                                              Image.asset(c2.assetPath, width: 45, height: 63),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
