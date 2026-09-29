import 'dart:io';

import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();

  test('matches baseline full-window alpha-beta move and score', () async {
    final position = engine.createInitialState();
    final request = _request(engine, position, maxDepth: 4);
    final pvs = FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      transpositionTable: TranspositionTable(maxEntries: 0),
    );
    final baseline = FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      transpositionTable: TranspositionTable(maxEntries: 0),
      usePrincipalVariationSearch: false,
    );

    final pvsOutcome = await pvs.searchWithWindow(
      request,
      alpha: FixedDepthAlphaBetaStrategy.minimumScore,
      beta: FixedDepthAlphaBetaStrategy.maximumScore,
    );
    final baselineOutcome = await baseline.searchWithWindow(
      request,
      alpha: FixedDepthAlphaBetaStrategy.minimumScore,
      beta: FixedDepthAlphaBetaStrategy.maximumScore,
    );

    expect(pvsOutcome.result.move.id, baselineOutcome.result.move.id);
    expect(pvsOutcome.score, baselineOutcome.score);
    expect(pvsOutcome.bound, TranspositionBound.exact);
    expect(baselineOutcome.bound, TranspositionBound.exact);
    expect(
      pvsOutcome.result.metadata.principalVariationSearch.narrowWindowSearches,
      greaterThan(0),
    );
    expect(
      baselineOutcome
          .result
          .metadata
          .principalVariationSearch
          .narrowWindowSearches,
      0,
    );
  });

  test(
    'searches the first move fully and re-searches a later fail high',
    () async {
      final tree = _PvsTree(firstMoveWins: false);
      final strategy = FixedDepthAlphaBetaStrategy(rulesEngine: tree);
      final expectedScore = tree.scoreFor(tree.secondMove);

      final outcome = await strategy.searchWithWindow(
        tree.request(maxDepth: 1),
        alpha: FixedDepthAlphaBetaStrategy.minimumScore,
        beta: FixedDepthAlphaBetaStrategy.maximumScore,
      );
      final diagnostics = outcome.result.metadata.principalVariationSearch;

      expect(outcome.result.move.id, tree.secondMove.id);
      expect(outcome.score, expectedScore);
      expect(diagnostics.firstMoveFullWindowSearches, 1);
      expect(diagnostics.narrowWindowSearches, 1);
      expect(diagnostics.fullWindowResearches, 1);
      expect(diagnostics.cutoffs, 0);
      expect(outcome.result.metadata.nodesExamined, 3);
    },
  );

  test('does not re-search a later move that fails low', () async {
    final tree = _PvsTree(firstMoveWins: true);
    final strategy = FixedDepthAlphaBetaStrategy(rulesEngine: tree);
    final expectedScore = tree.scoreFor(tree.firstMove);

    final outcome = await strategy.searchWithWindow(
      tree.request(maxDepth: 1),
      alpha: FixedDepthAlphaBetaStrategy.minimumScore,
      beta: FixedDepthAlphaBetaStrategy.maximumScore,
    );
    final diagnostics = outcome.result.metadata.principalVariationSearch;

    expect(outcome.result.move.id, tree.firstMove.id);
    expect(outcome.score, expectedScore);
    expect(diagnostics.firstMoveFullWindowSearches, 1);
    expect(diagnostics.narrowWindowSearches, 1);
    expect(diagnostics.fullWindowResearches, 0);
    expect(outcome.result.metadata.nodesExamined, 2);
  });

  test('records a cutoff produced directly by a narrow probe', () async {
    final tree = _PvsTree(firstMoveWins: false);
    final strategy = FixedDepthAlphaBetaStrategy(rulesEngine: tree);
    final firstScore = tree.scoreFor(tree.firstMove);

    final outcome = await strategy.searchWithWindow(
      tree.request(maxDepth: 1),
      alpha: firstScore - 1,
      beta: firstScore + 1,
    );
    final diagnostics = outcome.result.metadata.principalVariationSearch;

    expect(outcome.bound, TranspositionBound.lower);
    expect(diagnostics.narrowWindowSearches, 1);
    expect(diagnostics.fullWindowResearches, 0);
    expect(diagnostics.cutoffs, 1);
  });

  test('keeps narrow TT bounds non-exact until a full re-search', () async {
    final cutoffTree = _PvsTree(firstMoveWins: false, twoPly: true);
    final cutoffTable = TranspositionTable();
    final cutoffStrategy = FixedDepthAlphaBetaStrategy(
      rulesEngine: cutoffTree,
      transpositionTable: cutoffTable,
    );

    final cutoffCenter = cutoffTree.scoreFor(cutoffTree.firstMove);
    await cutoffStrategy.searchWithWindow(
      cutoffTree.request(maxDepth: 2),
      alpha: cutoffCenter - 1,
      beta: cutoffCenter + 1,
    );
    final cutoffEntry = cutoffTable.probe(
      TranspositionKey.fromState(
        state: cutoffTree.secondMiddle,
        perspective: PlayerSide.dark,
        weights: EvaluationWeights(),
      ),
    );

    expect(cutoffEntry?.bound, TranspositionBound.lower);

    final exactTree = _PvsTree(firstMoveWins: false, twoPly: true);
    final exactTable = TranspositionTable();
    final exactStrategy = FixedDepthAlphaBetaStrategy(
      rulesEngine: exactTree,
      transpositionTable: exactTable,
    );
    await exactStrategy.chooseMove(exactTree.request(maxDepth: 2));
    final exactEntry = exactTable.probe(
      TranspositionKey.fromState(
        state: exactTree.secondMiddle,
        perspective: PlayerSide.dark,
        weights: EvaluationWeights(),
      ),
    );

    expect(exactEntry?.bound, TranspositionBound.exact);
  });

  test('remains deterministic across independent searches', () async {
    final position = engine.createInitialState();
    final request = _request(engine, position, maxDepth: 4);

    final first = await FixedDepthAlphaBetaStrategy(rulesEngine: engine)
        .chooseMove(request);
    final second = await FixedDepthAlphaBetaStrategy(rulesEngine: engine)
        .chooseMove(request);

    expect(first.move.id, second.move.id);
    expect(
      first.metadata.principalVariationSearch.narrowWindowSearches,
      second.metadata.principalVariationSearch.narrowWindowSearches,
    );
    expect(
      first.metadata.principalVariationSearch.fullWindowResearches,
      second.metadata.principalVariationSearch.fullWindowResearches,
    );
  });

  test('is compatible with aspiration-window iterative search', () async {
    final position = engine.createInitialState();
    final request = _request(engine, position, maxDepth: 4);
    final pvs = IterativeDeepeningStrategy(
      rulesEngine: engine,
      aspirationWindow: AspirationWindowConfig(initialHalfWidth: 1),
    );
    final baseline = IterativeDeepeningStrategy(
      rulesEngine: engine,
      aspirationWindow: AspirationWindowConfig(initialHalfWidth: 1),
      usePrincipalVariationSearch: false,
    );

    final pvsResult = await pvs.chooseMove(request);
    final baselineResult = await baseline.chooseMove(request);

    expect(pvsResult.move.id, baselineResult.move.id);
    expect(pvsResult.metadata.completedDepth, 4);
    expect(pvsResult.metadata.aspiration.attempts, greaterThan(0));
    expect(
      pvsResult.metadata.principalVariationSearch.narrowWindowSearches,
      greaterThan(0),
    );
  });

  test('is compatible with quiescence and killer/history ordering', () async {
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
    final pvs = FixedDepthAlphaBetaStrategy(rulesEngine: engine);
    final baseline = FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      usePrincipalVariationSearch: false,
    );

    final pvsResult = await pvs.chooseMove(
      _request(engine, position, maxDepth: 2),
    );
    final baselineResult = await baseline.chooseMove(
      _request(engine, position, maxDepth: 2),
    );
    final iterativeResult = await IterativeDeepeningStrategy(
      rulesEngine: engine,
      transpositionTable: TranspositionTable(maxEntries: 0),
      aspirationWindow: AspirationWindowConfig.disabled(),
    ).chooseMove(_request(engine, engine.createInitialState(), maxDepth: 4));

    expect(pvsResult.move.id, baselineResult.move.id);
    expect(pvsResult.metadata.quiescence.nodes, greaterThan(0));
    expect(iterativeResult.metadata.moveOrdering.killerHits, greaterThan(0));
    expect(iterativeResult.metadata.moveOrdering.historyHits, greaterThan(0));
    expect(
      iterativeResult.metadata.principalVariationSearch.narrowWindowSearches,
      greaterThan(0),
    );
  });

  test('charges an interrupted full re-search to the node budget', () async {
    final tree = _PvsTree(firstMoveWins: false);
    final strategy = FixedDepthAlphaBetaStrategy(
      rulesEngine: tree,
      transpositionTable: TranspositionTable(maxEntries: 0),
    );

    final result = await strategy.chooseMove(
      tree.request(maxDepth: 1, maxNodes: 2),
    );

    expect(result.move.id, tree.firstMove.id);
    expect(result.metadata.nodesExamined, 2);
    expect(result.metadata.completedDepth, 0);
    expect(result.metadata.stopReason, SearchStopReason.nodeLimit);
    expect(result.metadata.principalVariationSearch.fullWindowResearches, 1);
  });

  test('preserves the last completed depth when PVS is interrupted', () async {
    final tree = _PvsTree(firstMoveWins: false);
    final strategy = IterativeDeepeningStrategy(
      rulesEngine: tree,
      transpositionTable: TranspositionTable(maxEntries: 0),
      aspirationWindow: AspirationWindowConfig.disabled(),
    );

    final result = await strategy.chooseMove(
      tree.request(maxDepth: 2, maxNodes: 4),
    );

    expect(result.move.id, tree.secondMove.id);
    expect(result.metadata.completedDepth, 1);
    expect(result.metadata.nodesExamined, 4);
    expect(result.metadata.stopReason, SearchStopReason.nodeLimit);
  });

  test('applies time and cancellation limits to PVS work', () async {
    final delayedTree = _DelayedRulesEngine(_PvsTree(firstMoveWins: false));
    final timed = await FixedDepthAlphaBetaStrategy(rulesEngine: delayedTree)
        .chooseMove(
          _request(
            delayedTree,
            delayedTree.createInitialState(),
            maxDepth: 1,
            maxDuration: const Duration(milliseconds: 1),
          ),
        );

    expect(timed.metadata.completedDepth, 0);
    expect(timed.metadata.stopReason, SearchStopReason.timeLimit);

    final tree = _PvsTree(firstMoveWins: false);
    final token = _CancelAfterChecks(6);
    await expectLater(
      FixedDepthAlphaBetaStrategy(rulesEngine: tree)
          .chooseMove(tree.request(maxDepth: 1, cancellationToken: token)),
      throwsA(isA<AiSearchCancelledException>()),
    );
    expect(token.checks, 6);
  });
}

AiSearchRequest _request(
  RulesEngine engine,
  GameState state, {
  required int maxDepth,
  int? maxNodes,
  Duration? maxDuration,
  AiCancellationToken cancellationToken = const NoCancellationToken(),
}) {
  return AiSearchRequest(
    state: state,
    legalMoves: engine.legalMoves(state),
    budget: SearchBudget(
      maxDepth: maxDepth,
      maxNodes: maxNodes,
      maxDuration: maxDuration,
    ),
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

final class _PvsTree implements RulesEngine {
  _PvsTree({required this.firstMoveWins, this.twoPly = false}) {
    root = _state(
      darkPosition: BoardPosition(row: 2, column: 1),
      lightPosition: BoardPosition(row: 5, column: 6),
      activeSide: PlayerSide.dark,
      revision: 0,
    );
    firstMiddle = _state(
      darkPosition: firstMove.destination,
      lightPosition: BoardPosition(row: 5, column: 6),
      activeSide: PlayerSide.light,
      revision: 1,
    );
    secondMiddle = _state(
      darkPosition: secondMove.destination,
      lightPosition: BoardPosition(row: 5, column: 6),
      activeSide: PlayerSide.light,
      revision: 1,
    );
  }

  final bool firstMoveWins;
  final bool twoPly;
  late final GameState root;
  late final GameState firstMiddle;
  late final GameState secondMiddle;

  final Move firstMove = Move(
    id: 'a-first',
    pieceId: 'dark',
    path: <BoardPosition>[
      BoardPosition(row: 2, column: 1),
      BoardPosition(row: 3, column: 0),
    ],
  );
  final Move secondMove = Move(
    id: 'b-second',
    pieceId: 'dark',
    path: <BoardPosition>[
      BoardPosition(row: 2, column: 1),
      BoardPosition(row: 3, column: 2),
    ],
  );
  final Move replyMove = Move(
    id: 'reply',
    pieceId: 'light',
    path: <BoardPosition>[
      BoardPosition(row: 5, column: 6),
      BoardPosition(row: 4, column: 5),
    ],
  );

  @override
  RulesetDescriptor get descriptor =>
      const AmericanCheckersRulesEngine().descriptor;

  @override
  GameState createInitialState() => root;

  AiSearchRequest request({
    required int maxDepth,
    int? maxNodes,
    AiCancellationToken cancellationToken = const NoCancellationToken(),
  }) {
    return _request(
      this,
      root,
      maxDepth: maxDepth,
      maxNodes: maxNodes,
      cancellationToken: cancellationToken,
    );
  }

  int scoreFor(Move move) {
    var state = applyMove(root, move);
    if (twoPly) {
      state = applyMove(state, replyMove);
    }
    return PositionEvaluator(rulesEngine: this)
        .evaluate(state, PlayerSide.dark)
        .score;
  }

  @override
  List<Move> legalMoves(GameState state) {
    if (state.status == GameStatus.completed) return const <Move>[];
    return state.revision == 0
        ? <Move>[firstMove, secondMove]
        : <Move>[replyMove];
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
      final first = move.id == firstMove.id;
      if (twoPly) return first ? firstMiddle : secondMiddle;
      return _terminal(move.destination, firstWins: first == firstMoveWins);
    }
    final first = state.positionHash == firstMiddle.positionHash;
    return _terminal(
      state.board.pieceById('dark')!.position,
      firstWins: first == firstMoveWins,
      revision: 2,
    );
  }

  GameState _terminal(
    BoardPosition darkPosition, {
    required bool firstWins,
    int revision = 1,
  }) {
    return _state(
      darkPosition: darkPosition,
      lightPosition: revision == 1
          ? BoardPosition(row: 5, column: 6)
          : replyMove.destination,
      activeSide: revision.isOdd ? PlayerSide.light : PlayerSide.dark,
      revision: revision,
      outcome: firstWins
          ? const GameOutcome.win(
              winner: PlayerSide.dark,
              reason: GameOutcomeReason.noLegalMoves,
            )
          : const GameOutcome.draw(reason: GameOutcomeReason.drawAgreement),
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

final class _DelayedRulesEngine implements RulesEngine {
  _DelayedRulesEngine(this.delegate);

  final RulesEngine delegate;

  @override
  RulesetDescriptor get descriptor => delegate.descriptor;

  @override
  GameState createInitialState() => delegate.createInitialState();

  @override
  List<Move> legalMoves(GameState state) => delegate.legalMoves(state);

  @override
  MoveValidation validateMove(GameState state, Move move) {
    return delegate.validateMove(state, move);
  }

  @override
  GameState applyMove(GameState state, Move move) {
    sleep(const Duration(milliseconds: 10));
    return delegate.applyMove(state, move);
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
