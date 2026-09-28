import 'board_position.dart';

/// A complete turn, including every landing in a multiple-capture sequence.
final class Move {
  Move({
    required this.id,
    required this.pieceId,
    required Iterable<BoardPosition> path,
    Iterable<String> capturedPieceIds = const <String>[],
  }) : path = List<BoardPosition>.unmodifiable(path),
       capturedPieceIds = List<String>.unmodifiable(capturedPieceIds) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Move id cannot be empty.');
    }
    if (pieceId.trim().isEmpty) {
      throw ArgumentError.value(
        pieceId,
        'pieceId',
        'Piece id cannot be empty.',
      );
    }
    if (this.path.length < 2) {
      throw ArgumentError.value(
        this.path,
        'path',
        'A move needs an origin and at least one landing.',
      );
    }
    if (this.capturedPieceIds.toSet().length != this.capturedPieceIds.length) {
      throw ArgumentError.value(
        this.capturedPieceIds,
        'capturedPieceIds',
        'A piece cannot be captured twice in one move.',
      );
    }
    if (this.capturedPieceIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError.value(
        this.capturedPieceIds,
        'capturedPieceIds',
        'Captured piece ids cannot be empty.',
      );
    }
    if (this.capturedPieceIds.contains(pieceId)) {
      throw ArgumentError.value(
        this.capturedPieceIds,
        'capturedPieceIds',
        'A moving piece cannot capture itself.',
      );
    }
    if (this.capturedPieceIds.isEmpty && this.path.length != 2) {
      throw ArgumentError.value(
        this.path,
        'path',
        'A non-capturing move has exactly one landing.',
      );
    }
    if (this.capturedPieceIds.isNotEmpty &&
        this.capturedPieceIds.length != this.path.length - 1) {
      throw ArgumentError(
        'A capturing move needs one captured piece for every landing.',
      );
    }
  }

  final String id;
  final String pieceId;
  final List<BoardPosition> path;
  final List<String> capturedPieceIds;

  BoardPosition get origin => path.first;
  BoardPosition get destination => path.last;
  int get captureCount => capturedPieceIds.length;
  bool get isCapture => capturedPieceIds.isNotEmpty;
}
