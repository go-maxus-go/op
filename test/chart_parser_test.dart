import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/utils/chart_parser.dart';
import 'package:yaml/yaml.dart';

void main() {
  late PositionChart utg;
  late PositionChart hjVsUtg;

  PositionChart load(String chart, String position) {
    final path = ChartParser.assetPath(
      type: '6max',
      stacks: '100',
      limit: 'NL100',
      raise: '3bb',
      chart: chart,
    );
    return ChartParser.parse(loadYaml(File(path).readAsStringSync()), position);
  }

  setUpAll(() {
    utg = load('OPR', 'UTG');
    hjVsUtg = load('vs_UTG_opr', 'HJ');
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

  test('The first declared action wins for overlapping ranges', () {
    expect(hjVsUtg.actionForCombo('7s7h'), 'Raise 9bb');
    expect(hjVsUtg.actionForCombo('AsAh'), 'Raise 9bb');
    expect(hjVsUtg.actionForCombo('6s6h'), 'Call 3bb');
    expect(hjVsUtg.actionForCombo('2s2h'), 'Call 3bb');
    expect(hjVsUtg.actionForCombo('As2s'), 'Call 3bb');
    expect(hjVsUtg.actionForCombo('AsJh'), 'Call 3bb');
    expect(hjVsUtg.actionForCombo('AsTh'), PositionChart.foldLabel);
  });

  test('A declared fold keeps its combos from later actions', () {
    final chart = ChartParser.parse(
      loadYaml('HJ:\n  - Fold: AA\n  - Call 3bb: QQ+'),
      'HJ',
    );
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
