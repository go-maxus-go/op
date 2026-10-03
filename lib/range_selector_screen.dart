import 'package:flutter/material.dart' hide Card;
import 'utils/range_parser.dart';
import 'card.dart';
import 'range_chart.dart';
import 'range_editor_screen.dart';

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
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _selectedCombos = Set<String>.from(widget.initialRange);
  }

  String _selectedPercentText() {
    final percentage = (_selectedCombos.length / 1326) * 100;
    return '${percentage.toStringAsFixed(2)}%';
  }

  void _openRangeEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RangeEditorScreen(
          initialName: _selectedPercentText(),
          initialHands: RangeParser.rangeFromCombos(_selectedCombos),
          onHandsChanged: (combos) {
            setState(() {
              _selectedCombos = combos;
            });
          },
        ),
      ),
    );
  }

  void _handleDrag(Offset localPosition, double gridSize) {
    final double cellSize = (gridSize - 12) / 13;
    final int col = (localPosition.dx / (cellSize + 1)).floor();
    final int row = (localPosition.dy / (cellSize + 1)).floor();

    if (row >= 0 && row < 13 && col >= 0 && col < 13) {
      String hand = RangeChart.handAt(row, col);
      if (!_draggedHands.contains(hand)) {
        _draggedHands.add(hand);
        setState(() {
          _activeHand = hand;
          if (_isLocked) return;
          final combos = RangeChart.combosForHand(hand);
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
      String hand = RangeChart.handAt(row, col);
      final combos = RangeChart.combosForHand(hand);
      _isSelecting = !combos.every((c) => _selectedCombos.contains(c));
      _draggedHands.clear();
      _handleDrag(localPosition, gridSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Set<String>>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _selectedCombos);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select Range'),
          actions: [
            IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Clear Range',
              onPressed: _selectedCombos.isEmpty
                  ? null
                  : () => setState(() => _selectedCombos = {}),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_note),
                        tooltip: 'Range',
                        visualDensity: VisualDensity.compact,
                        onPressed: _openRangeEditor,
                      ),
                      Text(
                        'Selected: ${_selectedPercentText()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(_isLocked ? Icons.lock : Icons.lock_open),
                        tooltip: _isLocked ? 'Unlock Range' : 'Lock Range',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _isLocked = !_isLocked),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = constraints.maxWidth;
                      // Cap at 800 for desktop, otherwise take full width
                      final gridSize = screenWidth > 800 ? 800.0 : screenWidth;

                      return Center(
                        child: Listener(
                          onPointerDown: (event) =>
                              _startDrag(event.localPosition, gridSize),
                          onPointerMove: (event) =>
                              _handleDrag(event.localPosition, gridSize),
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
                                final hand = RangeChart.handAt(row, col);
                                final isSelected =
                                    RangeChart.selectedCount(
                                      hand,
                                      _selectedCombos,
                                    ) >
                                    0;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: RangeChart.cellColor(
                                      context: context,
                                      row: row,
                                      col: col,
                                      selectedCombos: _selectedCombos,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                    border: _activeHand == hand
                                        ? Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        hand,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : null,
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
                if (_activeHand != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Combinations for $_activeHand',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final comboRows = RangeParser.comboLayoutForHand(
                              _activeHand!,
                            );
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: comboRows.map((row) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: row.map((combo) {
                                        final isSelected = _selectedCombos
                                            .contains(combo);
                                        final c1 = Card(combo[0], combo[1]);
                                        final c2 = Card(combo[2], combo[3]);

                                        return GestureDetector(
                                          onTap: _isLocked
                                              ? null
                                              : () {
                                                  setState(() {
                                                    if (isSelected) {
                                                      _selectedCombos.remove(
                                                        combo,
                                                      );
                                                    } else {
                                                      _selectedCombos.add(
                                                        combo,
                                                      );
                                                    }
                                                  });
                                                },
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 4.0,
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.blue.withValues(
                                                      alpha: 0.2,
                                                    )
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: isSelected
                                                    ? Colors.blue
                                                    : Colors.grey,
                                                width: isSelected ? 2 : 1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Image.asset(
                                                  c1.assetPath,
                                                  width: 45,
                                                  height: 63,
                                                ),
                                                const SizedBox(width: 2),
                                                Image.asset(
                                                  c2.assetPath,
                                                  width: 45,
                                                  height: 63,
                                                ),
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
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
