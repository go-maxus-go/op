import 'package:flutter/material.dart';

import 'chart_screen.dart';
import 'practice_screen.dart';
import 'constants.dart';
import 'user_settings.dart';

class ChartsConfiguratorScreen extends StatefulWidget {
  const ChartsConfiguratorScreen({super.key});

  @override
  State<ChartsConfiguratorScreen> createState() =>
      _ChartsConfiguratorScreenState();
}

class _ChartsConfiguratorScreenState extends State<ChartsConfiguratorScreen> {
  static const _modes = ['Chart', 'Practice'];
  static const _charts = [
    PokerConstants.chartOPR,
    PokerConstants.chartVsOPR,
    PokerConstants.chartVs3bet,
  ];
  static const _actionOrder = [
    PokerConstants.positionUTG,
    PokerConstants.positionHJ,
    PokerConstants.positionCO,
    PokerConstants.positionBTN,
    PokerConstants.positionSB,
    PokerConstants.positionBB,
  ];

  /// Positions that can open. The big blind acts last and does not open.
  static const _openPositions = [
    PokerConstants.positionUTG,
    PokerConstants.positionHJ,
    PokerConstants.positionCO,
    PokerConstants.positionBTN,
    PokerConstants.positionSB,
  ];

  final ConfiguratorSettings _settings = UserSettings.instance.configurator;

  String _selectedMode = 'Practice';
  String _selectedPosition = 'All';
  String _selectedOpponentPosition = PokerConstants.positionUTG;
  String _selectedChart = PokerConstants.chartOPR;

  @override
  void initState() {
    super.initState();
    // Saved values may no longer be offered, so fall back to defaults.
    if (_modes.contains(_settings.mode)) _selectedMode = _settings.mode;
    if (_charts.contains(_settings.chart)) _selectedChart = _settings.chart;
    _selectedOpponentPosition = _settings.opponentPosition;
    _selectedPosition = _settings.position;
    _selectedPosition = _coerceHero(_selectedPosition);
    _selectedOpponentPosition = _coerceVillain(_selectedOpponentPosition);
  }

  /// Applies a selection change and saves the resulting configuration.
  void _update(VoidCallback change) {
    setState(() {
      change();
      _selectedPosition = _coerceHero(_selectedPosition);
      _selectedOpponentPosition = _coerceVillain(_selectedOpponentPosition);
    });
    _settings
      ..mode = _selectedMode
      ..chart = _selectedChart
      ..opponentPosition = _selectedOpponentPosition
      ..position = _selectedPosition;
  }

  bool get _showsVillain =>
      _selectedChart == PokerConstants.chartVsOPR ||
      _selectedChart == PokerConstants.chartVs3bet;

  /// Hero seats for the current chart.
  ///
  /// Vs OPR starts at HJ, since UTG acts first and cannot face an open.
  /// Vs 3bet stops at SB, since the big blind has nobody left to 3-bet them.
  List<String> _heroOptions() {
    if (_selectedChart == PokerConstants.chartVsOPR) {
      return [
        if (_selectedMode == 'Practice') 'All',
        PokerConstants.positionHJ,
        PokerConstants.positionCO,
        PokerConstants.positionBTN,
        PokerConstants.positionSB,
        PokerConstants.positionBB,
      ];
    }
    return [
      if (_selectedMode == 'Practice') 'All',
      PokerConstants.positionUTG,
      PokerConstants.positionHJ,
      PokerConstants.positionCO,
      PokerConstants.positionBTN,
      PokerConstants.positionSB,
    ];
  }

  /// Villains for the selected hero.
  ///
  /// Vs OPR: openers who act before the hero. Vs 3bet: seats who act after
  /// the hero's open, including the big blind.
  List<String> _villainOptions() {
    final heroIndex = _actionOrder.indexOf(_selectedPosition);
    if (_selectedChart == PokerConstants.chartVs3bet) {
      if (_selectedPosition == 'All') {
        return _actionOrder.sublist(1);
      }
      return _actionOrder.sublist(heroIndex + 1);
    }
    if (_selectedPosition == 'All') return _openPositions;
    return [
      for (final position in _openPositions)
        if (_actionOrder.indexOf(position) < heroIndex) position,
    ];
  }

  String _coerceHero(String position) {
    final options = _heroOptions();
    if (options.contains(position)) return position;
    return options.firstWhere((option) => option != 'All');
  }

  String _coerceVillain(String villain) {
    if (!_showsVillain) return villain;
    final options = _villainOptions();
    if (options.contains(villain)) return villain;
    return options.first;
  }

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
              _modes,
              _selectedMode,
              (val) {
                _update(() {
                  _selectedMode = val;
                  if (_selectedMode == 'Practice') {
                    _selectedPosition = 'All';
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
              'Charts',
              _charts,
              _selectedChart,
              (val) => _update(() => _selectedChart = val),
            ),
            _buildSection(
              'Hero',
              _heroOptions(),
              _selectedPosition,
              (val) => _update(() => _selectedPosition = val),
            ),
            if (_showsVillain)
              _buildSection(
                'Villain',
                _villainOptions(),
                _selectedOpponentPosition,
                (val) => _update(() => _selectedOpponentPosition = val),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                textStyle: const TextStyle(fontSize: 20),
              ),
              onPressed: () {
                final villain = _showsVillain ? _selectedOpponentPosition : null;

                if (_selectedMode == 'Practice') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PracticeScreen(
                        type: PokerConstants.type6max,
                        limit: PokerConstants.limitNL100,
                        stacks: PokerConstants.stacks100,
                        raise: PokerConstants.raise3bb,
                        position: _selectedPosition,
                        chart: _selectedChart,
                        villain: villain,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChartScreen(
                        type: PokerConstants.type6max,
                        limit: PokerConstants.limitNL100,
                        stacks: PokerConstants.stacks100,
                        raise: PokerConstants.raise3bb,
                        position: _selectedPosition,
                        chart: _selectedChart,
                        villain: villain,
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
