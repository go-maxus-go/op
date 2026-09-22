import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/utils/range_parser.dart';

void main() {
  test('Parses single hands', () {
    expect(RangeParser.parseHandRange('54s'), ['54s']);
    expect(RangeParser.parseHandRange('AKo'), ['AKo']);
    expect(RangeParser.parseHandRange('88'), ['88']);
  });

  test('Parses pairs with +', () {
    expect(RangeParser.parseHandRange('QQ+'), ['QQ', 'KK', 'AA']);
    expect(RangeParser.parseHandRange('22+').length, 13); // All pairs
  });

  test('Parses consecutive suited with +', () {
    expect(RangeParser.parseHandRange('JTs+'), ['JTs', 'QJs', 'KQs', 'AKs']);
  });

  test('Parses unconnected suited/offsuit with +', () {
    expect(RangeParser.parseHandRange('AJo+'), ['AJo', 'AQo', 'AKo']);
    expect(RangeParser.parseHandRange('K9s+'), ['K9s', 'KTs', 'KJs', 'KQs']);
  });

  test('Parses line with multiple hands', () {
    expect(RangeParser.parseLine('54s, 65s, 76s'), ['54s', '65s', '76s']);
    expect(RangeParser.parseLine('88+, AJo+'), ['88', '99', 'TT', 'JJ', 'QQ', 'KK', 'AA', 'AJo', 'AQo', 'AKo']);
  });
}
