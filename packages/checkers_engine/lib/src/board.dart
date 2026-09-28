import 'dart:collection';

import 'board_position.dart';
import 'move.dart';
import 'piece.dart';

/// Immutable piece placement for a square checkers board.
final class Board {
  factory Board({required int size, required Iterable<Piece> pieces}) {
    if (size < 2) {
      throw ArgumentError.value(size, 'size', 'Board size must be at least 2.');
    }

    final materializedPieces = List<Piece>.unmodifiable(pieces);
    return Board._(size: size, pieces: materializedPieces);
  }

  Board._({required this.size, required List<Piece> pieces})
    : _piecesById = _indexById(size, pieces),
      _pieceIdsByPosition = _indexByPosition(size, pieces);

  final int size;
  final Map<String, Piece> _piecesById;
  final Map<BoardPosition, String> _pieceIdsByPosition;

  List<Piece> get pieces {
    final ordered = _piecesById.values.toList()
      ..sort((first, second) => first.id.compareTo(second.id));
    return List<Piece>.unmodifiable(ordered);
  }

  int get pieceCount => _piecesById.length;

  Piece? pieceById(String id) => _piecesById[id];

  Piece? pieceAt(BoardPosition position) {
    final id = _pieceIdsByPosition[position];
    return id == null ? null : _piecesById[id];
  }

  bool isEmptyAt(BoardPosition position) => pieceAt(position) == null;

  List<Piece> piecesFor(PlayerSide side) {
    return List<Piece>.unmodifiable(
      pieces.where((piece) => piece.side == side),
    );
  }

  /// Applies a move whose ruleset-specific legality has already been checked.
  ///
  /// This method only enforces board invariants. Deciding whether movement,
  /// capture selection, and promotion are legal remains a [RulesEngine]
  /// responsibility.
  Board applyMove(Move move, {bool promote = false}) {
    final movingPiece = _piecesById[move.pieceId];
    if (movingPiece == null) {
      throw StateError('Cannot move missing piece ${move.pieceId}.');
    }
    if (movingPiece.position != move.origin) {
      throw StateError(
        'Move origin ${move.origin} does not contain ${move.pieceId}.',
      );
    }
    for (final position in move.path) {
      _requireInside(position);
    }
    final destinationOccupant = pieceAt(move.destination);
    if (destinationOccupant != null && destinationOccupant.id != move.pieceId) {
      throw StateError('Cannot move to occupied position ${move.destination}.');
    }

    for (final capturedId in move.capturedPieceIds) {
      final capturedPiece = _piecesById[capturedId];
      if (capturedPiece == null) {
        throw StateError('Cannot capture missing piece $capturedId.');
      }
      if (capturedPiece.side == movingPiece.side) {
        throw StateError('Cannot capture friendly piece $capturedId.');
      }
    }

    var result = removePieces(move.capturedPieceIds);
    if (move.destination != move.origin) {
      result = result.movePiece(pieceId: move.pieceId, to: move.destination);
    }
    if (promote) {
      result = result.promotePiece(move.pieceId);
    }
    return result;
  }

  Board movePiece({required String pieceId, required BoardPosition to}) {
    _requireInside(to);
    final piece = _piecesById[pieceId];
    if (piece == null) {
      throw StateError('Cannot move missing piece $pieceId.');
    }
    if (!isEmptyAt(to)) {
      throw StateError('Cannot move to occupied position $to.');
    }

    return replacePiece(piece.copyWith(position: to));
  }

  Board promotePiece(String pieceId) {
    final piece = _piecesById[pieceId];
    if (piece == null) {
      throw StateError('Cannot promote missing piece $pieceId.');
    }
    if (piece.rank == PieceRank.king) {
      return this;
    }

    return replacePiece(piece.copyWith(rank: PieceRank.king));
  }

  Board removePieces(Iterable<String> pieceIds) {
    final ids = pieceIds.toSet();
    if (ids.isEmpty) {
      return this;
    }
    final missing = ids.difference(_piecesById.keys.toSet());
    if (missing.isNotEmpty) {
      throw StateError('Cannot remove missing pieces: ${missing.join(', ')}.');
    }

    return Board(
      size: size,
      pieces: _piecesById.values.where((piece) => !ids.contains(piece.id)),
    );
  }

  Board replacePiece(Piece piece) {
    _requireInside(piece.position);
    final currentPiece = _piecesById[piece.id];
    if (currentPiece == null) {
      throw StateError('Cannot replace missing piece ${piece.id}.');
    }
    if (piece.side != currentPiece.side) {
      throw StateError('Cannot change the side of piece ${piece.id}.');
    }
    final occupant = pieceAt(piece.position);
    if (occupant != null && occupant.id != piece.id) {
      throw StateError(
        'Cannot place ${piece.id} on occupied ${piece.position}.',
      );
    }

    return Board(
      size: size,
      pieces: _piecesById.values.map(
        (current) => current.id == piece.id ? piece : current,
      ),
    );
  }

  void _requireInside(BoardPosition position) {
    if (!position.isInside(size)) {
      throw RangeError('Position $position is outside a $size x $size board.');
    }
  }

  static Map<String, Piece> _indexById(int size, Iterable<Piece> source) {
    final result = <String, Piece>{};
    for (final piece in source) {
      if (!piece.position.isInside(size)) {
        throw RangeError('Piece ${piece.id} is outside a $size x $size board.');
      }
      if (result.containsKey(piece.id)) {
        throw ArgumentError('Duplicate piece id: ${piece.id}.');
      }
      result[piece.id] = piece;
    }
    return UnmodifiableMapView<String, Piece>(result);
  }

  static Map<BoardPosition, String> _indexByPosition(
    int size,
    Iterable<Piece> source,
  ) {
    final result = <BoardPosition, String>{};
    for (final piece in source) {
      if (!piece.position.isInside(size)) {
        throw RangeError('Piece ${piece.id} is outside a $size x $size board.');
      }
      final previousId = result[piece.position];
      if (previousId != null) {
        throw ArgumentError(
          'Pieces $previousId and ${piece.id} occupy ${piece.position}.',
        );
      }
      result[piece.position] = piece.id;
    }
    return UnmodifiableMapView<BoardPosition, String>(result);
  }
}
