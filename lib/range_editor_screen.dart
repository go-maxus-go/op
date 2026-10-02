import 'package:flutter/material.dart';

import 'utils/range_parser.dart';

class RangeEditorScreen extends StatefulWidget {
  final String initialName;
  final String initialHands;
  final ValueChanged<Set<String>> onHandsChanged;

  const RangeEditorScreen({
    super.key,
    required this.initialName,
    required this.initialHands,
    required this.onHandsChanged,
  });

  @override
  State<RangeEditorScreen> createState() => _RangeEditorScreenState();
}

class _RangeEditorScreenState extends State<RangeEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _handsController;
  String? _rangeError;
  bool _ignoreHandsChange = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _handsController = TextEditingController(text: widget.initialHands);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _handsController.dispose();
    super.dispose();
  }

  void _onHandsChanged(String value) {
    if (_ignoreHandsChange) {
      return;
    }
    try {
      final parsed = RangeParser.expandRangeToComboSet(value);
      setState(() {
        _rangeError = null;
      });
      widget.onHandsChanged(parsed);
    } catch (_) {
      setState(() {
        _rangeError = 'Invalid range';
      });
    }
  }

  void _formatHandsFromCombos() {
    if (_rangeError != null) {
      return;
    }
    final formatted = RangeParser.rangeFromCombos(
      RangeParser.expandRangeToComboSet(_handsController.text),
    );
    if (_handsController.text == formatted) {
      return;
    }
    _ignoreHandsChange = true;
    _handsController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _ignoreHandsChange = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Range')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Range name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _handsController,
                onChanged: _onHandsChanged,
                onEditingComplete: _formatHandsFromCombos,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'AKs, QQ+, 87s',
                  labelText: 'Range hands',
                  errorText: _rangeError,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
