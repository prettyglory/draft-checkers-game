import 'package:checkers_engine/checkers_engine.dart';

import 'ai_search.dart';
import 'cancellation.dart';
import 'position_evaluator.dart';
import 'search_request_validator.dart';

final class FixedDepthAlphaBetaStrategy implements AiStrategy {
  FixedDepthAlphaBetaStrategy({
    required this.rulesEngine,
    PositionEvaluator? evaluator,
  }) : evaluator = evaluator ?? PositionEvaluator(rulesEngine: rulesEngine);

  static const strategyId = 'alpha-beta-fixed';

  final RulesEngine rulesEngine;
  final PositionEvaluator evaluator;

  @override
  String get id => strategyId;

  @override
  Future<AiSearchResult> chooseMove(AiSearchRequest request) async {
    _throwIfCancelled(request);
    validateSearchRequest(rulesEngine, request);
    final depth = request.budget.maxDepth;
    if (depth == null) {
      throw const AiSearchException(AiSearchFailure.missingDepthBudget);
    }

    final context = _SearchContext(request);
    final perspective = request.state.activeSide;
    var bestMove = request.legalMoves.first;
    var bestScore = -_infinity;
    var completed = true;

    for (final move in request.legalMoves) {
      try {
        context.checkLimits();
        final nextState = rulesEngine.applyMove(request.state, move);
        final score = _alphaBeta(
          nextState,
          depth - 1,
          perspective,
          -_infinity,
          _infinity,
          context,
        );
        if (score > bestScore) {
          bestScore = score;
          bestMove = move;
        }
      } on _SearchLimitReached catch (limit) {
        context.stopReason = limit.reason;
        completed = false;
        break;
      }
    }
    context.stopwatch.stop();

    return AiSearchResult(
      move: bestMove,
      metadata: AiSearchMetadata(
        strategyId: id,
        nodesExamined: context.nodesExamined,
        completedDepth: completed ? depth : 0,
        elapsed: context.stopwatch.elapsed,
        stopReason: completed
            ? SearchStopReason.depthLimit
            : context.stopReason,
      ),
    );
  }

  int _alphaBeta(
    GameState state,
    int depth,
    PlayerSide perspective,
    int alpha,
    int beta,
    _SearchContext context,
  ) {
    context.visitNode();
    if (depth == 0 || state.status == GameStatus.completed) {
      return evaluator.evaluate(state, perspective).score;
    }

    final moves = rulesEngine.legalMoves(state);
    if (moves.isEmpty) {
      return evaluator.evaluate(state, perspective).score;
    }

    if (state.activeSide == perspective) {
      var value = -_infinity;
      for (final move in moves) {
        final child = rulesEngine.applyMove(state, move);
        final score = _alphaBeta(
          child,
          depth - 1,
          perspective,
          alpha,
          beta,
          context,
        );
        if (score > value) {
          value = score;
        }
        if (value > alpha) {
          alpha = value;
        }
        if (alpha >= beta) {
          break;
        }
      }
      return value;
    }

    var value = _infinity;
    for (final move in moves) {
      final child = rulesEngine.applyMove(state, move);
      final score = _alphaBeta(
        child,
        depth - 1,
        perspective,
        alpha,
        beta,
        context,
      );
      if (score < value) {
        value = score;
      }
      if (value < beta) {
        beta = value;
      }
      if (alpha >= beta) {
        break;
      }
    }
    return value;
  }

  static void _throwIfCancelled(AiSearchRequest request) {
    if (request.cancellationToken.isCancelled) {
      throw const AiSearchCancelledException();
    }
  }

  static const _infinity = 1 << 30;
}

final class _SearchContext {
  _SearchContext(this.request) : stopwatch = Stopwatch()..start();

  final AiSearchRequest request;
  final Stopwatch stopwatch;
  int nodesExamined = 0;
  SearchStopReason stopReason = SearchStopReason.completed;

  void visitNode() {
    checkLimits();
    nodesExamined += 1;
  }

  void checkLimits() {
    if (request.cancellationToken.isCancelled) {
      throw const AiSearchCancelledException();
    }
    if (request.budget.maxNodes case final limit? when nodesExamined >= limit) {
      throw const _SearchLimitReached(SearchStopReason.nodeLimit);
    }
    if (request.budget.maxDuration case final limit?
        when stopwatch.elapsed >= limit) {
      throw const _SearchLimitReached(SearchStopReason.timeLimit);
    }
  }
}

final class _SearchLimitReached implements Exception {
  const _SearchLimitReached(this.reason);

  final SearchStopReason reason;
}
