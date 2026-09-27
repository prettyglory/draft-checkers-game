import 'board_position.dart';

enum PlayerSide { light, dark }

enum PieceRank { man, king }

/// A piece identity is stable for the lifetime of a match.
final class Piece {
  Piece({
    required this.id,
    required this.side,
    required this.rank,
    required this.position,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Piece id cannot be empty.');
    }
  }

  final String id;
  final PlayerSide side;
  final PieceRank rank;
  final BoardPosition position;

  Piece copyWith({PieceRank? rank, BoardPosition? position}) {
    return Piece(
      id: id,
      side: side,
      rank: rank ?? this.rank,
      position: position ?? this.position,
    );
  }
}
