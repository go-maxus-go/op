import 'package:flutter/material.dart';

import 'chart_screen.dart';
import 'practice_screen.dart';
import 'constants.dart';

class ChartsConfiguratorScreen extends StatefulWidget {
  const ChartsConfiguratorScreen({super.key});

  @override
  State<ChartsConfiguratorScreen> createState() =>
      _ChartsConfiguratorScreenState();
}

class _ChartsConfiguratorScreenState extends State<ChartsConfiguratorScreen> {
  String _selectedMode = 'Practice';
  String _selectedLimit = PokerConstants.limitNL100;
  String _selectedPosition = 'All';
  String _selectedOpponentPosition = PokerConstants.positionUTG;
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
        title: const Text('Preflop'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              'Mode',
              ['Chart', 'Practice'],
              _selectedMode,
              (val) {
                setState(() {
                  _selectedMode = val;
                  if (_selectedMode == 'Practice') {
                    _selectedPosition = 'All';
                  } else if (_selectedMode == 'Chart' && _selectedPosition == 'All') {
                    _selectedPosition = PokerConstants.positionUTG;
                  }
                });
              },
            ),
            _buildSection(
              'Type',
              [PokerConstants.type6max],
              PokerConstants.type6max,
              null,
            ),
            _buildSection(
              'Limit',
              [PokerConstants.limitNL100, PokerConstants.limitNL200],
              _selectedLimit,
              (val) => setState(() => _selectedLimit = val),
            ),
            _buildSection(
              'Stacks',
              [PokerConstants.stacks100],
              PokerConstants.stacks100,
              null,
            ),
            _buildSection(
              'Raise',
              [PokerConstants.raise3bb],
              PokerConstants.raise3bb,
              null,
            ),
            _buildSection(
              'Charts',
              [
                PokerConstants.chartOPR,
                PokerConstants.chartVsOPR,
                PokerConstants.chartCall,
                PokerConstants.chart3bet,
                PokerConstants.chart4bet,
              ],
              _selectedChart,
              (val) {
                setState(() {
                  _selectedChart = val;
                  if (_selectedChart == PokerConstants.chartOPR &&
                      _selectedPosition == PokerConstants.positionBB) {
                    _selectedPosition = PokerConstants.positionSB;
                  }
                  if (_selectedChart == PokerConstants.chartVsOPR) {
                    final allPos = [
                      PokerConstants.positionUTG,
                      PokerConstants.positionHJ,
                      PokerConstants.positionCO,
                      PokerConstants.positionBTN,
                      PokerConstants.positionSB,
                      PokerConstants.positionBB,
                    ];
                    final oppIndex = allPos.indexOf(_selectedOpponentPosition);
                    final heroPosIndex = allPos.indexOf(_selectedPosition);
                    if (_selectedPosition != 'All' && heroPosIndex <= oppIndex) {
                      _selectedPosition = allPos[oppIndex + 1];
                    }
                  }
                });
              },
            ),
            if (_selectedChart == PokerConstants.chartVsOPR)
              _buildSection(
                'Raiser',
                [
                  PokerConstants.positionUTG,
                  PokerConstants.positionHJ,
                  PokerConstants.positionCO,
                  PokerConstants.positionBTN,
                  PokerConstants.positionSB,
                ],
                _selectedOpponentPosition,
                (val) {
                  setState(() {
                    _selectedOpponentPosition = val;
                    final allPos = [
                      PokerConstants.positionUTG,
                      PokerConstants.positionHJ,
                      PokerConstants.positionCO,
                      PokerConstants.positionBTN,
                      PokerConstants.positionSB,
                      PokerConstants.positionBB,
                    ];
                    final oppIndex = allPos.indexOf(_selectedOpponentPosition);
                    final heroPosIndex = allPos.indexOf(_selectedPosition);
                    if (_selectedPosition != 'All' && heroPosIndex <= oppIndex) {
                      _selectedPosition = allPos[oppIndex + 1];
                    }
                  });
                },
              ),
            _buildSection(
              'Position',
              () {
                final allPos = [
                  PokerConstants.positionUTG,
                  PokerConstants.positionHJ,
                  PokerConstants.positionCO,
                  PokerConstants.positionBTN,
                  PokerConstants.positionSB,
                  PokerConstants.positionBB,
                ];
                if (_selectedChart == PokerConstants.chartVsOPR) {
                  final oppIndex = allPos.indexOf(_selectedOpponentPosition);
                  return [
                    if (_selectedMode == 'Practice') 'All',
                    ...allPos.sublist(oppIndex + 1),
                  ];
                }
                return [
                  if (_selectedMode == 'Practice') 'All',
                  PokerConstants.positionUTG,
                  PokerConstants.positionHJ,
                  PokerConstants.positionCO,
                  PokerConstants.positionBTN,
                  PokerConstants.positionSB,
                  if (_selectedChart != PokerConstants.chartOPR)
                    PokerConstants.positionBB,
                ];
              }(),
              _selectedPosition,
              (val) => setState(() => _selectedPosition = val),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                textStyle: const TextStyle(fontSize: 20),
              ),
              onPressed: () {
                final chartToPass = _selectedChart == PokerConstants.chartVsOPR
                    ? 'vs_${_selectedOpponentPosition}_opr'
                    : _selectedChart;
                    
                if (_selectedMode == 'Practice') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PracticeScreen(
                        type: PokerConstants.type6max,
                        limit: _selectedLimit,
                        stacks: PokerConstants.stacks100,
                        raise: PokerConstants.raise3bb,
                        position: _selectedPosition,
                        chart: chartToPass,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChartScreen(
                        type: PokerConstants.type6max,
                        limit: _selectedLimit,
                        stacks: PokerConstants.stacks100,
                        raise: PokerConstants.raise3bb,
                        position: _selectedPosition,
                        chart: chartToPass,
                      ),
                    ),
                  );
                }
              },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}
