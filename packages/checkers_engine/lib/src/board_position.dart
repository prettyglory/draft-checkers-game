/// Zero-based board coordinate independent of any display orientation.
final class BoardPosition {
  BoardPosition({required this.row, required this.column}) {
    if (row < 0 || column < 0) {
      throw RangeError('Board coordinates cannot be negative.');
    }
  }

  final int row;
  final int column;

  /// Whether this coordinate is valid for a square board of [boardSize].
  bool isInside(int boardSize) {
    return boardSize > 0 &&
        row >= 0 &&
        row < boardSize &&
        column >= 0 &&
        column < boardSize;
  }

  BoardPosition offset({required int rows, required int columns}) {
    return BoardPosition(row: row + rows, column: column + columns);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BoardPosition && row == other.row && column == other.column;
  }

  @override
  int get hashCode => Object.hash(row, column);

  @override
  String toString() => 'BoardPosition(row: $row, column: $column)';
}
