import 'dart:async';
import 'dart:isolate';

import 'card.dart';
import 'equity_simulator.dart';

/// Progress of a background simulation: equities after [simulations] runs.
class EquityProgress {
  final int simulations;
  final List<double> equities;
  final bool isComplete;

  const EquityProgress(this.simulations, this.equities, this.isComplete);
}

/// Runs an [EquitySimulator] on a separate isolate so the UI thread stays free.
///
/// [onProgress] is called on the caller's isolate, at most once per
/// [updateInterval] and once more when the simulation completes. After [stop]
/// no further callbacks are delivered.
class BackgroundEquitySimulation {
  final void Function(EquityProgress progress) onProgress;
  final void Function(Object error)? onError;

  final ReceivePort _port = ReceivePort();
  Isolate? _isolate;
  var _stopped = false;

  BackgroundEquitySimulation._(this.onProgress, this.onError);

  /// Validates the deal and starts simulating it in the background.
  ///
  /// Throws [ArgumentError] synchronously when the deal is invalid.
  static Future<BackgroundEquitySimulation> start({
    required List<String> ranges,
    required List<Card> board,
    required int maxSimulations,
    required void Function(EquityProgress progress) onProgress,
    void Function(Object error)? onError,
    Duration updateInterval = const Duration(milliseconds: 100),
  }) {
    EquitySimulator(ranges, board, maxSimulations: maxSimulations);

    final simulation = BackgroundEquitySimulation._(onProgress, onError);
    simulation._port.listen(simulation._onMessage);
    final job = _Job(
      simulation._port.sendPort,
      [...ranges],
      [...board],
      maxSimulations,
      updateInterval.inMicroseconds,
    );
    return simulation._spawn(job).then((_) => simulation);
  }

  Future<void> _spawn(_Job job) async {
    try {
      _isolate = await Isolate.spawn(
        _work,
        job,
        errorsAreFatal: true,
        onError: _port.sendPort,
        onExit: _port.sendPort,
      );
    } catch (_) {
      _port.close();
      rethrow;
    }
    if (_stopped) _kill();
  }

  bool get isStopped => _stopped;

  /// Stops the worker immediately and drops any messages still in flight.
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _kill();
  }

  void _kill() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port.close();
  }

  void _onMessage(Object? message) {
    if (_stopped) return;
    switch (message) {
      case EquityProgress progress:
        onProgress(progress);
        if (progress.isComplete) stop();
      case [final Object error, _]:
        stop();
        onError?.call(error);
      case null:
        stop();
    }
  }
}

class _Job {
  final SendPort port;
  final List<String> ranges;
  final List<Card> board;
  final int maxSimulations;
  final int updateIntervalMicros;

  _Job(
    this.port,
    this.ranges,
    this.board,
    this.maxSimulations,
    this.updateIntervalMicros,
  );
}

void _work(_Job job) {
  final simulator = EquitySimulator(
    job.ranges,
    job.board,
    maxSimulations: job.maxSimulations,
  );
  final clock = Stopwatch()..start();
  var lastSent = -job.updateIntervalMicros;

  simulator.run((equities) {
    final complete = simulator.results.isComplete;
    final now = clock.elapsedMicroseconds;
    if (!complete && now - lastSent < job.updateIntervalMicros) return;
    lastSent = now;
    job.port.send(EquityProgress(simulator.simulations, equities, complete));
  }, notifyEvery: 1);
}
