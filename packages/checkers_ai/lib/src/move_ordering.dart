import 'package:checkers_engine/checkers_engine.dart';

final class MoveOrderingDiagnostics {
  const MoveOrderingDiagnostics({
    this.killerHits = 0,
    this.historyHits = 0,
    this.historyUpdates = 0,
    this.killerUpdates = 0,
    this.reorderedQuietBetaCutoffs = 0,
  });

  final int killerHits;
  final int historyHits;
  final int historyUpdates;
  final int killerUpdates;
  final int reorderedQuietBetaCutoffs;

  MoveOrderingDiagnostics difference(MoveOrderingDiagnostics earlier) {
    return MoveOrderingDiagnostics(
      killerHits: killerHits - earlier.killerHits,
      historyHits: historyHits - earlier.historyHits,
      historyUpdates: historyUpdates - earlier.historyUpdates,
      killerUpdates: killerUpdates - earlier.killerUpdates,
      reorderedQuietBetaCutoffs:
          reorderedQuietBetaCutoffs - earlier.reorderedQuietBetaCutoffs,
    );
  }

  MoveOrderingDiagnostics plus(MoveOrderingDiagnostics other) {
    return MoveOrderingDiagnostics(
      killerHits: killerHits + other.killerHits,
      historyHits: historyHits + other.historyHits,
      historyUpdates: historyUpdates + other.historyUpdates,
      killerUpdates: killerUpdates + other.killerUpdates,
      reorderedQuietBetaCutoffs:
          reorderedQuietBetaCutoffs + other.reorderedQuietBetaCutoffs,
    );
  }
}

final class MoveOrderingHeuristics {
  final Map<int, List<String>> _killersByPly = <int, List<String>>{};
  final Map<String, int> _historyScores = <String, int>{};
  int _killerHits = 0;
  int _historyHits = 0;
  int _historyUpdates = 0;
  int _killerUpdates = 0;
  int _reorderedQuietBetaCutoffs = 0;

  MoveOrderingDiagnostics get diagnostics => MoveOrderingDiagnostics(
    killerHits: _killerHits,
    historyHits: _historyHits,
    historyUpdates: _historyUpdates,
    killerUpdates: _killerUpdates,
    reorderedQuietBetaCutoffs: _reorderedQuietBetaCutoffs,
  );

  void recordQuietCutoff({
    required GameState state,
    required Move move,
    required int ply,
    required int remainingDepth,
  }) {
    if (move.isCapture) return;

    final signature = _moveSignature(move);
    final killers = _killersByPly[ply] ?? const <String>[];
    final historyKey = _historyKey(state, move);
    if (killers.contains(signature) || (_historyScores[historyKey] ?? 0) > 0) {
      _reorderedQuietBetaCutoffs += 1;
    }

    if (killers.isEmpty || killers.first != signature) {
      _killersByPly[ply] = <String>[
        signature,
        if (killers.isNotEmpty) killers.first,
      ];
      _killerUpdates += 1;
    }
    final bonus = remainingDepth * remainingDepth;
    _historyScores.update(
      historyKey,
      (score) => score + bonus,
      ifAbsent: () => bonus,
    );
    _historyUpdates += 1;
  }

  int? killerRank(int ply, Move move) {
    final index = _killersByPly[ply]?.indexOf(_moveSignature(move)) ?? -1;
    return index < 0 ? null : index;
  }

  int historyScore(GameState state, Move move) {
    return _historyScores[_historyKey(state, move)] ?? 0;
  }

  void recordKillerHit() {
    _killerHits += 1;
  }

  void recordHistoryHit() {
    _historyHits += 1;
  }

  static String _moveSignature(Move move) {
    final path = move.path
        .map((position) => '${position.row},${position.column}')
        .join(';');
    return '${move.pieceId}|$path';
  }

  static String _historyKey(GameState state, Move move) {
    return '${state.activeSide.name}|${_moveSignature(move)}';
  }
}

final class MoveOrdering {
  const MoveOrdering({this.useTacticalOrdering = true});

  final bool useTacticalOrdering;

  List<Move> order(
    GameState state,
    Iterable<Move> moves, {
    String? preferredMoveId,
    MoveOrderingHeuristics? heuristics,
    int ply = 0,
  }) {
    final ranked = <({Move move, int killerRank, int historyScore})>[
      for (final move in moves)
        (
          move: move,
          killerRank: _killerRank(heuristics, ply, move),
          historyScore: _historyScore(heuristics, state, move),
        ),
    ];
    ranked.sort((left, right) {
      final preferredComparison = _boolScore(right.move.id == preferredMoveId)
          .compareTo(_boolScore(left.move.id == preferredMoveId));
      if (preferredComparison != 0) {
        return preferredComparison;
      }
      if (useTacticalOrdering) {
        final captureComparison = right.move.captureCount.compareTo(
          left.move.captureCount,
        );
        if (captureComparison != 0) {
          return captureComparison;
        }
        final promotionComparison = _boolScore(_promotes(state, right.move))
            .compareTo(_boolScore(_promotes(state, left.move)));
        if (promotionComparison != 0) {
          return promotionComparison;
        }
      }
      final killerComparison = left.killerRank.compareTo(right.killerRank);
      if (killerComparison != 0) {
        return killerComparison;
      }
      final historyComparison = right.historyScore.compareTo(left.historyScore);
      if (historyComparison != 0) {
        return historyComparison;
      }
      return left.move.id.compareTo(right.move.id);
    });
    return List<Move>.unmodifiable(ranked.map((entry) => entry.move));
  }

  static int _killerRank(
    MoveOrderingHeuristics? heuristics,
    int ply,
    Move move,
  ) {
    if (heuristics == null || move.isCapture) return 2;
    final rank = heuristics.killerRank(ply, move);
    if (rank == null) return 2;
    heuristics.recordKillerHit();
    return rank;
  }

  static int _historyScore(
    MoveOrderingHeuristics? heuristics,
    GameState state,
    Move move,
  ) {
    if (heuristics == null || move.isCapture) return 0;
    final score = heuristics.historyScore(state, move);
    if (score > 0) {
      heuristics.recordHistoryHit();
    }
    return score;
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
