import 'board.dart';
import 'piece.dart';
import 'position_hasher.dart';

enum GameStatus { active, completed }

enum GameOutcomeType { win, draw }

enum GameOutcomeReason {
  noPieces,
  noLegalMoves,
  resignation,
  timeout,
  drawAgreement,
  repetition,
  moveLimit,
  insufficientWinningMaterial,
}

final class GameOutcome {
  const GameOutcome._({required this.type, required this.reason, this.winner});

  const GameOutcome.win({
    required PlayerSide winner,
    required GameOutcomeReason reason,
  }) : this._(type: GameOutcomeType.win, reason: reason, winner: winner);

  const GameOutcome.draw({required GameOutcomeReason reason})
    : this._(type: GameOutcomeType.draw, reason: reason);

  final GameOutcomeType type;
  final GameOutcomeReason reason;
  final PlayerSide? winner;
}

/// Immutable, serializable match state owned by a rules engine.
final class GameState {
  GameState({
    required this.rulesetId,
    required this.boardSize,
    required Iterable<Piece> pieces,
    required this.activeSide,
    required this.ply,
    required this.revision,
    String? positionHash,
    this.status = GameStatus.active,
    this.outcome,
  }) : board = Board(size: boardSize, pieces: pieces) {
    if (rulesetId.trim().isEmpty) {
      throw ArgumentError.value(
        rulesetId,
        'rulesetId',
        'Ruleset id cannot be empty.',
      );
    }
    if (boardSize < 2) {
      throw ArgumentError.value(
        boardSize,
        'boardSize',
        'Board size must be at least 2.',
      );
    }
    if (ply < 0 || revision < 0) {
      throw ArgumentError('Ply and revision cannot be negative.');
    }
    final computedPositionHash = PositionHasher.compute(
      rulesetId: rulesetId,
      boardSize: boardSize,
      pieces: board.pieces,
      activeSide: activeSide,
    );
    if (positionHash != null && positionHash != computedPositionHash) {
      throw ArgumentError.value(
        positionHash,
        'positionHash',
        'Position hash does not match the state.',
      );
    }
    this.positionHash = computedPositionHash;
    if (status == GameStatus.completed && outcome == null) {
      throw ArgumentError('A completed game must have an outcome.');
    }
    if (status == GameStatus.active && outcome != null) {
      throw ArgumentError('An active game cannot have an outcome.');
    }
  }

  final String rulesetId;
  final int boardSize;
  final Board board;
  final PlayerSide activeSide;
  final int ply;
  final int revision;
  late final String positionHash;
  final GameStatus status;
  final GameOutcome? outcome;

  List<Piece> get pieces => board.pieces;
}
