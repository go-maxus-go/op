import 'package:flutter/material.dart';

import 'chart_screen.dart';
import 'constants.dart';

class ChartsConfiguratorScreen extends StatefulWidget {
  const ChartsConfiguratorScreen({super.key});

  @override
  State<ChartsConfiguratorScreen> createState() => _ChartsConfiguratorScreenState();
}

class _ChartsConfiguratorScreenState extends State<ChartsConfiguratorScreen> {
  String _selectedLimit = PokerConstants.limitNL50;
  String _selectedPosition = PokerConstants.positionUTG;
  String _selectedChart = PokerConstants.chartOPR;

  Widget _buildSection(
    String title,
    List<String> options,
    String selectedValue,
    ValueChanged<String>? onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                if (selected && onChanged != null) {
                  onChanged(option);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chart Configuration'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection('Type', [PokerConstants.type6max], PokerConstants.type6max, null),
            _buildSection(
              'Limit',
              [PokerConstants.limitNL50, PokerConstants.limitNL100, PokerConstants.limitNL200],
              _selectedLimit,
              (val) => setState(() => _selectedLimit = val),
            ),
            _buildSection('Stacks', [PokerConstants.stacks100], PokerConstants.stacks100, null),
            _buildSection('Raise', [PokerConstants.raise3bb], PokerConstants.raise3bb, null),
            _buildSection(
              'Position',
              [
                PokerConstants.positionUTG,
                PokerConstants.positionHJ,
                PokerConstants.positionCO,
                PokerConstants.positionBTN,
                PokerConstants.positionSB,
                PokerConstants.positionBB,
              ],
              _selectedPosition,
              (val) => setState(() => _selectedPosition = val),
            ),
            _buildSection(
              'Charts',
              [
                PokerConstants.chartOPR,
                PokerConstants.chartCall,
                PokerConstants.chart3bet,
                PokerConstants.chart4bet,
              ],
              _selectedChart,
              (val) => setState(() => _selectedChart = val),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                textStyle: const TextStyle(fontSize: 20),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChartScreen(
                      type: PokerConstants.type6max,
                      limit: _selectedLimit,
                      stacks: PokerConstants.stacks100,
                      raise: PokerConstants.raise3bb,
                      position: _selectedPosition,
                      chart: _selectedChart,
                    ),
                  ),
                );
              },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

