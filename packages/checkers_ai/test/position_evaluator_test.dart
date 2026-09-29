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
    Map<String, int> ruleCounters = const <String, int>{},
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
      ruleCounters: ruleCounters,
    );
  }

  EndgameEvaluationWeights endgameWeights({
    int materialThreshold = 6,
    int kingActivity = 0,
    int kingCentralization = 0,
    int promotionProximity = 0,
    int mobility = 0,
    int trappedPiece = 0,
    int edgeSafety = 0,
    int conversionPressure = 0,
    int drawRisk = 0,
  }) {
    return EndgameEvaluationWeights(
      materialThreshold: materialThreshold,
      kingActivity: kingActivity,
      kingCentralization: kingCentralization,
      promotionProximity: promotionProximity,
      mobility: mobility,
      trappedPiece: trappedPiece,
      edgeSafety: edgeSafety,
      conversionPressure: conversionPressure,
      drawRisk: drawRisk,
    );
  }

  EvaluationWeights neutralWeights() => EvaluationWeights(
    man: 0,
    king: 0,
    advancement: 0,
    centerControl: 0,
    mobility: 0,
  );

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

  group('endgame evaluation', () {
    test('prefers a centralized king', () {
      final evaluator = PositionEvaluator(
        rulesEngine: engine,
        weights: neutralWeights(),
        endgameWeights: endgameWeights(kingCentralization: 5),
      );
      final position = state(<Piece>[
        piece('dark-center', PlayerSide.dark, 3, 2, rank: PieceRank.king),
        piece('light-edge', PlayerSide.light, 7, 0, rank: PieceRank.king),
      ]);

      final evaluation = evaluator.evaluate(position, PlayerSide.dark);

      expect(evaluation.endgameActive, isTrue);
      expect(evaluation.kingCentralization, 10);
      expect(evaluation.score, 10);
    });

    test('scores the leading promotion race', () {
      final evaluator = PositionEvaluator(
        rulesEngine: engine,
        weights: neutralWeights(),
        endgameWeights: endgameWeights(promotionProximity: 6),
      );
      final position = state(<Piece>[
        piece('dark-near-promotion', PlayerSide.dark, 5, 0),
        piece('light-farther-away', PlayerSide.light, 3, 6),
      ]);

      final evaluation = evaluator.evaluate(position, PlayerSide.dark);

      expect(evaluation.promotionProximity, 6);
      expect(evaluation.score, 6);
    });

    test('penalizes an individually trapped king', () {
      final evaluator = PositionEvaluator(
        rulesEngine: engine,
        weights: neutralWeights(),
        endgameWeights: endgameWeights(trappedPiece: 20),
      );
      final position = state(<Piece>[
        piece('dark-trapped', PlayerSide.dark, 0, 1, rank: PieceRank.king),
        piece('dark-block-left', PlayerSide.dark, 1, 0),
        piece('dark-block-right', PlayerSide.dark, 1, 2),
        piece('light-king', PlayerSide.light, 6, 1, rank: PieceRank.king),
      ]);

      final evaluation = evaluator.evaluate(position, PlayerSide.dark);

      expect(evaluation.trappedPieces, -20);
      expect(evaluation.score, -20);
    });

    test('rewards greater active-side mobility', () {
      final evaluator = PositionEvaluator(
        rulesEngine: engine,
        weights: neutralWeights(),
        endgameWeights: endgameWeights(mobility: 3),
      );
      final mobile = state(<Piece>[
        piece('dark-king', PlayerSide.dark, 3, 2, rank: PieceRank.king),
        piece('light-king', PlayerSide.light, 7, 0, rank: PieceRank.king),
      ]);
      final constrained = state(<Piece>[
        piece('dark-king', PlayerSide.dark, 0, 1, rank: PieceRank.king),
        piece('light-king', PlayerSide.light, 7, 0, rank: PieceRank.king),
      ]);

      final mobileScore = evaluator.evaluate(mobile, PlayerSide.dark);
      final constrainedScore = evaluator.evaluate(constrained, PlayerSide.dark);

      expect(
        mobileScore.endgameMobility,
        greaterThan(constrainedScore.endgameMobility),
      );
    });

    test('increases conversion pressure for a material leader', () {
      final evaluator = PositionEvaluator(
        rulesEngine: engine,
        weights: neutralWeights(),
        endgameWeights: endgameWeights(conversionPressure: 10),
      );
      final position = state(<Piece>[
        piece('dark-king', PlayerSide.dark, 2, 1, rank: PieceRank.king),
        piece('dark-man', PlayerSide.dark, 4, 3),
        piece('light-king', PlayerSide.light, 6, 5, rank: PieceRank.king),
      ]);

      final evaluation = evaluator.evaluate(position, PlayerSide.dark);

      expect(evaluation.conversionPressure, 40);
      expect(evaluation.score, 40);
    });

    test(
      'reduces a material lead near a draw and neutralizes a drawn game',
      () {
        final evaluator = PositionEvaluator(
          rulesEngine: engine,
          endgameWeights: endgameWeights(drawRisk: 8),
        );
        final pieces = <Piece>[
          piece('dark-king', PlayerSide.dark, 2, 1, rank: PieceRank.king),
          piece('dark-man', PlayerSide.dark, 4, 3),
          piece('light-king', PlayerSide.light, 6, 5, rank: PieceRank.king),
        ];
        final ordinary = state(pieces);
        final nearDraw = state(
          pieces,
          ruleCounters: const <String, int>{
            AmericanCheckersRulesEngine.noProgressPlyCounter: 70,
          },
        );
        final drawn = state(
          pieces,
          status: GameStatus.completed,
          outcome: const GameOutcome.draw(reason: GameOutcomeReason.moveLimit),
        );
        final won = state(
          pieces,
          status: GameStatus.completed,
          outcome: const GameOutcome.win(
            winner: PlayerSide.dark,
            reason: GameOutcomeReason.noLegalMoves,
          ),
        );

        final ordinaryEvaluation = evaluator.evaluate(
          ordinary,
          PlayerSide.dark,
        );
        final nearDrawEvaluation = evaluator.evaluate(
          nearDraw,
          PlayerSide.dark,
        );

        expect(nearDrawEvaluation.drawRisk, -56);
        expect(nearDrawEvaluation.score, lessThan(ordinaryEvaluation.score));
        expect(evaluator.evaluate(drawn, PlayerSide.dark).score, 0);
        expect(evaluator.evaluate(drawn, PlayerSide.light).score, 0);
        expect(evaluator.evaluate(won, PlayerSide.dark).score, greaterThan(0));
        expect(evaluator.evaluate(won, PlayerSide.light).score, lessThan(0));
        expect(evaluator.evaluate(won, PlayerSide.dark).conversionPressure, 0);
      },
    );

    test('returns the same evaluation for repeated calls', () {
      final evaluator = PositionEvaluator(
        rulesEngine: engine,
        endgameWeights: EndgameEvaluationWeights(),
      );
      final position = state(<Piece>[
        piece('dark-king', PlayerSide.dark, 2, 1, rank: PieceRank.king),
        piece('dark-man', PlayerSide.dark, 4, 3),
        piece('light-king', PlayerSide.light, 6, 5, rank: PieceRank.king),
      ]);

      final first = evaluator.evaluate(position, PlayerSide.dark);
      final second = evaluator.evaluate(position, PlayerSide.dark);

      expect(second.score, first.score);
      expect(second.kingActivity, first.kingActivity);
      expect(second.conversionPressure, first.conversionPressure);
    });

    test('keeps every active endgame term symmetric by perspective', () {
      final evaluator = PositionEvaluator(
        rulesEngine: engine,
        endgameWeights: EndgameEvaluationWeights(),
      );
      final position = state(
        <Piece>[
          piece('dark-king', PlayerSide.dark, 2, 1, rank: PieceRank.king),
          piece('dark-man', PlayerSide.dark, 4, 3),
          piece('light-king', PlayerSide.light, 6, 5, rank: PieceRank.king),
        ],
        ruleCounters: const <String, int>{
          AmericanCheckersRulesEngine.noProgressPlyCounter: 40,
        },
      );

      final dark = evaluator.evaluate(position, PlayerSide.dark);
      final light = evaluator.evaluate(position, PlayerSide.light);

      expect(dark.score, -light.score);
      expect(dark.kingActivity, -light.kingActivity);
      expect(dark.endgameMobility, -light.endgameMobility);
      expect(dark.drawRisk, -light.drawRisk);
    });

    test('leaves middlegame evaluation unchanged above the threshold', () {
      final baseline = PositionEvaluator(rulesEngine: engine);
      final aware = PositionEvaluator(
        rulesEngine: engine,
        endgameWeights: EndgameEvaluationWeights(materialThreshold: 6),
      );
      final opening = engine.createInitialState();

      final baselineEvaluation = baseline.evaluate(opening, PlayerSide.dark);
      final awareEvaluation = aware.evaluate(opening, PlayerSide.dark);

      expect(awareEvaluation.endgameActive, isFalse);
      expect(awareEvaluation.score, baselineEvaluation.score);
      expect(awareEvaluation.material, baselineEvaluation.material);
      expect(awareEvaluation.advancement, baselineEvaluation.advancement);
      expect(awareEvaluation.centerControl, baselineEvaluation.centerControl);
      expect(awareEvaluation.mobility, baselineEvaluation.mobility);
    });

    test('validates endgame threshold and weights', () {
      expect(
        () => EndgameEvaluationWeights(materialThreshold: 1),
        throwsArgumentError,
      );
      expect(
        () => EndgameEvaluationWeights(trappedPiece: -1),
        throwsArgumentError,
      );
    });
  });
}
