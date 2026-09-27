import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/utils/range_parser.dart';

import 'package:optimal_poker/hand.dart';
import 'package:optimal_poker/card.dart';

void main() {
  test('Expands a raw hand', () {
    expect(RangeParser.expandRange('5s4s'), ['5s4s']);
    expect(RangeParser.expandRange('AhKd'), ['AhKd']);
    expect(RangeParser.expandRange('8c8h'), ['8c8h']);
  });

  test('Expands a pair', () {
    expect(RangeParser.expandRange('QQ'), [
      'QsQh',
      'QsQc',
      'QsQd',
      'QhQc',
      'QhQd',
      'QcQd',
    ]);
  });

  test('Expands a pair plus', () {
    expect(RangeParser.expandRange('QQ+'), [
      'AsAh',
      'AsAc',
      'AsAd',
      'AhAc',
      'AhAd',
      'AcAd',

      'KsKh',
      'KsKc',
      'KsKd',
      'KhKc',
      'KhKd',
      'KcKd',

      'QsQh',
      'QsQc',
      'QsQd',
      'QhQc',
      'QhQd',
      'QcQd',
    ]);
  });

  test('Expands an offsuit', () {
    expect(RangeParser.expandRange('AKo'), [
      'AsKh',
      'AsKc',
      'AsKd',
      'AhKs',
      'AhKc',
      'AhKd',
      'AcKs',
      'AcKh',
      'AcKd',
      'AdKs',
      'AdKh',
      'AdKc',
    ]);
  });

  test('Expands an offsuit plus', () {
    expect(RangeParser.expandRange('QTo+'), [
      'QsJh',
      'QsJc',
      'QsJd',
      'QhJs',
      'QhJc',
      'QhJd',
      'QcJs',
      'QcJh',
      'QcJd',
      'QdJs',
      'QdJh',
      'QdJc',

      'QsTh',
      'QsTc',
      'QsTd',
      'QhTs',
      'QhTc',
      'QhTd',
      'QcTs',
      'QcTh',
      'QcTd',
      'QdTs',
      'QdTh',
      'QdTc',
    ]);
  });

  test('Expands a suit', () {
    expect(RangeParser.expandRange('AKs'), ['AsKs', 'AhKh', 'AcKc', 'AdKd']);
  });

  test('Expands a suit plus', () {
    expect(RangeParser.expandRange('J8s+'), [
      'JsTs',
      'JhTh',
      'JcTc',
      'JdTd',
      'Js9s',
      'Jh9h',
      'Jc9c',
      'Jd9d',
      'Js8s',
      'Jh8h',
      'Jc8c',
      'Jd8d',
    ]);
  });

  test('Range to hands', () {
    expect(RangeParser.rangeToHands('AKs'), [
      Hand(Card('A', 's'), Card('K', 's')),
      Hand(Card('A', 'h'), Card('K', 'h')),
      Hand(Card('A', 'c'), Card('K', 'c')),
      Hand(Card('A', 'd'), Card('K', 'd')),
    ]);
  });

  test('Parse hand range (collapsed)', () {
    expect(RangeParser.parseHandRange('QQ+'), ['AA', 'KK', 'QQ']);
    expect(RangeParser.parseHandRange('AKs, 88'), ['AKs', '88']);
    expect(RangeParser.parseHandRange('QTo+'), ['QJo', 'QTo']);
  });

  test('Range from combos collapses consecutive hands', () {
    expect(
      RangeParser.rangeFromCombos(RangeParser.expandRange('QQ+')),
      'QQ+',
    );
    expect(
      RangeParser.rangeFromCombos(RangeParser.expandRange('AKs, 88')),
      '88, AKs',
    );
    expect(
      RangeParser.rangeFromCombos(RangeParser.expandRange('QTo+')),
      'QTo+',
    );
    expect(
      RangeParser.rangeFromCombos(RangeParser.expandRange('J8s+')),
      'J8s+',
    );
  });

  test('Range from combos lists partial combo selections', () {
    expect(RangeParser.rangeFromCombos(['AhKd']), 'AhKd');
    expect(RangeParser.rangeFromCombos(['KdAh']), 'AhKd');
  });

  test('Range from combos does not plus-collapse when a gap exists', () {
    expect(
      RangeParser.rangeFromCombos(RangeParser.expandRange('KK, QQ')),
      'KK, QQ',
    );
  });
}
