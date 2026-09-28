import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();

  Piece piece(
    String id,
    PlayerSide side,
    int row,
    int column, {
    PieceRank rank = PieceRank.man,
  }) {
    return Piece(
      id: id,
      side: side,
      rank: rank,
      position: BoardPosition(row: row, column: column),
    );
  }

  GameState state(
    Iterable<Piece> pieces, {
    PlayerSide activeSide = PlayerSide.dark,
    GameStatus status = GameStatus.active,
    GameOutcome? outcome,
  }) {
    return GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: pieces,
      activeSide: activeSide,
      ply: 0,
      revision: 0,
      status: status,
      outcome: outcome,
    );
  }

  test('scores every position symmetrically by perspective', () {
    final evaluator = PositionEvaluator(rulesEngine: engine);
    final position = state(<Piece>[
      piece('dark-king', PlayerSide.dark, 3, 2, rank: PieceRank.king),
      piece('dark-man', PlayerSide.dark, 4, 5),
      piece('light-man', PlayerSide.light, 6, 1),
    ]);

    final dark = evaluator.evaluate(position, PlayerSide.dark);
    final light = evaluator.evaluate(position, PlayerSide.light);

    expect(dark.score, -light.score);
    expect(dark.material, greaterThan(0));
  });

  test('values kings above men', () {
    final evaluator = PositionEvaluator(
      rulesEngine: engine,
      weights: EvaluationWeights(advancement: 0, centerControl: 0, mobility: 0),
    );
    final position = state(<Piece>[
      piece('dark-king', PlayerSide.dark, 2, 1, rank: PieceRank.king),
      piece('light-man', PlayerSide.light, 5, 6),
    ]);

    expect(
      evaluator.evaluate(position, PlayerSide.dark).material,
      greaterThan(0),
    );
  });

  test('rewards uncrowned progress toward promotion', () {
    final evaluator = PositionEvaluator(
      rulesEngine: engine,
      weights: EvaluationWeights(
        man: 0,
        king: 0,
        centerControl: 0,
        mobility: 0,
      ),
    );
    final position = state(<Piece>[
      piece('dark-advanced', PlayerSide.dark, 5, 0),
      piece('light-less-advanced', PlayerSide.light, 5, 2),
    ]);

    expect(
      evaluator.evaluate(position, PlayerSide.dark).advancement,
      greaterThan(0),
    );
  });

  test('reports center control as a separate measurable term', () {
    final evaluator = PositionEvaluator(
      rulesEngine: engine,
      weights: EvaluationWeights(
        man: 0,
        king: 0,
        advancement: 0,
        centerControl: 10,
        mobility: 0,
      ),
    );
    final position = state(<Piece>[
      piece('dark-center', PlayerSide.dark, 3, 2),
      piece('light-edge', PlayerSide.light, 0, 1),
    ]);

    final evaluation = evaluator.evaluate(position, PlayerSide.dark);

    expect(evaluation.centerControl, 10);
    expect(evaluation.score, 10);
  });

  test('terminal wins dominate heuristic disadvantages', () {
    final evaluator = PositionEvaluator(rulesEngine: engine);
    final position = state(
      <Piece>[
        piece('light-king', PlayerSide.light, 5, 0, rank: PieceRank.king),
      ],
      status: GameStatus.completed,
      outcome: const GameOutcome.win(
        winner: PlayerSide.dark,
        reason: GameOutcomeReason.resignation,
      ),
    );

    final evaluation = evaluator.evaluate(position, PlayerSide.dark);

    expect(evaluation.terminal, evaluator.weights.terminal);
    expect(evaluation.score, greaterThan(0));
  });

  test('tactical terminal fixture scores both sides correctly', () {
    final start = state(<Piece>[
      piece('dark-jumper', PlayerSide.dark, 2, 1),
      piece('light-last', PlayerSide.light, 3, 2),
    ]);
    final winningMove = engine.legalMoves(start).single;
    final result = engine.applyMove(start, winningMove);
    final evaluator = PositionEvaluator(rulesEngine: engine);

    expect(result.status, GameStatus.completed);
    expect(evaluator.evaluate(result, PlayerSide.dark).score, greaterThan(0));
    expect(evaluator.evaluate(result, PlayerSide.light).score, lessThan(0));
  });

  test('validates weights and ruleset compatibility', () {
    expect(() => EvaluationWeights(man: -1), throwsArgumentError);
    expect(() => EvaluationWeights(terminal: 1), throwsArgumentError);

    final evaluator = PositionEvaluator(rulesEngine: engine);
    final incompatible = GameState(
      rulesetId: 'other-rules',
      boardSize: 8,
      pieces: <Piece>[
        piece('dark', PlayerSide.dark, 2, 1),
        piece('light', PlayerSide.light, 5, 0),
      ],
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );

    expect(
      () => evaluator.evaluate(incompatible, PlayerSide.dark),
      throwsArgumentError,
    );
  });
}
