import 'dart:async';
import 'dart:isolate';

import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';

abstract interface class AiTurnRunner {
  Future<AiSearchResult> chooseMove({
    required AiDifficulty difficulty,
    required GameState state,
    required List<Move> legalMoves,
  });

  void cancel();

  void dispose();
}

final class IsolateAiTurnRunner implements AiTurnRunner {
  Isolate? _isolate;
  ReceivePort? _receivePort;
  Completer<AiSearchResult>? _completer;
  int _generation = 0;
  bool _disposed = false;

  @override
  Future<AiSearchResult> chooseMove({
    required AiDifficulty difficulty,
    required GameState state,
    required List<Move> legalMoves,
  }) {
    if (_disposed) {
      throw StateError('The AI turn runner has been disposed.');
    }
    cancel();
    final generation = ++_generation;
    final receivePort = ReceivePort();
    final completer = Completer<AiSearchResult>();
    _receivePort = receivePort;
    _completer = completer;
    receivePort.listen((message) {
      if (generation != _generation || completer.isCompleted) return;
      if (message is AiSearchResult) {
        completer.complete(message);
      } else {
        completer.completeError(StateError('$message'));
      }
      _clearActive(generation);
    });

    unawaited(
      _spawnWorker(
        generation,
        completer,
        _AiWorkerRequest(
          responsePort: receivePort.sendPort,
          difficulty: difficulty,
          state: state,
          legalMoves: legalMoves,
        ),
      ),
    );
    return completer.future;
  }

  Future<void> _spawnWorker(
    int generation,
    Completer<AiSearchResult> completer,
    _AiWorkerRequest request,
  ) async {
    try {
      final isolate = await Isolate.spawn(
        _runSearch,
        request,
        errorsAreFatal: true,
      );
      if (generation != _generation || _disposed) {
        isolate.kill(priority: Isolate.immediate);
        if (!completer.isCompleted) {
          completer.completeError(const AiSearchCancelledException());
        }
      } else {
        _isolate = isolate;
      }
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      _clearActive(generation);
    }
  }

  @override
  void cancel() {
    _generation += 1;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(const AiSearchCancelledException());
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancel();
  }

  void _clearActive(int generation) {
    if (generation != _generation) return;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    _completer = null;
  }

  static Future<void> _runSearch(_AiWorkerRequest request) async {
    try {
      const engine = AmericanCheckersRulesEngine();
      final preset = request.difficulty.preset;
      final result = await preset
          .createStrategy(rulesEngine: engine)
          .chooseMove(
            AiSearchRequest(
              state: request.state,
              legalMoves: request.legalMoves,
              budget: preset.budget,
            ),
          );
      request.responsePort.send(result);
    } catch (error, stackTrace) {
      request.responsePort.send('AI search failed: $error\n$stackTrace');
    }
  }
}

final class _AiWorkerRequest {
  const _AiWorkerRequest({
    required this.responsePort,
    required this.difficulty,
    required this.state,
    required this.legalMoves,
  });

  final SendPort responsePort;
  final AiDifficulty difficulty;
  final GameState state;
  final List<Move> legalMoves;
}
