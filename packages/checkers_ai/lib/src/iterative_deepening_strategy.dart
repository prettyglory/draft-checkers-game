import 'package:checkers_engine/checkers_engine.dart';

import 'ai_search.dart';
import 'cancellation.dart';
import 'fixed_depth_alpha_beta_strategy.dart';
import 'position_evaluator.dart';
import 'search_budget.dart';
import 'search_request_validator.dart';

final class IterativeDeepeningStrategy implements AiStrategy {
  IterativeDeepeningStrategy({
    required this.rulesEngine,
    PositionEvaluator? evaluator,
  }) : _fixedDepth = FixedDepthAlphaBetaStrategy(
         rulesEngine: rulesEngine,
         evaluator: evaluator,
       );

  static const strategyId = 'alpha-beta-iterative';

  final RulesEngine rulesEngine;
  final FixedDepthAlphaBetaStrategy _fixedDepth;

  @override
  String get id => strategyId;

  @override
  Future<AiSearchResult> chooseMove(AiSearchRequest request) async {
    _throwIfCancelled(request);
    validateSearchRequest(rulesEngine, request);
    final maximumDepth = request.budget.maxDepth;
    if (maximumDepth == null) {
      throw const AiSearchException(AiSearchFailure.missingDepthBudget);
    }

    final stopwatch = Stopwatch()..start();
    var bestMove = request.legalMoves.first;
    var completedDepth = 0;
    var totalNodes = 0;
    var stopReason = SearchStopReason.depthLimit;

    for (var depth = 1; depth <= maximumDepth; depth += 1) {
      _throwIfCancelled(request);
      final remainingNodes = switch (request.budget.maxNodes) {
        final limit? => limit - totalNodes,
        null => null,
      };
      if (remainingNodes != null && remainingNodes <= 0) {
        stopReason = SearchStopReason.nodeLimit;
        break;
      }
      final remainingDuration = switch (request.budget.maxDuration) {
        final limit? => limit - stopwatch.elapsed,
        null => null,
      };
      if (remainingDuration != null && remainingDuration <= Duration.zero) {
        stopReason = SearchStopReason.timeLimit;
        break;
      }

      final iteration = await _fixedDepth.chooseMove(
        AiSearchRequest(
          state: request.state,
          legalMoves: request.legalMoves,
          budget: SearchBudget(
            maxDepth: depth,
            maxNodes: remainingNodes,
            maxDuration: remainingDuration,
          ),
          cancellationToken: request.cancellationToken,
        ),
      );
      totalNodes += iteration.metadata.nodesExamined;
      if (iteration.metadata.completedDepth == depth) {
        bestMove = iteration.move;
        completedDepth = depth;
      } else {
        stopReason = iteration.metadata.stopReason;
        break;
      }
    }
    stopwatch.stop();

    return AiSearchResult(
      move: bestMove,
      metadata: AiSearchMetadata(
        strategyId: id,
        nodesExamined: totalNodes,
        completedDepth: completedDepth,
        elapsed: stopwatch.elapsed,
        stopReason: stopReason,
      ),
    );
  }

  static void _throwIfCancelled(AiSearchRequest request) {
    if (request.cancellationToken.isCancelled) {
      throw const AiSearchCancelledException();
    }
  }
}
