import 'package:checkers_engine/checkers_engine.dart';

import 'ai_search.dart';
import 'aspiration_window.dart';
import 'cancellation.dart';
import 'fixed_depth_alpha_beta_strategy.dart';
import 'move_ordering.dart';
import 'position_evaluator.dart';
import 'search_budget.dart';
import 'search_request_validator.dart';
import 'transposition_table.dart';

final class IterativeDeepeningStrategy implements AiStrategy {
  IterativeDeepeningStrategy({
    required this.rulesEngine,
    PositionEvaluator? evaluator,
    TranspositionTable? transpositionTable,
    int maxQuiescenceDepth = 8,
    AspirationWindowConfig? aspirationWindow,
  }) : aspirationWindow = aspirationWindow ?? AspirationWindowConfig(),
       _fixedDepth = FixedDepthAlphaBetaStrategy(
         rulesEngine: rulesEngine,
         evaluator: evaluator,
         transpositionTable: transpositionTable,
         maxQuiescenceDepth: maxQuiescenceDepth,
       );

  static const strategyId = 'alpha-beta-iterative';

  final RulesEngine rulesEngine;
  final AspirationWindowConfig aspirationWindow;
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
    var transposition = const TranspositionDiagnostics();
    var quiescence = const QuiescenceDiagnostics();
    var ordering = const MoveOrderingDiagnostics();
    final orderingHeuristics = MoveOrderingHeuristics();
    var previousScore = 0;
    var hasPreviousScore = false;
    var aspirationAttempts = 0;
    var failLow = 0;
    var failHigh = 0;
    var reSearches = 0;
    var maximumWindowWidth = 0;
    var fullWindowFallback = false;

    depthLoop:
    for (var depth = 1; depth <= maximumDepth; depth += 1) {
      _throwIfCancelled(request);
      final useAspiration =
          aspirationWindow.enabled && depth > 1 && hasPreviousScore;
      var windowedAttempt = 0;
      var halfWidth = aspirationWindow.initialHalfWidth;

      while (true) {
        _throwIfCancelled(request);
        final remainingNodes = switch (request.budget.maxNodes) {
          final limit? => limit - totalNodes,
          null => null,
        };
        if (remainingNodes != null && remainingNodes <= 0) {
          stopReason = SearchStopReason.nodeLimit;
          break depthLoop;
        }
        final remainingDuration = switch (request.budget.maxDuration) {
          final limit? => limit - stopwatch.elapsed,
          null => null,
        };
        if (remainingDuration != null && remainingDuration <= Duration.zero) {
          stopReason = SearchStopReason.timeLimit;
          break depthLoop;
        }

        final fullWindow =
            !useAspiration ||
            windowedAttempt >= aspirationWindow.maxWindowedAttempts;
        final alpha = fullWindow
            ? FixedDepthAlphaBetaStrategy.minimumScore
            : _clampScore(previousScore - halfWidth);
        final beta = fullWindow
            ? FixedDepthAlphaBetaStrategy.maximumScore
            : _clampScore(previousScore + halfWidth);
        if (useAspiration) {
          aspirationAttempts += 1;
          if (windowedAttempt > 0) {
            reSearches += 1;
          }
          final width = beta - alpha;
          if (width > maximumWindowWidth) {
            maximumWindowWidth = width;
          }
          if (fullWindow) {
            fullWindowFallback = true;
          }
        }

        final iteration = await _fixedDepth.searchWithWindow(
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
          alpha: alpha,
          beta: beta,
          orderingHeuristics: orderingHeuristics,
        );
        final result = iteration.result;
        totalNodes += result.metadata.nodesExamined;
        transposition = transposition.plus(result.metadata.transposition);
        quiescence = quiescence.plus(result.metadata.quiescence);
        ordering = ordering.plus(result.metadata.moveOrdering);
        if (result.metadata.completedDepth != depth) {
          stopReason = result.metadata.stopReason;
          break depthLoop;
        }
        if (iteration.bound == TranspositionBound.exact) {
          bestMove = result.move;
          completedDepth = depth;
          previousScore = iteration.score;
          hasPreviousScore = true;
          continue depthLoop;
        }
        if (iteration.bound == TranspositionBound.upper) {
          failLow += 1;
        } else {
          failHigh += 1;
        }
        windowedAttempt += 1;
        halfWidth *= aspirationWindow.wideningFactor;
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
        transposition: transposition,
        quiescence: quiescence,
        aspiration: AspirationDiagnostics(
          attempts: aspirationAttempts,
          failLow: failLow,
          failHigh: failHigh,
          reSearches: reSearches,
          maximumWindowWidth: maximumWindowWidth,
          fullWindowFallback: fullWindowFallback,
        ),
        moveOrdering: ordering,
      ),
    );
  }

  static void _throwIfCancelled(AiSearchRequest request) {
    if (request.cancellationToken.isCancelled) {
      throw const AiSearchCancelledException();
    }
  }

  static int _clampScore(int score) {
    return score.clamp(
      FixedDepthAlphaBetaStrategy.minimumScore,
      FixedDepthAlphaBetaStrategy.maximumScore,
    );
  }
}
