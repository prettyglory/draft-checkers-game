import 'dart:collection';

import 'game_state.dart';
import 'move.dart';
import 'rules_engine.dart';

/// Reconstructs every state in a move history through its rules engine.
final class GameReplayer {
  const GameReplayer();

  List<GameState> replay({
    required RulesEngine rulesEngine,
    required GameState initialState,
    required Iterable<Move> moves,
  }) {
    if (initialState.rulesetId != rulesEngine.descriptor.id) {
      throw GameReplayException(
        'State ruleset ${initialState.rulesetId} does not match engine '
        '${rulesEngine.descriptor.id}.',
      );
    }
    if (initialState.boardSize != rulesEngine.descriptor.boardSize) {
      throw GameReplayException(
        'State board size ${initialState.boardSize} does not match engine '
        '${rulesEngine.descriptor.boardSize}.',
      );
    }

    final states = <GameState>[initialState];
    var current = initialState;
    var moveIndex = 0;
    for (final move in moves) {
      final validation = rulesEngine.validateMove(current, move);
      if (!validation.isValid) {
        throw GameReplayException(
          'Move ${move.id} was rejected with ${validation.rejectionCode}.',
          moveIndex: moveIndex,
          move: move,
          rejectionCode: validation.rejectionCode,
        );
      }

      final next = rulesEngine.applyMove(current, move);
      _validateTransition(
        engine: rulesEngine,
        previous: current,
        next: next,
        move: move,
        moveIndex: moveIndex,
      );
      states.add(next);
      current = next;
      moveIndex += 1;
    }

    return UnmodifiableListView<GameState>(states);
  }

  static void _validateTransition({
    required RulesEngine engine,
    required GameState previous,
    required GameState next,
    required Move move,
    required int moveIndex,
  }) {
    if (next.rulesetId != engine.descriptor.id ||
        next.boardSize != engine.descriptor.boardSize) {
      throw GameReplayException(
        'Move ${move.id} changed the ruleset or board geometry.',
        moveIndex: moveIndex,
        move: move,
      );
    }
    if (next.revision != previous.revision + 1) {
      throw GameReplayException(
        'Move ${move.id} produced revision ${next.revision}; expected '
        '${previous.revision + 1}.',
        moveIndex: moveIndex,
        move: move,
      );
    }
    if (next.ply != previous.ply + 1) {
      throw GameReplayException(
        'Move ${move.id} produced ply ${next.ply}; expected '
        '${previous.ply + 1}.',
        moveIndex: moveIndex,
        move: move,
      );
    }
  }
}

final class GameReplayException implements Exception {
  const GameReplayException(
    this.message, {
    this.moveIndex,
    this.move,
    this.rejectionCode,
  });

  final String message;
  final int? moveIndex;
  final Move? move;
  final MoveRejectionCode? rejectionCode;

  @override
  String toString() {
    final location = moveIndex == null ? '' : ' at move $moveIndex';
    return 'GameReplayException$location: $message';
  }
}
