import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();
  final budget = SearchBudget(maxNodes: 1);

  AiSearchRequest openingRequest({AiCancellationToken? cancellationToken}) {
    final state = engine.createInitialState();
    return AiSearchRequest(
      state: state,
      legalMoves: engine.legalMoves(state),
      budget: budget,
      cancellationToken: cancellationToken ?? const NoCancellationToken(),
    );
  }

  test('selects an authoritative legal move with truthful metadata', () async {
    final strategy = BeginnerStrategy(rulesEngine: engine, seed: 7);
    final request = openingRequest();

    final result = await strategy.chooseMove(request);

    expect(request.legalMoves, contains(same(result.move)));
    expect(engine.validateMove(request.state, result.move).isValid, isTrue);
    expect(result.metadata.strategyId, BeginnerStrategy.strategyId);
    expect(result.metadata.nodesExamined, 1);
    expect(result.metadata.completedDepth, 0);
    expect(result.metadata.elapsed, greaterThanOrEqualTo(Duration.zero));
    expect(result.metadata.stopReason, SearchStopReason.completed);
  });

  test('produces a reproducible sequence for a configured seed', () async {
    final first = BeginnerStrategy(rulesEngine: engine, seed: 42);
    final second = BeginnerStrategy(rulesEngine: engine, seed: 42);
    final request = openingRequest();

    final firstIds = <String>[];
    final secondIds = <String>[];
    for (var index = 0; index < 8; index += 1) {
      firstIds.add((await first.chooseMove(request)).move.id);
      secondIds.add((await second.chooseMove(request)).move.id);
    }

    expect(firstIds, secondIds);
  });

  test('defensively copies the supplied legal move collection', () {
    final state = engine.createInitialState();
    final source = engine.legalMoves(state).toList();
    final request = AiSearchRequest(
      state: state,
      legalMoves: source,
      budget: budget,
    );

    source.clear();

    expect(request.legalMoves, hasLength(7));
    expect(() => request.legalMoves.clear(), throwsUnsupportedError);
  });

  test('rejects a legal list that does not match the state', () async {
    final strategy = BeginnerStrategy(rulesEngine: engine);
    final state = engine.createInitialState();
    final incomplete = engine.legalMoves(state).toList()..removeLast();

    await expectLater(
      strategy.chooseMove(
        AiSearchRequest(state: state, legalMoves: incomplete, budget: budget),
      ),
      throwsA(
        isA<AiSearchException>().having(
          (error) => error.failure,
          'failure',
          AiSearchFailure.legalMovesMismatch,
        ),
      ),
    );
  });

  test('honors cancellation before selecting a move', () async {
    final controller = AiCancellationController()..cancel();
    final strategy = BeginnerStrategy(rulesEngine: engine);

    await expectLater(
      strategy.chooseMove(openingRequest(cancellationToken: controller.token)),
      throwsA(isA<AiSearchCancelledException>()),
    );
  });

  test('rejects completed states', () async {
    final active = engine.createInitialState();
    final completed = GameState(
      rulesetId: active.rulesetId,
      boardSize: active.boardSize,
      pieces: active.pieces,
      activeSide: active.activeSide,
      ply: active.ply,
      revision: active.revision,
      previousPositionHashes: active.positionHistory.take(
        active.positionHistory.length - 1,
      ),
      ruleCounters: active.ruleCounters,
      status: GameStatus.completed,
      outcome: const GameOutcome.draw(reason: GameOutcomeReason.drawAgreement),
    );
    final strategy = BeginnerStrategy(rulesEngine: engine);

    await expectLater(
      strategy.chooseMove(
        AiSearchRequest(
          state: completed,
          legalMoves: const <Move>[],
          budget: budget,
        ),
      ),
      throwsA(
        isA<AiSearchException>().having(
          (error) => error.failure,
          'failure',
          AiSearchFailure.completedGame,
        ),
      ),
    );
  });

  test('validates search budgets', () {
    expect(() => SearchBudget(), throwsArgumentError);
    expect(() => SearchBudget(maxNodes: 0), throwsArgumentError);
    expect(() => SearchBudget(maxDepth: -1), throwsArgumentError);
    expect(() => SearchBudget(maxDuration: Duration.zero), throwsArgumentError);
  });
}
