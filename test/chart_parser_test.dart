import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/utils/chart_parser.dart';
import 'package:yaml/yaml.dart';

PositionChart _parse(String yaml, String position) {
  return ChartParser.parse(loadYaml(yaml), position);
}

void main() {
  late PositionChart utg;
  late PositionChart hj;

  setUpAll(() {
    utg = _parse('''
UTG:
  - Raise 3bb: 88+, 7s7c, 7h7c, 7c7d, A2s+, ATo+, Tc9c
''', 'UTG');
    hj = _parse('''
HJ:
  - Raise 9bb: 77+
  - Call 3bb: A2s+, AJo+, 22+
''', 'HJ');
  });

  test('Asset paths follow the chart directory layout', () {
    String path(String chart) => ChartParser.assetPath(
      type: '6max',
      stacks: '100',
      limit: 'NL100',
      raise: '3bb',
      chart: chart,
    );
    expect(path('OPR'), 'assets/6max/100bb/OPR/nl100_3bb.yaml');
    expect(path('vs_UTG_opr'), 'assets/6max/100bb/vs_OPR/UTG/nl100_3bb.yaml');
  });

  test('Every chart asset parses', () {
    final files = Directory('assets/6max')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml'));
    expect(files, isNotEmpty);
    for (final file in files) {
      final doc = loadYaml(file.readAsStringSync()) as YamlMap;
      for (final position in doc.keys.where((k) => k != 'config')) {
        final chart = ChartParser.parse(doc, position as String);
        expect(chart.comboActions, isNotEmpty, reason: file.path);
      }
    }
  });

  test('The first declared action wins for overlapping ranges', () {
    expect(hj.actionForCombo('7s7h'), 'Raise 9bb');
    expect(hj.actionForCombo('AsAh'), 'Raise 9bb');
    expect(hj.actionForCombo('6s6h'), 'Call 3bb');
    expect(hj.actionForCombo('2s2h'), 'Call 3bb');
    expect(hj.actionForCombo('As2s'), 'Call 3bb');
    expect(hj.actionForCombo('AsJh'), 'Call 3bb');
    expect(hj.actionForCombo('AsTh'), PositionChart.foldLabel);
  });

  test('A declared fold keeps its combos from later actions', () {
    final chart = _parse('HJ:\n  - Fold: AA\n  - Call 3bb: QQ+', 'HJ');
    expect(chart.actionForCombo('AsAh'), PositionChart.foldLabel);
    expect(chart.actionForCombo('KsKh'), 'Call 3bb');
  });

  test('Hands in the raise range are raises', () {
    expect(utg.actionForCombo('AsAh'), 'Raise 3bb');
    expect(utg.actionForCombo('AsKs'), 'Raise 3bb');
    expect(utg.actionForCombo('AsTh'), 'Raise 3bb');
    expect(utg.actionWeightsForHand('AA'), {'Raise 3bb': 100});
    expect(utg.actionWeightsForHand('AKs'), {'Raise 3bb': 100});
  });

  test('Hands not in the raise range are folded', () {
    expect(utg.actionForCombo('2s2h'), PositionChart.foldLabel);
    expect(utg.actionWeightsForHand('22'), {PositionChart.foldLabel: 100});
    expect(utg.actionForCombo('As9h'), PositionChart.foldLabel);
  });

  test('Partial combo ranges mix raise and fold on the same grid hand', () {
    expect(utg.actionForCombo('7s7c'), 'Raise 3bb');
    expect(utg.actionForCombo('7s7h'), PositionChart.foldLabel);
    expect(utg.actionWeightsForHand('77'), {
      'Raise 3bb': 50,
      PositionChart.foldLabel: 50,
    });
    expect(utg.actionForCombo('Tc9c'), 'Raise 3bb');
    expect(utg.actionForCombo('Ts9s'), PositionChart.foldLabel);
    expect(utg.actionWeightsForHand('T9s'), {
      'Raise 3bb': 25,
      PositionChart.foldLabel: 75,
    });
  });
}
