import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  test(
    'completes in the initial window when the score remains nearby',
    () async {
      final tree = _SearchTree(winner: PlayerSide.dark);
      final strategy = IterativeDeepeningStrategy(
        rulesEngine: tree,
        aspirationWindow: AspirationWindowConfig(initialHalfWidth: 200000),
      );

      final result = await strategy.chooseMove(tree.request(maxDepth: 2));

      expect(result.metadata.completedDepth, 2);
      expect(result.metadata.aspiration.attempts, 1);
      expect(result.metadata.aspiration.failLow, 0);
      expect(result.metadata.aspiration.failHigh, 0);
      expect(result.metadata.aspiration.reSearches, 0);
      expect(result.metadata.aspiration.maximumWindowWidth, 400000);
      expect(result.metadata.aspiration.fullWindowFallback, isFalse);
    },
  );

  test('widens and re-searches after a fail high', () async {
    final tree = _SearchTree(winner: PlayerSide.dark);
    final strategy = IterativeDeepeningStrategy(
      rulesEngine: tree,
      aspirationWindow: AspirationWindowConfig(initialHalfWidth: 60000),
    );

    final result = await strategy.chooseMove(tree.request(maxDepth: 2));

    expect(result.metadata.completedDepth, 2);
    expect(result.metadata.aspiration.attempts, 2);
    expect(result.metadata.aspiration.failHigh, 1);
    expect(result.metadata.aspiration.failLow, 0);
    expect(result.metadata.aspiration.reSearches, 1);
    expect(result.metadata.aspiration.fullWindowFallback, isFalse);
  });

  test('widens and re-searches after a fail low', () async {
    final tree = _SearchTree(winner: PlayerSide.light);
    final strategy = IterativeDeepeningStrategy(
      rulesEngine: tree,
      aspirationWindow: AspirationWindowConfig(initialHalfWidth: 60000),
    );

    final result = await strategy.chooseMove(tree.request(maxDepth: 2));

    expect(result.metadata.completedDepth, 2);
    expect(result.metadata.aspiration.attempts, 2);
    expect(result.metadata.aspiration.failLow, 1);
    expect(result.metadata.aspiration.failHigh, 0);
    expect(result.metadata.aspiration.reSearches, 1);
    expect(result.metadata.aspiration.fullWindowFallback, isFalse);
  });

  test('falls back to the full window after repeated widening', () async {
    final tree = _SearchTree(winner: PlayerSide.dark);
    final strategy = IterativeDeepeningStrategy(
      rulesEngine: tree,
      aspirationWindow: AspirationWindowConfig(
        initialHalfWidth: 1,
        maxWindowedAttempts: 2,
      ),
    );

    final result = await strategy.chooseMove(tree.request(maxDepth: 2));

    expect(result.metadata.completedDepth, 2);
    expect(result.metadata.aspiration.attempts, 3);
    expect(result.metadata.aspiration.failHigh, 2);
    expect(result.metadata.aspiration.reSearches, 2);
    expect(
      result.metadata.aspiration.maximumWindowWidth,
      FixedDepthAlphaBetaStrategy.maximumScore -
          FixedDepthAlphaBetaStrategy.minimumScore,
    );
    expect(result.metadata.aspiration.fullWindowFallback, isTrue);
  });

  test('matches full-window iterative search', () async {
    const engine = AmericanCheckersRulesEngine();
    final position = engine.createInitialState();
    final request = _request(engine, position, maxDepth: 3);
    final aspiration = IterativeDeepeningStrategy(
      rulesEngine: engine,
      aspirationWindow: AspirationWindowConfig(initialHalfWidth: 1),
    );
    final fullWindow = IterativeDeepeningStrategy(
      rulesEngine: engine,
      aspirationWindow: AspirationWindowConfig.disabled(),
    );

    final aspirationResult = await aspiration.chooseMove(request);
    final fullWindowResult = await fullWindow.chooseMove(request);

    expect(aspirationResult.move.id, fullWindowResult.move.id);
    expect(aspirationResult.metadata.completedDepth, 3);
    expect(fullWindowResult.metadata.completedDepth, 3);
  });

  test('remains deterministic across independent searches', () async {
    const engine = AmericanCheckersRulesEngine();
    final position = engine.createInitialState();
    final request = _request(engine, position, maxDepth: 3);

    final first = await IterativeDeepeningStrategy(rulesEngine: engine)
        .chooseMove(request);
    final second = await IterativeDeepeningStrategy(rulesEngine: engine)
        .chooseMove(request);

    expect(first.move.id, second.move.id);
    expect(
      first.metadata.aspiration.attempts,
      second.metadata.aspiration.attempts,
    );
    expect(
      first.metadata.aspiration.failLow,
      second.metadata.aspiration.failLow,
    );
    expect(
      first.metadata.aspiration.failHigh,
      second.metadata.aspiration.failHigh,
    );
  });

  test(
    'preserves the last completed depth when a re-search exhausts nodes',
    () async {
      final tree = _SearchTree(winner: PlayerSide.dark);
      final strategy = IterativeDeepeningStrategy(
        rulesEngine: tree,
        transpositionTable: TranspositionTable(maxEntries: 0),
        aspirationWindow: AspirationWindowConfig(initialHalfWidth: 60000),
      );

      final result = await strategy.chooseMove(
        tree.request(maxDepth: 2, maxNodes: 4),
      );

      expect(result.move.id, tree.rootMove.id);
      expect(result.metadata.completedDepth, 1);
      expect(result.metadata.nodesExamined, 4);
      expect(result.metadata.stopReason, SearchStopReason.nodeLimit);
      expect(result.metadata.aspiration.attempts, 2);
      expect(result.metadata.aspiration.failHigh, 1);
      expect(result.metadata.aspiration.reSearches, 1);
    },
  );

  test('checks cancellation during a re-search', () async {
    final tree = _SearchTree(winner: PlayerSide.dark);
    final token = _CancelAfterChecks(16);
    final strategy = IterativeDeepeningStrategy(
      rulesEngine: tree,
      transpositionTable: TranspositionTable(maxEntries: 0),
      aspirationWindow: AspirationWindowConfig(initialHalfWidth: 60000),
    );

    await expectLater(
      strategy.chooseMove(tree.request(maxDepth: 2, cancellationToken: token)),
      throwsA(isA<AiSearchCancelledException>()),
    );
    expect(token.checks, 16);
  });

  test('reuses valid transposition bounds across re-searches', () async {
    final tree = _SearchTree(winner: PlayerSide.dark);
    final strategy = IterativeDeepeningStrategy(
      rulesEngine: tree,
      aspirationWindow: AspirationWindowConfig(
        initialHalfWidth: 1,
        maxWindowedAttempts: 2,
      ),
    );

    final result = await strategy.chooseMove(tree.request(maxDepth: 2));

    expect(result.metadata.completedDepth, 2);
    expect(result.metadata.transposition.boundHits, greaterThan(0));
    expect(result.metadata.aspiration.fullWindowFallback, isTrue);
  });

  test('preserves quiescence results under aspiration re-search', () async {
    const engine = AmericanCheckersRulesEngine();
    final position = GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: <Piece>[
        _piece('dark-man', PlayerSide.dark, 2, 1),
        _piece('light-man', PlayerSide.light, 4, 3),
      ],
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );
    final request = _request(engine, position, maxDepth: 2);
    final aspiration = IterativeDeepeningStrategy(
      rulesEngine: engine,
      aspirationWindow: AspirationWindowConfig(initialHalfWidth: 1),
    );
    final fullWindow = IterativeDeepeningStrategy(
      rulesEngine: engine,
      aspirationWindow: AspirationWindowConfig.disabled(),
    );

    final aspirationResult = await aspiration.chooseMove(request);
    final fullWindowResult = await fullWindow.chooseMove(request);

    expect(aspirationResult.move.id, fullWindowResult.move.id);
    expect(aspirationResult.metadata.quiescence.nodes, greaterThan(0));
    expect(aspirationResult.metadata.completedDepth, 2);
  });
}

AiSearchRequest _request(
  RulesEngine engine,
  GameState state, {
  required int maxDepth,
}) {
  return AiSearchRequest(
    state: state,
    legalMoves: engine.legalMoves(state),
    budget: SearchBudget(maxDepth: maxDepth),
  );
}

Piece _piece(String id, PlayerSide side, int row, int column) {
  return Piece(
    id: id,
    side: side,
    rank: PieceRank.man,
    position: BoardPosition(row: row, column: column),
  );
}

final class _SearchTree implements RulesEngine {
  _SearchTree({required PlayerSide winner}) {
    root = GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: <Piece>[
        _piece('dark-man', PlayerSide.dark, 2, 1),
        _piece('light-man', PlayerSide.light, 5, 6),
      ],
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );
    middle = GameState(
      rulesetId: root.rulesetId,
      boardSize: root.boardSize,
      pieces: <Piece>[
        _piece('dark-man', PlayerSide.dark, 3, 0),
        _piece('light-man', PlayerSide.light, 5, 6),
      ],
      activeSide: PlayerSide.light,
      ply: 1,
      revision: 1,
      previousPositionHashes: root.positionHistory,
    );
    terminal = GameState(
      rulesetId: root.rulesetId,
      boardSize: root.boardSize,
      pieces: <Piece>[
        _piece('dark-man', PlayerSide.dark, 3, 0),
        _piece('light-man', PlayerSide.light, 4, 7),
      ],
      activeSide: PlayerSide.dark,
      ply: 2,
      revision: 2,
      previousPositionHashes: middle.positionHistory,
      status: GameStatus.completed,
      outcome: GameOutcome.win(
        winner: winner,
        reason: GameOutcomeReason.noLegalMoves,
      ),
    );
  }

  late final GameState root;
  late final GameState middle;
  late final GameState terminal;
  final Move rootMove = Move(
    id: 'root',
    pieceId: 'dark-man',
    path: <BoardPosition>[
      BoardPosition(row: 2, column: 1),
      BoardPosition(row: 3, column: 0),
    ],
  );
  final Move replyMove = Move(
    id: 'reply',
    pieceId: 'light-man',
    path: <BoardPosition>[
      BoardPosition(row: 5, column: 6),
      BoardPosition(row: 4, column: 7),
    ],
  );

  @override
  RulesetDescriptor get descriptor =>
      const AmericanCheckersRulesEngine().descriptor;

  AiSearchRequest request({
    required int maxDepth,
    int? maxNodes,
    AiCancellationToken cancellationToken = const NoCancellationToken(),
  }) {
    return AiSearchRequest(
      state: root,
      legalMoves: legalMoves(root),
      budget: SearchBudget(maxDepth: maxDepth, maxNodes: maxNodes),
      cancellationToken: cancellationToken,
    );
  }

  @override
  GameState createInitialState() => root;

  @override
  List<Move> legalMoves(GameState state) {
    return switch (state.revision) {
      0 => <Move>[rootMove],
      1 => <Move>[replyMove],
      _ => const <Move>[],
    };
  }

  @override
  MoveValidation validateMove(GameState state, Move move) {
    return legalMoves(state).any((candidate) => candidate.id == move.id)
        ? const MoveValidation.valid()
        : const MoveValidation.invalid(MoveRejectionCode.illegalMovement);
  }

  @override
  GameState applyMove(GameState state, Move move) {
    if (!validateMove(state, move).isValid) {
      throw StateError('Illegal test-tree move ${move.id}.');
    }
    return state.revision == 0 ? middle : terminal;
  }
}

final class _CancelAfterChecks implements AiCancellationToken {
  _CancelAfterChecks(this.cancelAt);

  final int cancelAt;
  int checks = 0;

  @override
  bool get isCancelled {
    checks += 1;
    return checks >= cancelAt;
  }
}
