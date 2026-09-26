import 'package:flutter/material.dart';
import 'utils/range_parser.dart';

class RangeSelectorScreen extends StatefulWidget {
  final Set<String> initialRange;

  const RangeSelectorScreen({super.key, required this.initialRange});

  @override
  State<RangeSelectorScreen> createState() => _RangeSelectorScreenState();
}

class _RangeSelectorScreenState extends State<RangeSelectorScreen> {
  late Set<String> _selectedHands;
  bool _isSelecting = true;
  final Set<String> _draggedHands = {};

  @override
  void initState() {
    super.initState();
    _selectedHands = Set<String>.from(widget.initialRange);
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

  void _handleDrag(Offset localPosition, double gridSize) {
    final double cellSize = (gridSize - 12) / 13;
    final int col = (localPosition.dx / (cellSize + 1)).floor();
    final int row = (localPosition.dy / (cellSize + 1)).floor();

    if (row >= 0 && row < 13 && col >= 0 && col < 13) {
      String hand = _getHandAt(row, col);
      if (!_draggedHands.contains(hand)) {
        _draggedHands.add(hand);
        setState(() {
          if (_isSelecting) {
            _selectedHands.add(hand);
          } else {
            _selectedHands.remove(hand);
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
      _isSelecting = !_selectedHands.contains(hand);
      _draggedHands.clear();
      _handleDrag(localPosition, gridSize);
    }
  }

  void _clearRange() {
    setState(() {
      _selectedHands.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
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
              Navigator.pop(context, _selectedHands);
            },
            tooltip: 'Done',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gridSize = constraints.maxWidth < constraints.maxHeight
                      ? constraints.maxWidth
                      : constraints.maxHeight;

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
                            bool isSelected = _selectedHands.contains(hand);

                            Color selectedColor;
                            if (row == col) {
                              selectedColor = Colors.amber.shade800;
                            } else if (col > row) {
                              selectedColor = Colors.green.shade800;
                            } else {
                              selectedColor = Colors.purple.shade800;
                            }

                            return Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? selectedColor
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(2),
                              ),
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
              padding: const EdgeInsets.all(16.0),
              child: Builder(
                builder: (context) {
                  int combos = 0;
                  for (String hand in _selectedHands) {
                    if (hand.endsWith('s')) {
                      combos += 4;
                    } else if (hand.endsWith('o')) {
                      combos += 12;
                    } else {
                      combos += 6;
                    }
                  }
                  double percentage = (combos / 1326) * 100;
                  return Text(
                    'Selected: ${percentage.toStringAsFixed(2)}%',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
