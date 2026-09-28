import 'dart:collection';

import 'package:checkers_engine/checkers_engine.dart';

import 'cancellation.dart';
import 'search_budget.dart';

enum SearchStopReason { completed, nodeLimit, depthLimit, timeLimit, cancelled }

final class AiSearchRequest {
  AiSearchRequest({
    required this.state,
    required Iterable<Move> legalMoves,
    required this.budget,
    this.cancellationToken = const NoCancellationToken(),
  }) : legalMoves = UnmodifiableListView<Move>(List<Move>.of(legalMoves));

  final GameState state;
  final List<Move> legalMoves;
  final SearchBudget budget;
  final AiCancellationToken cancellationToken;
}

final class AiSearchMetadata {
  AiSearchMetadata({
    required this.strategyId,
    required this.nodesExamined,
    required this.completedDepth,
    required this.elapsed,
    required this.stopReason,
  }) {
    if (strategyId.trim().isEmpty) {
      throw ArgumentError.value(
        strategyId,
        'strategyId',
        'Strategy id cannot be empty.',
      );
    }
    if (nodesExamined < 0 || completedDepth < 0 || elapsed.isNegative) {
      throw ArgumentError(
        'Search counters and elapsed duration cannot be negative.',
      );
    }
  }

  final String strategyId;
  final int nodesExamined;
  final int completedDepth;
  final Duration elapsed;
  final SearchStopReason stopReason;
}

final class AiSearchResult {
  const AiSearchResult({required this.move, required this.metadata});

  final Move move;
  final AiSearchMetadata metadata;
}

abstract interface class AiStrategy {
  String get id;

  Future<AiSearchResult> chooseMove(AiSearchRequest request);
}

enum AiSearchFailure {
  incompatibleRuleset,
  completedGame,
  noLegalMoves,
  legalMovesMismatch,
  missingDepthBudget,
}

final class AiSearchException implements Exception {
  const AiSearchException(this.failure);

  final AiSearchFailure failure;

  @override
  String toString() => 'AI search failed: ${failure.name}.';
}
