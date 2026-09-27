/// Human-readable facts shown before a match begins.
final class RulesetDescriptor {
  RulesetDescriptor({
    required this.id,
    required this.displayName,
    required this.boardSize,
    required this.piecesPerSide,
    required Iterable<String> importantDifferences,
  }) : importantDifferences = List<String>.unmodifiable(importantDifferences) {
    if (id.trim().isEmpty || displayName.trim().isEmpty) {
      throw ArgumentError('Ruleset id and display name cannot be empty.');
    }
    if (boardSize < 2 || piecesPerSide < 1) {
      throw ArgumentError('Ruleset board and piece counts must be positive.');
    }
    if (this.importantDifferences.isEmpty) {
      throw ArgumentError('A ruleset must explain its important differences.');
    }
  }

  final String id;
  final String displayName;
  final int boardSize;
  final int piecesPerSide;
  final List<String> importantDifferences;
}
