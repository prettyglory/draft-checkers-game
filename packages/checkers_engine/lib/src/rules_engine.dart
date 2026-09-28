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

  const MoveValidation.invalid(MoveRejectionCode code) : rejectionCode = code;

  final MoveRejectionCode? rejectionCode;

  bool get isValid => rejectionCode == null;
}

/// The only boundary allowed to decide legal game-state transitions.
abstract interface class RulesEngine {
  RulesetDescriptor get descriptor;

  GameState createInitialState();

  List<Move> legalMoves(GameState state);

  MoveValidation validateMove(GameState state, Move move);

  /// Returns the next revision/ply or throws if [move] is not valid.
  ///
  /// Implementations must increment both `revision` and `ply` exactly once.
  GameState applyMove(GameState state, Move move);
}
