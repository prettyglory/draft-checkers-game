import 'package:checkers_engine/checkers_engine.dart';

final class EvaluationWeights {
  EvaluationWeights({
    this.man = 100,
    this.king = 175,
    this.advancement = 4,
    this.centerControl = 6,
    this.mobility = 3,
    this.terminal = 100000,
  }) {
    final heuristicWeights = <int>[
      man,
      king,
      advancement,
      centerControl,
      mobility,
    ];
    if (heuristicWeights.any((weight) => weight < 0)) {
      throw ArgumentError('Heuristic weights cannot be negative.');
    }
    if (terminal <= heuristicWeights.fold(0, (sum, weight) => sum + weight)) {
      throw ArgumentError.value(
        terminal,
        'terminal',
        'Terminal weight must dominate the combined heuristic weights.',
      );
    }
  }

  final int man;
  final int king;
  final int advancement;
  final int centerControl;
  final int mobility;
  final int terminal;
}

final class PositionEvaluation {
  const PositionEvaluation({
    required this.material,
    required this.advancement,
    required this.centerControl,
    required this.mobility,
    required this.terminal,
  });

  final int material;
  final int advancement;
  final int centerControl;
  final int mobility;
  final int terminal;

  int get score => material + advancement + centerControl + mobility + terminal;
}

final class PositionEvaluator {
  PositionEvaluator({required this.rulesEngine, EvaluationWeights? weights})
    : weights = weights ?? EvaluationWeights();

  final RulesEngine rulesEngine;
  final EvaluationWeights weights;

  PositionEvaluation evaluate(GameState state, PlayerSide perspective) {
    if (state.rulesetId != rulesEngine.descriptor.id ||
        state.boardSize != rulesEngine.descriptor.boardSize) {
      throw ArgumentError('Game state does not match the evaluator ruleset.');
    }

    var material = 0;
    var advancement = 0;
    var centerControl = 0;
    for (final piece in state.pieces) {
      final sign = piece.side == perspective ? 1 : -1;
      material +=
          sign * (piece.rank == PieceRank.king ? weights.king : weights.man);
      if (piece.rank == PieceRank.man) {
        final progress = piece.side == PlayerSide.dark
            ? piece.position.row
            : state.boardSize - 1 - piece.position.row;
        advancement += sign * progress * weights.advancement;
      }
      if (_isCentral(piece.position, state.boardSize)) {
        centerControl += sign * weights.centerControl;
      }
    }

    final mobilitySign = state.activeSide == perspective ? 1 : -1;
    final mobility = state.status == GameStatus.active
        ? mobilitySign * rulesEngine.legalMoves(state).length * weights.mobility
        : 0;
    final terminal = switch (state.outcome) {
      GameOutcome(type: GameOutcomeType.draw) => 0,
      GameOutcome(winner: final winner?) =>
        winner == perspective ? weights.terminal : -weights.terminal,
      _ => 0,
    };

    return PositionEvaluation(
      material: material,
      advancement: advancement,
      centerControl: centerControl,
      mobility: mobility,
      terminal: terminal,
    );
  }

  static bool _isCentral(BoardPosition position, int boardSize) {
    final lower = boardSize ~/ 2 - 2;
    final upper = boardSize ~/ 2 + 1;
    return position.row >= lower &&
        position.row <= upper &&
        position.column >= lower &&
        position.column <= upper;
  }
}
