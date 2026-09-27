/// Zero-based board coordinate independent of any display orientation.
final class BoardPosition {
  const BoardPosition({required this.row, required this.column})
    : assert(row >= 0),
      assert(column >= 0);

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
