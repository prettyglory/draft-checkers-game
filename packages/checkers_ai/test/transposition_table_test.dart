import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();

  TranspositionKey keyFor(GameState state) {
    return TranspositionKey.fromState(
      state: state,
      perspective: PlayerSide.dark,
      weights: EvaluationWeights(),
    );
  }

  GameState copyWithRuleState(
    GameState source, {
    Iterable<String> previousPositionHashes = const <String>[],
    int noProgressPly = 0,
  }) {
    return GameState(
      rulesetId: source.rulesetId,
      boardSize: source.boardSize,
      pieces: source.pieces,
      activeSide: source.activeSide,
      ply: source.ply,
      revision: source.revision,
      previousPositionHashes: previousPositionHashes,
      ruleCounters: <String, int>{
        AmericanCheckersRulesEngine.noProgressPlyCounter: noProgressPly,
      },
    );
  }

  test('snapshot keys separate repetition and no-progress state', () {
    final opening = engine.createInitialState();
    final ordinary = copyWithRuleState(opening);
    final repeated = copyWithRuleState(
      opening,
      previousPositionHashes: <String>[
        opening.positionHash,
        opening.positionHash,
      ],
    );
    final nearDraw = copyWithRuleState(opening, noProgressPly: 79);

    expect(ordinary.positionHash, repeated.positionHash);
    expect(ordinary.positionHash, nearDraw.positionHash);
    expect(keyFor(ordinary), isNot(keyFor(repeated)));
    expect(keyFor(ordinary), isNot(keyFor(nearDraw)));
    expect(keyFor(repeated), isNot(keyFor(nearDraw)));
  });

  test('keys separate perspective and evaluator configuration', () {
    final state = engine.createInitialState();
    final dark = keyFor(state);
    final light = TranspositionKey.fromState(
      state: state,
      perspective: PlayerSide.light,
      weights: EvaluationWeights(),
    );
    final weighted = TranspositionKey.fromState(
      state: state,
      perspective: PlayerSide.dark,
      weights: EvaluationWeights(king: 200),
    );

    expect(dark, isNot(light));
    expect(dark, isNot(weighted));
  });

  test('keeps deeper entries instead of weaker replacements', () {
    final table = TranspositionTable(maxEntries: 4);
    final key = keyFor(engine.createInitialState());
    table.store(
      key,
      const TranspositionEntry(
        depth: 4,
        score: 30,
        bound: TranspositionBound.exact,
        generation: 1,
      ),
    );
    table.store(
      key,
      const TranspositionEntry(
        depth: 2,
        score: 99,
        bound: TranspositionBound.lower,
        generation: 2,
      ),
    );

    final retained = table.probe(key)!;
    expect(retained.depth, 4);
    expect(retained.score, 30);
    expect(retained.bound, TranspositionBound.exact);
    expect(table.diagnostics.rejectedStores, 1);
  });

  test('tracks exact, lower, and upper bound use and cutoffs', () {
    final table = TranspositionTable(maxEntries: 4);
    const exact = TranspositionEntry(
      depth: 3,
      score: 10,
      bound: TranspositionBound.exact,
      generation: 1,
    );
    const lower = TranspositionEntry(
      depth: 3,
      score: 20,
      bound: TranspositionBound.lower,
      generation: 1,
    );
    const upper = TranspositionEntry(
      depth: 3,
      score: -20,
      bound: TranspositionBound.upper,
      generation: 1,
    );

    table.recordUse(exact, cutoff: true);
    table.recordUse(lower, cutoff: false);
    table.recordUse(upper, cutoff: true);

    expect(table.diagnostics.exactHits, 1);
    expect(table.diagnostics.boundHits, 2);
    expect(table.diagnostics.cutoffs, 2);
  });

  test('repeated search reuses entries without changing the move', () async {
    final table = TranspositionTable();
    final strategy = FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      transpositionTable: table,
    );
    final state = engine.createInitialState();
    final request = AiSearchRequest(
      state: state,
      legalMoves: engine.legalMoves(state),
      budget: SearchBudget(maxDepth: 3),
    );

    final cold = await strategy.chooseMove(request);
    final warm = await strategy.chooseMove(request);

    expect(warm.move.id, cold.move.id);
    expect(warm.metadata.transposition.hits, greaterThan(0));
    expect(
      warm.metadata.nodesExamined,
      lessThanOrEqualTo(cold.metadata.nodesExamined),
    );
  });

  test('cached and disabled searches keep deterministic selection', () async {
    final state = engine.createInitialState();
    final request = AiSearchRequest(
      state: state,
      legalMoves: engine.legalMoves(state),
      budget: SearchBudget(maxDepth: 3),
    );
    final cached = FixedDepthAlphaBetaStrategy(rulesEngine: engine);
    final disabled = FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      transpositionTable: TranspositionTable(maxEntries: 0),
    );

    final cachedResult = await cached.chooseMove(request);
    final uncachedResult = await disabled.chooseMove(request);

    expect(cachedResult.move.id, uncachedResult.move.id);
    expect(uncachedResult.metadata.transposition.probes, 0);
  });
}
