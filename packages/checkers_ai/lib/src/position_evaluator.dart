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

final class EndgameEvaluationWeights {
  EndgameEvaluationWeights({
    this.materialThreshold = 6,
    this.kingActivity = 2,
    this.kingCentralization = 5,
    this.promotionProximity = 6,
    this.mobility = 3,
    this.trappedPiece = 20,
    this.edgeSafety = 2,
    this.conversionPressure = 10,
    this.drawRisk = 8,
  }) {
    if (materialThreshold < 2) {
      throw ArgumentError.value(
        materialThreshold,
        'materialThreshold',
        'Must allow at least one piece per side.',
      );
    }
    final heuristicWeights = <int>[
      kingActivity,
      kingCentralization,
      promotionProximity,
      mobility,
      trappedPiece,
      edgeSafety,
      conversionPressure,
      drawRisk,
    ];
    if (heuristicWeights.any((weight) => weight < 0)) {
      throw ArgumentError('Endgame weights cannot be negative.');
    }
  }

  final int materialThreshold;
  final int kingActivity;
  final int kingCentralization;
  final int promotionProximity;
  final int mobility;
  final int trappedPiece;
  final int edgeSafety;
  final int conversionPressure;
  final int drawRisk;
}

final class PositionEvaluation {
  const PositionEvaluation({
    required this.material,
    required this.advancement,
    required this.centerControl,
    required this.mobility,
    required this.terminal,
    this.endgameActive = false,
    this.kingActivity = 0,
    this.kingCentralization = 0,
    this.promotionProximity = 0,
    this.endgameMobility = 0,
    this.trappedPieces = 0,
    this.edgeSafety = 0,
    this.conversionPressure = 0,
    this.drawRisk = 0,
  });

  final int material;
  final int advancement;
  final int centerControl;
  final int mobility;
  final int terminal;
  final bool endgameActive;
  final int kingActivity;
  final int kingCentralization;
  final int promotionProximity;
  final int endgameMobility;
  final int trappedPieces;
  final int edgeSafety;
  final int conversionPressure;
  final int drawRisk;

  int get score =>
      material +
      advancement +
      centerControl +
      mobility +
      terminal +
      kingActivity +
      kingCentralization +
      promotionProximity +
      endgameMobility +
      trappedPieces +
      edgeSafety +
      conversionPressure +
      drawRisk;
}

final class PositionEvaluator {
  PositionEvaluator({
    required this.rulesEngine,
    EvaluationWeights? weights,
    this.endgameWeights,
  }) : weights = weights ?? EvaluationWeights();

  final RulesEngine rulesEngine;
  final EvaluationWeights weights;
  final EndgameEvaluationWeights? endgameWeights;

  String get cacheKey {
    final base =
        '${weights.man}|${weights.king}|${weights.advancement}|'
        '${weights.centerControl}|${weights.mobility}|${weights.terminal}';
    final endgame = endgameWeights;
    if (endgame == null) return 'evaluation-v2|$base|endgame-off';
    return 'evaluation-v2|$base|endgame-on|${endgame.materialThreshold}|'
        '${endgame.kingActivity}|${endgame.kingCentralization}|'
        '${endgame.promotionProximity}|${endgame.mobility}|'
        '${endgame.trappedPiece}|${endgame.edgeSafety}|'
        '${endgame.conversionPressure}|${endgame.drawRisk}';
  }

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

    final endgame = endgameWeights;
    final endgameActive =
        endgame != null && state.pieces.length <= endgame.materialThreshold;
    if (!endgameActive) {
      return PositionEvaluation(
        material: material,
        advancement: advancement,
        centerControl: centerControl,
        mobility: mobility,
        terminal: terminal,
      );
    }
    if (state.status == GameStatus.completed) {
      final drawAdjustment = state.outcome?.type == GameOutcomeType.draw
          ? -(material + advancement + centerControl + mobility + terminal)
          : 0;
      return PositionEvaluation(
        material: material,
        advancement: advancement,
        centerControl: centerControl,
        mobility: mobility,
        terminal: terminal,
        endgameActive: true,
        drawRisk: drawAdjustment,
      );
    }

    var kingActivity = 0;
    var kingCentralization = 0;
    var promotionProximity = 0;
    var trappedPieces = 0;
    var edgeSafety = 0;
    var perspectiveMaterialUnits = 0;
    var opponentMaterialUnits = 0;
    for (final piece in state.pieces) {
      final sign = piece.side == perspective ? 1 : -1;
      final materialUnits = piece.rank == PieceRank.king ? 2 : 1;
      if (sign > 0) {
        perspectiveMaterialUnits += materialUnits;
      } else {
        opponentMaterialUnits += materialUnits;
      }
      if (piece.rank == PieceRank.king) {
        kingActivity +=
            sign *
            _kingActivity(piece, state.pieces, state.boardSize) *
            endgame.kingActivity;
        kingCentralization +=
            sign *
            _centralization(piece.position, state.boardSize) *
            endgame.kingCentralization;
      } else {
        final progress = piece.side == PlayerSide.dark
            ? piece.position.row
            : state.boardSize - 1 - piece.position.row;
        promotionProximity += sign * progress * endgame.promotionProximity;
        if (piece.position.column == 0 ||
            piece.position.column == state.boardSize - 1) {
          edgeSafety += sign * endgame.edgeSafety;
        }
      }
      if (!_hasLocalMove(state, piece)) {
        trappedPieces -= sign * endgame.trappedPiece;
      }
    }

    final endgameMobility = state.status == GameStatus.active
        ? mobilitySign * rulesEngine.legalMoves(state).length * endgame.mobility
        : 0;
    final materialDifference = perspectiveMaterialUnits - opponentMaterialUnits;
    final scarcity = endgame.materialThreshold - state.pieces.length + 1;
    final conversionPressure =
        materialDifference * scarcity * endgame.conversionPressure;
    final drawRisk =
        -materialDifference.sign * _drawRiskUnits(state) * endgame.drawRisk;

    return PositionEvaluation(
      material: material,
      advancement: advancement,
      centerControl: centerControl,
      mobility: mobility,
      terminal: terminal,
      endgameActive: true,
      kingActivity: kingActivity,
      kingCentralization: kingCentralization,
      promotionProximity: promotionProximity,
      endgameMobility: endgameMobility,
      trappedPieces: trappedPieces,
      edgeSafety: edgeSafety,
      conversionPressure: conversionPressure,
      drawRisk: drawRisk,
    );
  }

  static int _kingActivity(Piece king, List<Piece> pieces, int boardSize) {
    final opponents = pieces.where((piece) => piece.side != king.side);
    if (opponents.isEmpty) return 0;
    final nearest = opponents
        .map((piece) => _chebyshevDistance(king.position, piece.position))
        .reduce((left, right) => left < right ? left : right);
    return boardSize - 1 - nearest;
  }

  static int _centralization(BoardPosition position, int boardSize) {
    final edgeDistance = <int>[
      position.row,
      position.column,
      boardSize - 1 - position.row,
      boardSize - 1 - position.column,
    ];
    return edgeDistance.reduce((left, right) => left < right ? left : right);
  }

  static int _chebyshevDistance(BoardPosition left, BoardPosition right) {
    final rowDistance = (left.row - right.row).abs();
    final columnDistance = (left.column - right.column).abs();
    return rowDistance > columnDistance ? rowDistance : columnDistance;
  }

  static bool _hasLocalMove(GameState state, Piece piece) {
    final directions = piece.rank == PieceRank.king
        ? const <(int, int)>[(-1, -1), (-1, 1), (1, -1), (1, 1)]
        : piece.side == PlayerSide.dark
        ? const <(int, int)>[(1, -1), (1, 1)]
        : const <(int, int)>[(-1, -1), (-1, 1)];
    for (final (rowOffset, columnOffset) in directions) {
      final adjacentRow = piece.position.row + rowOffset;
      final adjacentColumn = piece.position.column + columnOffset;
      if (!_isInside(adjacentRow, adjacentColumn, state.boardSize)) continue;
      final adjacent = BoardPosition(row: adjacentRow, column: adjacentColumn);
      if (state.board.isEmptyAt(adjacent)) return true;
      final jumped = state.board.pieceAt(adjacent);
      if (jumped?.side == piece.side) continue;
      final landingRow = adjacent.row + rowOffset;
      final landingColumn = adjacent.column + columnOffset;
      if (!_isInside(landingRow, landingColumn, state.boardSize)) continue;
      final landing = BoardPosition(row: landingRow, column: landingColumn);
      if (state.board.isEmptyAt(landing)) {
        return true;
      }
    }
    return false;
  }

  static bool _isInside(int row, int column, int boardSize) =>
      row >= 0 && row < boardSize && column >= 0 && column < boardSize;

  static int _drawRiskUnits(GameState state) {
    final noProgressPly =
        state.ruleCounters[AmericanCheckersRulesEngine.noProgressPlyCounter] ??
        0;
    final repetitionRisk =
        state.positionOccurrenceCount(state.positionHash) - 1;
    return noProgressPly ~/ 10 + repetitionRisk * 4;
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
