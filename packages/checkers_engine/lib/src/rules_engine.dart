import 'game_state.dart';
import 'move.dart';
import 'ruleset_descriptor.dart';

enum MoveRejectionCode {
  malformed,
  wrongTurn,
  pieceNotFound,
  illegalMovement,
  captureRequired,
  incompleteCapture,
  nonMaximumCapture,
  staleState,
  gameAlreadyCompleted,
}

final class MoveValidation {
  const MoveValidation.valid() : rejectionCode = null;

  const MoveValidation.invalid(this.rejectionCode);

  final MoveRejectionCode? rejectionCode;

  bool get isValid => rejectionCode == null;
}

/// The only boundary allowed to decide legal game-state transitions.
abstract interface class RulesEngine {
  RulesetDescriptor get descriptor;

  GameState createInitialState();

  List<Move> legalMoves(GameState state);

  MoveValidation validateMove(GameState state, Move move);

  /// Returns a new state or throws if [move] was not validated successfully.
  GameState applyMove(GameState state, Move move);
}
