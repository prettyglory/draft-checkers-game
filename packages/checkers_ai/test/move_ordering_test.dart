import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();
  const ordering = MoveOrdering();

  Piece piece(String id, PlayerSide side, int row, int column) {
    return Piece(
      id: id,
      side: side,
      rank: PieceRank.man,
      position: BoardPosition(row: row, column: column),
    );
  }

  GameState state(Iterable<Piece> pieces) {
    return GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: pieces,
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );
  }

  test('orders longer captures before shorter captures', () {
    final position = state(<Piece>[
      piece('dark-jumper', PlayerSide.dark, 2, 3),
      piece('light-left', PlayerSide.light, 3, 2),
      piece('light-right', PlayerSide.light, 3, 4),
      piece('light-follow-up', PlayerSide.light, 5, 6),
    ]);
    final legalMoves = engine.legalMoves(position);

    final ordered = ordering.order(position, legalMoves);

    expect(ordered.map((move) => move.captureCount), <int>[2, 1]);
  });

  test('orders promotions before ordinary moves', () {
    final position = state(<Piece>[
      piece('dark-promoter', PlayerSide.dark, 6, 1),
      piece('dark-runner', PlayerSide.dark, 2, 5),
      piece('light-far', PlayerSide.light, 0, 7),
    ]);
    final legalMoves = engine.legalMoves(position);

    final ordered = ordering.order(position, legalMoves);

    expect(ordered.first.pieceId, 'dark-promoter');
    expect(ordered.first.destination.row, 7);
  });

  test('places a preferred principal move first', () {
    final position = engine.createInitialState();
    final legalMoves = engine.legalMoves(position);
    final preferred = legalMoves.last;

    final ordered = ordering.order(
      position,
      legalMoves,
      preferredMoveId: preferred.id,
    );

    expect(ordered.first.id, preferred.id);
  });

  test('promotes a quiet killer move at its recorded ply', () {
    final position = engine.createInitialState();
    final legalMoves = engine.legalMoves(position);
    final killer = legalMoves.last;
    final heuristics = MoveOrderingHeuristics();
    heuristics.recordQuietCutoff(
      state: position,
      move: killer,
      ply: 2,
      remainingDepth: 3,
    );

    final ordered = ordering.order(
      position,
      legalMoves,
      heuristics: heuristics,
      ply: 2,
    );

    expect(ordered.first.id, killer.id);
    expect(heuristics.diagnostics.killerHits, 1);
    expect(heuristics.diagnostics.killerUpdates, 1);
  });

  test('uses deterministic two-slot killer replacement', () {
    final position = engine.createInitialState();
    final legalMoves = engine.legalMoves(position);
    final firstKiller = legalMoves.last;
    final secondKiller = legalMoves[legalMoves.length - 2];
    final heuristics = MoveOrderingHeuristics();

    heuristics.recordQuietCutoff(
      state: position,
      move: firstKiller,
      ply: 2,
      remainingDepth: 3,
    );
    heuristics.recordQuietCutoff(
      state: position,
      move: secondKiller,
      ply: 2,
      remainingDepth: 3,
    );
    final secondFirst = ordering.order(
      position,
      legalMoves,
      heuristics: heuristics,
      ply: 2,
    );
    heuristics.recordQuietCutoff(
      state: position,
      move: firstKiller,
      ply: 2,
      remainingDepth: 3,
    );
    final firstRestored = ordering.order(
      position,
      legalMoves,
      heuristics: heuristics,
      ply: 2,
    );

    expect(secondFirst.take(2).map((move) => move.id), <String>[
      secondKiller.id,
      firstKiller.id,
    ]);
    expect(firstRestored.take(2).map((move) => move.id), <String>[
      firstKiller.id,
      secondKiller.id,
    ]);
    expect(heuristics.diagnostics.reorderedQuietBetaCutoffs, 1);
  });

  test('uses quiet-move history outside the recorded killer ply', () {
    final position = engine.createInitialState();
    final legalMoves = engine.legalMoves(position);
    final historical = legalMoves.last;
    final heuristics = MoveOrderingHeuristics();
    heuristics.recordQuietCutoff(
      state: position,
      move: historical,
      ply: 1,
      remainingDepth: 4,
    );

    final ordered = ordering.order(
      position,
      legalMoves,
      heuristics: heuristics,
      ply: 3,
    );

    expect(ordered.first.id, historical.id);
    expect(heuristics.diagnostics.killerHits, 0);
    expect(heuristics.diagnostics.historyHits, 1);
    expect(heuristics.diagnostics.historyUpdates, 1);
  });

  test('keeps captures ahead of trained quiet moves', () {
    final position = state(<Piece>[
      piece('dark-jumper', PlayerSide.dark, 2, 1),
      piece('dark-runner', PlayerSide.dark, 2, 5),
      piece('light-target', PlayerSide.light, 3, 2),
    ]);
    final capture = engine.legalMoves(position).single;
    final quiet = Move(
      id: 'quiet',
      pieceId: 'dark-runner',
      path: <BoardPosition>[
        BoardPosition(row: 2, column: 5),
        BoardPosition(row: 3, column: 4),
      ],
    );
    final heuristics = MoveOrderingHeuristics();
    for (var ply = 0; ply < 4; ply += 1) {
      heuristics.recordQuietCutoff(
        state: position,
        move: quiet,
        ply: ply,
        remainingDepth: 4,
      );
    }

    final ordered = ordering.order(position, <Move>[
      quiet,
      capture,
    ], heuristics: heuristics);

    expect(ordered.first.id, capture.id);
  });

  test('keeps promotions ahead of quiet history moves', () {
    final position = state(<Piece>[
      piece('dark-promoter', PlayerSide.dark, 6, 1),
      piece('dark-runner', PlayerSide.dark, 2, 5),
      piece('light-far', PlayerSide.light, 0, 7),
    ]);
    final legalMoves = engine.legalMoves(position);
    final ordinary = legalMoves.firstWhere(
      (move) => move.pieceId == 'dark-runner',
    );
    final heuristics = MoveOrderingHeuristics();
    heuristics.recordQuietCutoff(
      state: position,
      move: ordinary,
      ply: 1,
      remainingDepth: 8,
    );

    final ordered = ordering.order(
      position,
      legalMoves,
      heuristics: heuristics,
      ply: 2,
    );

    expect(ordered.first.pieceId, 'dark-promoter');
  });

  test('keeps transposition preference ahead of learned heuristics', () {
    final position = engine.createInitialState();
    final legalMoves = engine.legalMoves(position);
    final killer = legalMoves.last;
    final preferred = legalMoves[legalMoves.length - 2];
    final heuristics = MoveOrderingHeuristics();
    heuristics.recordQuietCutoff(
      state: position,
      move: killer,
      ply: 0,
      remainingDepth: 4,
    );

    final ordered = ordering.order(
      position,
      legalMoves,
      preferredMoveId: preferred.id,
      heuristics: heuristics,
    );

    expect(ordered.first.id, preferred.id);
  });

  test('does not learn from capture cutoffs', () {
    final position = state(<Piece>[
      piece('dark-jumper', PlayerSide.dark, 2, 1),
      piece('light-target', PlayerSide.light, 3, 2),
    ]);
    final capture = engine.legalMoves(position).single;
    final heuristics = MoveOrderingHeuristics();

    heuristics.recordQuietCutoff(
      state: position,
      move: capture,
      ply: 0,
      remainingDepth: 4,
    );

    expect(heuristics.diagnostics.killerUpdates, 0);
    expect(heuristics.diagnostics.historyUpdates, 0);
  });

  test('does not mutate input and keeps deterministic tie breaking', () {
    final position = engine.createInitialState();
    final source = engine.legalMoves(position).reversed.toList();
    final originalIds = source.map((move) => move.id).toList();

    final ordered = ordering.order(position, source);

    expect(source.map((move) => move.id), originalIds);
    expect(
      ordered.map((move) => move.id),
      ordered.map((move) => move.id).toList()..sort(),
    );
    expect(() => ordered.clear(), throwsUnsupportedError);
  });
}
