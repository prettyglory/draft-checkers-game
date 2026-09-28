import 'package:checkers_engine/checkers_engine.dart';

import 'ai_search.dart';
import 'cancellation.dart';
import 'move_ordering.dart';
import 'position_evaluator.dart';
import 'search_request_validator.dart';
import 'transposition_table.dart';

final class FixedDepthAlphaBetaStrategy implements AiStrategy {
  FixedDepthAlphaBetaStrategy({
    required this.rulesEngine,
    PositionEvaluator? evaluator,
    this.moveOrdering = const MoveOrdering(),
    TranspositionTable? transpositionTable,
  }) : evaluator = evaluator ?? PositionEvaluator(rulesEngine: rulesEngine),
       transpositionTable = transpositionTable ?? TranspositionTable();

  static const strategyId = 'alpha-beta-fixed';

  final RulesEngine rulesEngine;
  final PositionEvaluator evaluator;
  final MoveOrdering moveOrdering;
  final TranspositionTable transpositionTable;

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

    final perspective = request.state.activeSide;
    final diagnosticsBefore = transpositionTable.diagnostics;
    final context = _SearchContext(
      request,
      transpositionTable,
      transpositionTable.nextGeneration(),
      evaluator.weights,
      perspective,
    );
    var bestMove = request.legalMoves.first;
    var bestScore = -_infinity;
    var completed = true;

    for (final move in moveOrdering.order(request.state, request.legalMoves)) {
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
        transposition: transpositionTable.diagnostics.difference(
          diagnosticsBefore,
        ),
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
    final alphaOriginal = alpha;
    final betaOriginal = beta;
    final key = context.keyFor(state);
    final cached = context.table.probe(key);
    if (cached != null && cached.depth >= depth) {
      if (cached.bound == TranspositionBound.exact) {
        context.table.recordUse(cached, cutoff: true);
        return cached.score;
      }
      if (cached.bound == TranspositionBound.lower && cached.score > alpha) {
        alpha = cached.score;
      }
      if (cached.bound == TranspositionBound.upper && cached.score < beta) {
        beta = cached.score;
      }
      final cutoff = alpha >= beta;
      context.table.recordUse(cached, cutoff: cutoff);
      if (cutoff) {
        return cached.score;
      }
    }
    if (depth == 0 || state.status == GameStatus.completed) {
      final score = evaluator.evaluate(state, perspective).score;
      context.store(key, depth, score, TranspositionBound.exact, null);
      return score;
    }

    final moves = moveOrdering.order(
      state,
      rulesEngine.legalMoves(state),
      preferredMoveId: cached?.bestMoveId,
    );
    if (moves.isEmpty) {
      final score = evaluator.evaluate(state, perspective).score;
      context.store(key, depth, score, TranspositionBound.exact, null);
      return score;
    }

    late final int result;
    String? bestMoveId;
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
          bestMoveId = move.id;
        }
        if (value > alpha) {
          alpha = value;
        }
        if (alpha >= beta) {
          break;
        }
      }
      result = value;
    } else {
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
          bestMoveId = move.id;
        }
        if (value < beta) {
          beta = value;
        }
        if (alpha >= beta) {
          break;
        }
      }
      result = value;
    }
    final bound = result <= alphaOriginal
        ? TranspositionBound.upper
        : result >= betaOriginal
        ? TranspositionBound.lower
        : TranspositionBound.exact;
    context.store(key, depth, result, bound, bestMoveId);
    return result;
  }

  static void _throwIfCancelled(AiSearchRequest request) {
    if (request.cancellationToken.isCancelled) {
      throw const AiSearchCancelledException();
    }
  }

  static const _infinity = 1 << 30;
}

final class _SearchContext {
  _SearchContext(
    this.request,
    this.table,
    this.generation,
    this.weights,
    this.perspective,
  ) : stopwatch = Stopwatch()..start();

  final AiSearchRequest request;
  final TranspositionTable table;
  final int generation;
  final EvaluationWeights weights;
  final PlayerSide perspective;
  final Stopwatch stopwatch;
  int nodesExamined = 0;
  SearchStopReason stopReason = SearchStopReason.completed;

  TranspositionKey keyFor(GameState state) => TranspositionKey.fromState(
    state: state,
    perspective: perspective,
    weights: weights,
  );

  void store(
    TranspositionKey key,
    int depth,
    int score,
    TranspositionBound bound,
    String? bestMoveId,
  ) {
    table.store(
      key,
      TranspositionEntry(
        depth: depth,
        score: score,
        bound: bound,
        bestMoveId: bestMoveId,
        generation: generation,
      ),
    );
  }

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
