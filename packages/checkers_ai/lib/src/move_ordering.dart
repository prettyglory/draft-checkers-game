import 'package:checkers_engine/checkers_engine.dart';

final class MoveOrdering {
  const MoveOrdering();

  List<Move> order(
    GameState state,
    Iterable<Move> moves, {
    String? preferredMoveId,
  }) {
    final ordered = moves.toList();
    ordered.sort((left, right) {
      final preferredComparison = _boolScore(right.id == preferredMoveId)
          .compareTo(_boolScore(left.id == preferredMoveId));
      if (preferredComparison != 0) {
        return preferredComparison;
      }
      final captureComparison = right.captureCount.compareTo(left.captureCount);
      if (captureComparison != 0) {
        return captureComparison;
      }
      final promotionComparison = _boolScore(_promotes(state, right))
          .compareTo(_boolScore(_promotes(state, left)));
      if (promotionComparison != 0) {
        return promotionComparison;
      }
      return left.id.compareTo(right.id);
    });
    return List<Move>.unmodifiable(ordered);
  }

  static bool _promotes(GameState state, Move move) {
    final piece = state.board.pieceById(move.pieceId);
    if (piece == null || piece.rank == PieceRank.king) {
      return false;
    }
    return piece.side == PlayerSide.dark
        ? move.destination.row == state.boardSize - 1
        : move.destination.row == 0;
  }

  static int _boolScore(bool value) => value ? 1 : 0;
}
