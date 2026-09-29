import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();

  AiSearchRequest openingRequest({
    required int maxDepth,
    int? maxNodes,
    AiCancellationToken cancellationToken = const NoCancellationToken(),
  }) {
    final state = engine.createInitialState();
    return AiSearchRequest(
      state: state,
      legalMoves: engine.legalMoves(state),
      budget: SearchBudget(maxDepth: maxDepth, maxNodes: maxNodes),
      cancellationToken: cancellationToken,
    );
  }

  test('resets heuristic state between independent fixed searches', () async {
    final strategy = FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      transpositionTable: TranspositionTable(maxEntries: 0),
    );
    final request = openingRequest(maxDepth: 4);

    final first = await strategy.chooseMove(request);
    final second = await strategy.chooseMove(request);

    expect(first.move.id, second.move.id);
    expect(first.metadata.moveOrdering.killerUpdates, greaterThan(0));
    expect(
      second.metadata.moveOrdering.killerUpdates,
      first.metadata.moveOrdering.killerUpdates,
    );
    expect(
      second.metadata.moveOrdering.historyUpdates,
      first.metadata.moveOrdering.historyUpdates,
    );
    expect(
      second.metadata.moveOrdering.killerHits,
      first.metadata.moveOrdering.killerHits,
    );
    expect(
      second.metadata.moveOrdering.historyHits,
      first.metadata.moveOrdering.historyHits,
    );
  });

  test('reuses heuristics across iterative depths in one request', () async {
    final strategy = IterativeDeepeningStrategy(
      rulesEngine: engine,
      transpositionTable: TranspositionTable(maxEntries: 0),
      aspirationWindow: AspirationWindowConfig.disabled(),
    );

    final result = await strategy.chooseMove(openingRequest(maxDepth: 4));

    expect(result.metadata.completedDepth, 4);
    expect(result.metadata.moveOrdering.killerUpdates, greaterThan(0));
    expect(result.metadata.moveOrdering.historyUpdates, greaterThan(0));
    expect(result.metadata.moveOrdering.killerHits, greaterThan(0));
    expect(result.metadata.moveOrdering.historyHits, greaterThan(0));
    expect(
      result.metadata.moveOrdering.reorderedQuietBetaCutoffs,
      greaterThan(0),
    );
  });

  test('shares heuristics across aspiration re-searches', () async {
    final strategy = IterativeDeepeningStrategy(
      rulesEngine: engine,
      aspirationWindow: AspirationWindowConfig(initialHalfWidth: 1),
    );

    final result = await strategy.chooseMove(openingRequest(maxDepth: 4));

    expect(result.metadata.completedDepth, 4);
    expect(result.metadata.aspiration.attempts, greaterThan(0));
    expect(result.metadata.moveOrdering.killerHits, greaterThan(0));
    expect(result.metadata.moveOrdering.historyHits, greaterThan(0));
  });

  test('keeps quiescence capture search compatible', () async {
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
    final request = AiSearchRequest(
      state: position,
      legalMoves: engine.legalMoves(position),
      budget: SearchBudget(maxDepth: 2),
    );
    final iterative = IterativeDeepeningStrategy(rulesEngine: engine);
    final fixed = FixedDepthAlphaBetaStrategy(rulesEngine: engine);

    final iterativeResult = await iterative.chooseMove(request);
    final fixedResult = await fixed.chooseMove(request);

    expect(iterativeResult.move.id, fixedResult.move.id);
    expect(iterativeResult.metadata.quiescence.nodes, greaterThan(0));
  });

  test('matches the final move from a full fixed-depth search', () async {
    final request = openingRequest(maxDepth: 4);
    final iterative = IterativeDeepeningStrategy(rulesEngine: engine);
    final fixed = FixedDepthAlphaBetaStrategy(rulesEngine: engine);

    final iterativeResult = await iterative.chooseMove(request);
    final fixedResult = await fixed.chooseMove(request);

    expect(iterativeResult.move.id, fixedResult.move.id);
    expect(iterativeResult.metadata.completedDepth, 4);
    expect(fixedResult.metadata.completedDepth, 4);
  });

  test('preserves node-budget fallback and cancellation', () async {
    final strategy = IterativeDeepeningStrategy(rulesEngine: engine);
    final limited = await strategy.chooseMove(
      openingRequest(maxDepth: 4, maxNodes: 1),
    );
    final controller = AiCancellationController()..cancel();

    expect(limited.metadata.completedDepth, 0);
    expect(limited.metadata.nodesExamined, 1);
    expect(limited.metadata.stopReason, SearchStopReason.nodeLimit);
    expect(
      engine.validateMove(engine.createInitialState(), limited.move).isValid,
      isTrue,
    );
    await expectLater(
      strategy.chooseMove(
        openingRequest(maxDepth: 4, cancellationToken: controller.token),
      ),
      throwsA(isA<AiSearchCancelledException>()),
    );
  });
}

Piece _piece(String id, PlayerSide side, int row, int column) {
  return Piece(
    id: id,
    side: side,
    rank: PieceRank.man,
    position: BoardPosition(row: row, column: column),
  );
}
