import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/utils/chart_parser.dart';
import 'package:yaml/yaml.dart';

void main() {
  late PositionChart utg;

  setUpAll(() {
    final yamlString = File(
      'assets/6max_100_nl100_3bb_opr.yaml',
    ).readAsStringSync();
    utg = ChartParser.parse(loadYaml(yamlString), 'UTG');
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
