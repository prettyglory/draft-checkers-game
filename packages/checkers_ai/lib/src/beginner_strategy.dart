import 'dart:math';

import 'package:checkers_engine/checkers_engine.dart';

import 'ai_search.dart';
import 'cancellation.dart';
import 'search_request_validator.dart';

final class BeginnerStrategy implements AiStrategy {
  BeginnerStrategy({required this.rulesEngine, int seed = 0})
    : _random = Random(seed);

  static const strategyId = 'beginner-random';

  final RulesEngine rulesEngine;
  final Random _random;

  @override
  String get id => strategyId;

  @override
  Future<AiSearchResult> chooseMove(AiSearchRequest request) async {
    final stopwatch = Stopwatch()..start();
    _throwIfCancelled(request);
    validateSearchRequest(rulesEngine, request);

    final selected =
        request.legalMoves[_random.nextInt(request.legalMoves.length)];
    _throwIfCancelled(request);
    stopwatch.stop();

    return AiSearchResult(
      move: selected,
      metadata: AiSearchMetadata(
        strategyId: id,
        nodesExamined: 1,
        completedDepth: 0,
        elapsed: stopwatch.elapsed,
        stopReason: SearchStopReason.completed,
      ),
    );
  }

  static void _throwIfCancelled(AiSearchRequest request) {
    if (request.cancellationToken.isCancelled) {
      throw const AiSearchCancelledException();
    }
  }
}
