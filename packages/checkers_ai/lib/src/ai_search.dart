import 'dart:collection';

import 'package:checkers_engine/checkers_engine.dart';

import 'cancellation.dart';
import 'aspiration_window.dart';
import 'search_budget.dart';
import 'transposition_table.dart';

enum SearchStopReason { completed, nodeLimit, depthLimit, timeLimit, cancelled }

final class QuiescenceDiagnostics {
  const QuiescenceDiagnostics({
    this.nodes = 0,
    this.cutoffs = 0,
    this.maximumDepth = 0,
  });

  final int nodes;
  final int cutoffs;

  /// Recursive edges from the depth-frontier node, which is depth zero.
  final int maximumDepth;

  QuiescenceDiagnostics plus(QuiescenceDiagnostics other) {
    return QuiescenceDiagnostics(
      nodes: nodes + other.nodes,
      cutoffs: cutoffs + other.cutoffs,
      maximumDepth: maximumDepth > other.maximumDepth
          ? maximumDepth
          : other.maximumDepth,
    );
  }
}

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
    this.transposition = const TranspositionDiagnostics(),
    this.quiescence = const QuiescenceDiagnostics(),
    this.aspiration = const AspirationDiagnostics(),
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
  final TranspositionDiagnostics transposition;
  final QuiescenceDiagnostics quiescence;
  final AspirationDiagnostics aspiration;
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
