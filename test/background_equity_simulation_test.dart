import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/background_equity_simulation.dart';
import 'package:optimal_poker/card.dart';

/// Parses concatenated cards, e.g. 'AhKd2c'.
List<Card> cards(String s) => [
  for (var i = 0; i < s.length; i += 2) Card(s[i], s[i + 1]),
];

void main() {
  test('reports progress and a final complete result', () async {
    final updates = <EquityProgress>[];
    final done = Completer<void>();
    await BackgroundEquitySimulation.start(
      hands: [cards('AhAd'), cards('KsKc')],
      board: cards('2c7d9hJc3s'),
      maxSimulations: 500,
      onProgress: (progress) {
        updates.add(progress);
        if (progress.isComplete) done.complete();
      },
    );

    await done.future.timeout(const Duration(seconds: 30));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final last = updates.last;
    expect(last.isComplete, isTrue);
    expect(last.simulations, 500);
    expect(last.equities, [1, 0]);
    expect(updates.where((p) => p.isComplete), hasLength(1));
    for (var i = 1; i < updates.length; i++) {
      expect(
        updates[i].simulations,
        greaterThanOrEqualTo(updates[i - 1].simulations),
      );
    }
  });

  test('simulates the unknown cards in the background', () async {
    final done = Completer<EquityProgress>();
    await BackgroundEquitySimulation.start(
      hands: [cards('AsAh'), cards('KdKh')],
      board: cards('2c7d9hKs'),
      maxSimulations: 5000,
      onProgress: (progress) {
        if (progress.isComplete) done.complete(progress);
      },
    );

    final result = await done.future.timeout(const Duration(seconds: 30));
    expect(result.equities[0], closeTo(2 / 44, 0.015));
  });

  test('delivers nothing after stop', () async {
    final first = Completer<void>();
    var afterStop = 0;
    var stopped = false;
    late BackgroundEquitySimulation simulation;
    simulation = await BackgroundEquitySimulation.start(
      hands: [cards('AhAd'), <Card>[]],
      board: [],
      maxSimulations: 10000000,
      updateInterval: const Duration(milliseconds: 5),
      onProgress: (_) {
        if (stopped) {
          afterStop++;
        } else if (!first.isCompleted) {
          first.complete();
        }
      },
    );

    await first.future.timeout(const Duration(seconds: 30));
    simulation.stop();
    stopped = true;
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(simulation.isStopped, isTrue);
    expect(afterStop, 0);
  });

  test('stop is safe to call more than once', () async {
    final simulation = await BackgroundEquitySimulation.start(
      hands: [cards('AhAd'), <Card>[]],
      board: [],
      maxSimulations: 10000000,
      onProgress: (_) {},
    );
    simulation.stop();
    expect(simulation.stop, returnsNormally);
  });

  test('rejects an invalid deal before starting a worker', () {
    expect(
      () => BackgroundEquitySimulation.start(
        hands: [cards('AhAd'), cards('AhKd')],
        board: [],
        maxSimulations: 10,
        onProgress: (_) {},
      ),
      throwsArgumentError,
    );
  });
}
