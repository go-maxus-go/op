import 'package:flutter/material.dart' hide Card;
import 'utils/range_parser.dart';
import 'card.dart';
import 'range_chart.dart';
import 'user_settings.dart';

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
  late final TextEditingController _handsController;
  String? _handsError;

  /// Name of the saved range last loaded or saved, offered when saving again.
  String? _rangeName;

  final RangeSettings _ranges = UserSettings.instance.ranges;

  @override
  void initState() {
    super.initState();
    _selectedCombos = Set<String>.from(widget.initialRange);
    _handsController = TextEditingController(
      text: RangeParser.rangeFromCombos(_selectedCombos),
    );
  }

  @override
  void dispose() {
    _handsController.dispose();
    super.dispose();
  }

  String _selectedPercentText() {
    final percentage = (_selectedCombos.length / 1326) * 100;
    return '${percentage.toStringAsFixed(2)}%';
  }

  /// Rewrites the hands field from the combos selected on the chart.
  void _syncHandsText() {
    _handsError = null;
    final text = RangeParser.rangeFromCombos(_selectedCombos);
    if (_handsController.text == text) return;
    _handsController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onHandsChanged(String value) {
    try {
      final combos = RangeParser.expandRangeToComboSet(value);
      setState(() {
        _handsError = null;
        _selectedCombos = combos;
      });
    } catch (_) {
      setState(() => _handsError = 'Invalid range');
    }
  }

  void _finishHandsEditing() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_handsError == null) setState(_syncHandsText);
  }

  void _clearRange() {
    setState(() {
      _selectedCombos = {};
      _rangeName = null;
      _syncHandsText();
    });
  }

  void _loadRange(SavedRange range) {
    setState(() {
      _selectedCombos = RangeParser.expandRangeToComboSet(range.hands);
      _rangeName = range.name;
      _syncHandsText();
    });
  }

  Future<void> _saveRange() async {
    final result = await showDialog<_RangeNameResult>(
      context: context,
      builder: (context) => _RangeNameDialog(
        title: 'Save Range',
        initialName: _rangeName ?? '',
        nameTaken: (name) => _ranges.contains(name),
        replacesTakenName: true,
      ),
    );
    final name = result?.name;
    if (!mounted || name == null) return;
    setState(() {
      _ranges.save(name, RangeParser.rangeFromCombos(_selectedCombos));
      _rangeName = name;
    });
  }

  Future<void> _editRange(SavedRange range) async {
    final result = await showDialog<_RangeNameResult>(
      context: context,
      builder: (context) => _RangeNameDialog(
        title: 'Edit Range',
        initialName: range.name,
        nameTaken: (name) => name != range.name && _ranges.contains(name),
        replacesTakenName: false,
        canDelete: true,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result.delete) {
        _ranges.remove(range.name);
        if (_rangeName == range.name) _rangeName = null;
      } else if (result.name != null && result.name != range.name) {
        _ranges.rename(range.name, result.name!);
        if (_rangeName == range.name) _rangeName = result.name;
      }
    });
  }

  Widget _buildHandsEditor() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _handsController,
              onChanged: _onHandsChanged,
              onEditingComplete: _finishHandsEditing,
              onTapOutside: (_) => _finishHandsEditing(),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'AKs, QQ+, 87s',
                labelText: 'Range hands',
                errorText: _handsError,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _selectedCombos.isEmpty || _handsError != null
                ? null
                : _saveRange,
            icon: const Icon(Icons.save),
            tooltip: 'Save Range',
          ),
        ],
      ),
    );
  }

  Widget _buildSavedRanges() {
    final ranges = _ranges.saved;
    if (ranges.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Saved ranges',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        for (final range in ranges)
          Builder(
            builder: (context) {
              final combos = RangeParser.expandRangeToComboSet(range.hands);
              final percent = combos.length / 1326 * 100;
              return ListTile(
                leading: RangeChartImage(range: combos, size: 40),
                title: Text(range.name),
                trailing: Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                selected: range.name == _rangeName,
                onTap: () => _loadRange(range),
                onLongPress: () => _editRange(range),
              );
            },
          ),
      ],
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
          _syncHandsText();
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
              onPressed: _selectedCombos.isEmpty ? null : _clearRange,
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
                        icon: Icon(_isLocked ? Icons.lock : Icons.lock_open),
                        tooltip: _isLocked ? 'Unlock Range' : 'Lock Range',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _isLocked = !_isLocked),
                      ),
                      Text(
                        'Selected: ${_selectedPercentText()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                                    gradient: RangeChart.cellGradient(
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
                                                    _syncHandsText();
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
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [_buildHandsEditor(), _buildSavedRanges()],
                    ),
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

class _RangeNameResult {
  const _RangeNameResult.named(String this.name) : delete = false;
  const _RangeNameResult.delete() : name = null, delete = true;

  final String? name;
  final bool delete;
}

class _RangeNameDialog extends StatefulWidget {
  const _RangeNameDialog({
    required this.title,
    required this.initialName,
    required this.nameTaken,
    required this.replacesTakenName,
    this.canDelete = false,
  });

  final String title;
  final String initialName;
  final bool Function(String name) nameTaken;

  /// Whether a taken name may be used, replacing that range, or is an error.
  final bool replacesTakenName;
  final bool canDelete;

  @override
  State<_RangeNameDialog> createState() => _RangeNameDialogState();
}

class _RangeNameDialogState extends State<_RangeNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialName.length,
        );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();

  bool get _isTaken => _name.isNotEmpty && widget.nameTaken(_name);

  bool get _canSave =>
      _name.isNotEmpty && (!_isTaken || widget.replacesTakenName);

  void _submit() {
    if (_canSave) Navigator.pop(context, _RangeNameResult.named(_name));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Range name',
          border: const OutlineInputBorder(),
          errorText: _isTaken && !widget.replacesTakenName
              ? 'A range with this name already exists'
              : null,
        ),
      ),
      actionsAlignment: widget.canDelete
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.end,
      actions: [
        if (widget.canDelete)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () =>
                Navigator.pop(context, const _RangeNameResult.delete()),
            child: const Text('Delete'),
          ),
        if (_isTaken && widget.replacesTakenName)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: _submit,
            child: const Text('Rewrite'),
          )
        else
          FilledButton(
            onPressed: _canSave ? _submit : null,
            child: const Text('Save'),
          ),
      ],
    );
  }
}
