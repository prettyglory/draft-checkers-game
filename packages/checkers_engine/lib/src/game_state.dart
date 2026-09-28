import 'dart:collection';

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
    Iterable<String> previousPositionHashes = const <String>[],
    Map<String, int> ruleCounters = const <String, int>{},
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
    final previousHashes = List<String>.unmodifiable(previousPositionHashes);
    if (previousHashes.any((hash) => !_isSha256(hash))) {
      throw ArgumentError.value(
        previousHashes,
        'previousPositionHashes',
        'Position history entries must be SHA-256 hashes.',
      );
    }
    positionHistory = List<String>.unmodifiable(<String>[
      ...previousHashes,
      computedPositionHash,
    ]);
    if (ruleCounters.entries.any(
      (entry) => entry.key.trim().isEmpty || entry.value < 0,
    )) {
      throw ArgumentError.value(
        ruleCounters,
        'ruleCounters',
        'Rule counter names cannot be empty and values cannot be negative.',
      );
    }
    this.ruleCounters = UnmodifiableMapView<String, int>(
      Map<String, int>.of(ruleCounters),
    );
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
  late final List<String> positionHistory;
  late final Map<String, int> ruleCounters;
  final GameStatus status;
  final GameOutcome? outcome;

  List<Piece> get pieces => board.pieces;

  int positionOccurrenceCount(String hash) {
    return positionHistory.where((candidate) => candidate == hash).length;
  }

  static bool _isSha256(String value) {
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
  }
}
