import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();

  test('reduces a late quiet move but never the first move', () async {
    final tree = _LmrTree();
    final result = await FixedDepthAlphaBetaStrategy(
      rulesEngine: tree,
      transpositionTable: TranspositionTable(maxEntries: 0),
    ).chooseMove(tree.request(maxDepth: 4));
    final diagnostics = result.metadata.lateMoveReductions;

    expect(tree.appliedBranchMoves.first, tree.branchMoves.first.id);
    expect(diagnostics.candidates, greaterThan(0));
    expect(diagnostics.reductionsApplied, greaterThan(0));
    expect(diagnostics.reducedSearches, diagnostics.reductionsApplied);
    expect(
      diagnostics.reductionsApplied,
      lessThan(tree.appliedBranchMoves.length),
    );
  });

  test('never reduces captures or tactically forcing positions', () async {
    final tree = _LmrTree(captures: true);

    final result = await FixedDepthAlphaBetaStrategy(rulesEngine: tree)
        .chooseMove(tree.request(maxDepth: 4));

    expect(tree.appliedBranchMoves, isNotEmpty);
    expect(result.metadata.lateMoveReductions.candidates, 0);
    expect(result.metadata.lateMoveReductions.reductionsApplied, 0);
  });

  test('never reduces promotions', () async {
    final tree = _LmrTree(promotions: true);

    final result = await FixedDepthAlphaBetaStrategy(rulesEngine: tree)
        .chooseMove(tree.request(maxDepth: 4));

    expect(tree.appliedBranchMoves, isNotEmpty);
    expect(result.metadata.lateMoveReductions.candidates, 0);
    expect(result.metadata.lateMoveReductions.reductionsApplied, 0);
  });

  test('protects principal-variation and shallow nodes', () async {
    final pvTree = _LmrTree(branchFirst: true);
    final pvResult = await FixedDepthAlphaBetaStrategy(rulesEngine: pvTree)
        .chooseMove(pvTree.request(maxDepth: 4));
    final shallowTree = _LmrTree();
    final shallowResult = await FixedDepthAlphaBetaStrategy(
      rulesEngine: shallowTree,
    ).chooseMove(shallowTree.request(maxDepth: 3));

    expect(pvTree.appliedBranchMoves, isNotEmpty);
    expect(pvResult.metadata.lateMoveReductions.reductionsApplied, 0);
    expect(shallowTree.appliedBranchMoves, isNotEmpty);
    expect(shallowResult.metadata.lateMoveReductions.reductionsApplied, 0);
  });

  test('protects transposition and killer moves', () async {
    final ttTree = _LmrTree();
    final table = TranspositionTable();
    table.store(
      TranspositionKey.fromState(
        state: ttTree.branch,
        perspective: PlayerSide.dark,
        weights: EvaluationWeights(),
      ),
      TranspositionEntry(
        depth: 0,
        score: 0,
        bound: TranspositionBound.upper,
        bestMoveId: ttTree.branchMoves.last.id,
        generation: 0,
      ),
    );
    await FixedDepthAlphaBetaStrategy(
      rulesEngine: ttTree,
      transpositionTable: table,
      lateMoveReductions: LateMoveReductionConfig(minimumMoveIndex: 1),
    ).chooseMove(ttTree.request(maxDepth: 4));

    expect(ttTree.appliedBranchMoves.first, ttTree.branchMoves.last.id);

    final killerTree = _LmrTree();
    final heuristics = MoveOrderingHeuristics();
    heuristics.recordQuietCutoff(
      state: killerTree.branch,
      move: killerTree.branchMoves.last,
      ply: 1,
      remainingDepth: 3,
    );
    final outcome =
        await FixedDepthAlphaBetaStrategy(
          rulesEngine: killerTree,
          transpositionTable: TranspositionTable(maxEntries: 0),
          lateMoveReductions: LateMoveReductionConfig(minimumMoveIndex: 1),
        ).searchWithWindow(
          killerTree.request(maxDepth: 4),
          alpha: FixedDepthAlphaBetaStrategy.minimumScore,
          beta: FixedDepthAlphaBetaStrategy.maximumScore,
          orderingHeuristics: heuristics,
        );

    expect(killerTree.appliedBranchMoves.first, killerTree.branchMoves.last.id);
    expect(outcome.result.metadata.moveOrdering.killerHits, greaterThan(0));
  });

  test('re-searches a promising reduced move at full depth', () async {
    final tree = _LmrTree(promisingLastMove: true);

    final result = await FixedDepthAlphaBetaStrategy(
      rulesEngine: tree,
      transpositionTable: TranspositionTable(maxEntries: 0),
    ).chooseMove(tree.request(maxDepth: 4));
    final diagnostics = result.metadata.lateMoveReductions;

    expect(diagnostics.reductionsApplied, greaterThan(0));
    expect(diagnostics.fullDepthResearches, greaterThan(0));
    expect(diagnostics.reducedSearchCutoffs, greaterThan(0));
  });

  test('matches the baseline final move and exact score', () async {
    final position = engine.createInitialState();
    final request = _request(engine, position, maxDepth: 4);
    final lmr = FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      transpositionTable: TranspositionTable(maxEntries: 0),
    );
    final baseline = FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      transpositionTable: TranspositionTable(maxEntries: 0),
      lateMoveReductions: LateMoveReductionConfig.disabled(),
    );

    final lmrOutcome = await lmr.searchWithWindow(
      request,
      alpha: FixedDepthAlphaBetaStrategy.minimumScore,
      beta: FixedDepthAlphaBetaStrategy.maximumScore,
    );
    final baselineOutcome = await baseline.searchWithWindow(
      request,
      alpha: FixedDepthAlphaBetaStrategy.minimumScore,
      beta: FixedDepthAlphaBetaStrategy.maximumScore,
    );

    expect(lmrOutcome.result.move.id, baselineOutcome.result.move.id);
    expect(lmrOutcome.score, baselineOutcome.score);
    expect(lmrOutcome.bound, TranspositionBound.exact);
    expect(baselineOutcome.bound, TranspositionBound.exact);
    expect(
      lmrOutcome.result.metadata.lateMoveReductions.reductionsApplied,
      greaterThan(0),
    );
    expect(
      baselineOutcome.result.metadata.lateMoveReductions.reductionsApplied,
      0,
    );
  });

  test('remains deterministic and compatible with PVS', () async {
    final position = engine.createInitialState();
    final request = _request(engine, position, maxDepth: 4);

    final first = await FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      transpositionTable: TranspositionTable(maxEntries: 0),
    ).chooseMove(request);
    final second = await FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      transpositionTable: TranspositionTable(maxEntries: 0),
    ).chooseMove(request);

    expect(first.move.id, second.move.id);
    expect(
      first.metadata.lateMoveReductions.reductionsApplied,
      second.metadata.lateMoveReductions.reductionsApplied,
    );
    expect(
      first.metadata.principalVariationSearch.narrowWindowSearches,
      greaterThan(0),
    );
  });

  test('is compatible with aspiration-window iterative search', () async {
    final position = engine.createInitialState();
    final request = _request(engine, position, maxDepth: 4);
    final lmr = IterativeDeepeningStrategy(
      rulesEngine: engine,
      transpositionTable: TranspositionTable(maxEntries: 0),
      aspirationWindow: AspirationWindowConfig(initialHalfWidth: 1),
    );
    final baseline = IterativeDeepeningStrategy(
      rulesEngine: engine,
      transpositionTable: TranspositionTable(maxEntries: 0),
      aspirationWindow: AspirationWindowConfig(initialHalfWidth: 1),
      lateMoveReductions: LateMoveReductionConfig.disabled(),
    );

    final lmrResult = await lmr.chooseMove(request);
    final baselineResult = await baseline.chooseMove(request);

    expect(lmrResult.move.id, baselineResult.move.id);
    expect(lmrResult.metadata.completedDepth, 4);
    expect(lmrResult.metadata.aspiration.attempts, greaterThan(0));
    expect(
      lmrResult.metadata.lateMoveReductions.reductionsApplied,
      greaterThan(0),
    );
  });

  test('keeps quiescence results compatible', () async {
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
    final request = _request(engine, position, maxDepth: 4);
    final lmr = await FixedDepthAlphaBetaStrategy(rulesEngine: engine)
        .chooseMove(request);
    final baseline = await FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      lateMoveReductions: LateMoveReductionConfig.disabled(),
    ).chooseMove(request);

    expect(lmr.move.id, baseline.move.id);
    expect(lmr.metadata.quiescence.nodes, greaterThan(0));
  });

  test(
    'does not store an unverified reduction as a full-depth TT entry',
    () async {
      final tree = _LmrTree();
      final table = TranspositionTable();
      final strategy = FixedDepthAlphaBetaStrategy(
        rulesEngine: tree,
        transpositionTable: table,
      );
      final firstScore = tree.safeScore;

      final outcome = await strategy.searchWithWindow(
        tree.request(maxDepth: 4),
        alpha: firstScore - 1,
        beta: firstScore + 1,
      );
      final entry = table.probe(
        TranspositionKey.fromState(
          state: tree.branch,
          perspective: PlayerSide.dark,
          weights: EvaluationWeights(),
        ),
      );

      expect(
        outcome.result.metadata.lateMoveReductions.reductionsApplied,
        greaterThan(0),
      );
      expect(entry, isNull);
    },
  );

  test('preserves node-budget fallback and cancellation', () async {
    final position = engine.createInitialState();
    final limited = await FixedDepthAlphaBetaStrategy(rulesEngine: engine)
        .chooseMove(_request(engine, position, maxDepth: 5, maxNodes: 1));
    final controller = AiCancellationController()..cancel();

    expect(limited.metadata.nodesExamined, 1);
    expect(limited.metadata.completedDepth, 0);
    expect(limited.metadata.stopReason, SearchStopReason.nodeLimit);
    expect(engine.validateMove(position, limited.move).isValid, isTrue);
    await expectLater(
      FixedDepthAlphaBetaStrategy(rulesEngine: engine).chooseMove(
        _request(
          engine,
          position,
          maxDepth: 5,
          cancellationToken: controller.token,
        ),
      ),
      throwsA(isA<AiSearchCancelledException>()),
    );
  });
}

AiSearchRequest _request(
  RulesEngine engine,
  GameState state, {
  required int maxDepth,
  int? maxNodes,
  AiCancellationToken cancellationToken = const NoCancellationToken(),
}) {
  return AiSearchRequest(
    state: state,
    legalMoves: engine.legalMoves(state),
    budget: SearchBudget(maxDepth: maxDepth, maxNodes: maxNodes),
    cancellationToken: cancellationToken,
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

final class _LmrTree implements RulesEngine {
  _LmrTree({
    this.captures = false,
    this.promotions = false,
    this.branchFirst = false,
    this.promisingLastMove = false,
  }) {
    root = _state(
      darkPosition: BoardPosition(row: 2, column: 1),
      lightPosition: BoardPosition(row: promotions ? 1 : 5, column: 2),
      activeSide: PlayerSide.dark,
      revision: 0,
    );
    branch = _state(
      darkPosition: branchMove.destination,
      lightPosition: BoardPosition(row: promotions ? 1 : 5, column: 2),
      activeSide: PlayerSide.light,
      revision: 1,
    );
  }

  final bool captures;
  final bool promotions;
  final bool branchFirst;
  final bool promisingLastMove;
  late final GameState root;
  late final GameState branch;
  final List<String> appliedBranchMoves = <String>[];

  Move get safeMove => Move(
    id: branchFirst ? 'b-safe' : 'a-safe',
    pieceId: 'dark',
    path: <BoardPosition>[
      BoardPosition(row: 2, column: 1),
      BoardPosition(row: 3, column: 0),
    ],
  );

  Move get branchMove => Move(
    id: branchFirst ? 'a-branch' : 'b-branch',
    pieceId: 'dark',
    path: <BoardPosition>[
      BoardPosition(row: 2, column: 1),
      BoardPosition(row: 3, column: 2),
    ],
  );

  List<Move> get branchMoves => <Move>[
    _branchMove('a-reply', 1),
    _branchMove('b-reply', 3),
    _branchMove('c-reply', 5),
  ];

  int get safeScore =>
      PositionEvaluator(rulesEngine: this)
          .evaluate(_safeTerminal(), PlayerSide.dark)
          .score;

  @override
  RulesetDescriptor get descriptor =>
      const AmericanCheckersRulesEngine().descriptor;

  @override
  GameState createInitialState() => root;

  AiSearchRequest request({required int maxDepth, int? maxNodes}) {
    return _request(this, root, maxDepth: maxDepth, maxNodes: maxNodes);
  }

  @override
  List<Move> legalMoves(GameState state) {
    if (state.status == GameStatus.completed) return const <Move>[];
    return state.revision == 0 ? <Move>[safeMove, branchMove] : branchMoves;
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
    if (state.revision == 0) {
      return move.id == branchMove.id ? branch : _safeTerminal();
    }
    appliedBranchMoves.add(move.id);
    final lightWins = promisingLastMove && move.id == branchMoves.last.id;
    return _terminal(move.destination, lightWins: lightWins);
  }

  Move _branchMove(String id, int destinationColumn) {
    final row = promotions ? 1 : 5;
    return Move(
      id: id,
      pieceId: 'light',
      path: <BoardPosition>[
        BoardPosition(row: row, column: 2),
        BoardPosition(row: promotions ? 0 : 4, column: destinationColumn),
      ],
      capturedPieceIds: captures ? <String>['dark'] : const <String>[],
    );
  }

  GameState _safeTerminal() {
    return _state(
      darkPosition: safeMove.destination,
      lightPosition: BoardPosition(row: promotions ? 1 : 5, column: 2),
      activeSide: PlayerSide.light,
      revision: 1,
      outcome: const GameOutcome.draw(reason: GameOutcomeReason.drawAgreement),
    );
  }

  GameState _terminal(BoardPosition lightPosition, {required bool lightWins}) {
    return _state(
      darkPosition: branchMove.destination,
      lightPosition: lightPosition,
      activeSide: PlayerSide.dark,
      revision: 2,
      outcome: GameOutcome.win(
        winner: lightWins ? PlayerSide.light : PlayerSide.dark,
        reason: GameOutcomeReason.noLegalMoves,
      ),
    );
  }

  GameState _state({
    required BoardPosition darkPosition,
    required BoardPosition lightPosition,
    required PlayerSide activeSide,
    required int revision,
    GameOutcome? outcome,
  }) {
    return GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: <Piece>[
        _piece('dark', PlayerSide.dark, darkPosition.row, darkPosition.column),
        _piece(
          'light',
          PlayerSide.light,
          lightPosition.row,
          lightPosition.column,
        ),
      ],
      activeSide: activeSide,
      ply: revision,
      revision: revision,
      status: outcome == null ? GameStatus.active : GameStatus.completed,
      outcome: outcome,
    );
  }
}
