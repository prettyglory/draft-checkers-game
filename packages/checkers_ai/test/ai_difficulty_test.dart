import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();

  test('maps every difficulty to explicit deterministic settings', () {
    expect(AiDifficulty.values, hasLength(5));

    final beginner = AiDifficulty.beginner.preset;
    expect(beginner.strategyKind, AiStrategyKind.seededBeginner);
    expect(beginner.maxDepth, 1);
    expect(beginner.maxNodes, 1);
    expect(beginner.seed, 0);

    final easy = AiDifficulty.easy.preset;
    expect(easy.strategyKind, AiStrategyKind.iterativeDeepening);
    expect(easy.maxDepth, 2);
    expect(easy.maxNodes, 500);
    expect(easy.maxQuiescenceDepth, 0);
    expect(easy.useAspirationWindows, isFalse);
    expect(easy.usePrincipalVariationSearch, isFalse);

    final medium = AiDifficulty.medium.preset;
    expect(medium.maxDepth, 3);
    expect(medium.maxNodes, 2500);
    expect(medium.maxQuiescenceDepth, 4);
    expect(medium.useAspirationWindows, isTrue);
    expect(medium.useKillerHistoryHeuristics, isTrue);
    expect(medium.useLateMoveReductions, isFalse);

    final hard = AiDifficulty.hard.preset;
    expect(hard.maxDepth, 4);
    expect(hard.maxNodes, 10000);
    expect(hard.maxQuiescenceDepth, 8);
    expect(hard.usePrincipalVariationSearch, isTrue);
    expect(hard.useLateMoveReductions, isTrue);
    expect(hard.useEndgameEvaluation, isFalse);

    final expert = AiDifficulty.expert.preset;
    expect(expert.maxDepth, 5);
    expect(expert.maxNodes, 25000);
    expect(expert.useLateMoveReductions, isTrue);
    expect(expert.useEndgameEvaluation, isTrue);
  });

  test('budgets progress without hardware-dependent duration limits', () {
    final presets = AiDifficulty.values.map((value) => value.preset).toList();

    expect(
      presets.map((preset) => preset.maxDepth),
      orderedEquals(<int>[1, 2, 3, 4, 5]),
    );
    expect(
      presets.map((preset) => preset.maxNodes),
      orderedEquals(<int>[1, 500, 2500, 10000, 25000]),
    );
    for (final preset in presets) {
      expect(preset.budget.maxDuration, isNull);
    }
  });

  test('every preset returns a deterministic legal move', () async {
    final state = engine.createInitialState();
    final legalMoves = engine.legalMoves(state);

    for (final difficulty in AiDifficulty.values) {
      final preset = difficulty.preset;
      final first = await preset
          .createStrategy(rulesEngine: engine)
          .chooseMove(
            AiSearchRequest(
              state: state,
              legalMoves: legalMoves,
              budget: preset.budget,
            ),
          );
      final second = await preset
          .createStrategy(rulesEngine: engine)
          .chooseMove(
            AiSearchRequest(
              state: state,
              legalMoves: legalMoves,
              budget: preset.budget,
            ),
          );

      expect(legalMoves.map((move) => move.id), contains(first.move.id));
      expect(second.move.id, first.move.id, reason: difficulty.name);
      expect(second.metadata.nodesExamined, first.metadata.nodesExamined);
      expect(second.metadata.completedDepth, first.metadata.completedDepth);
      expect(second.metadata.stopReason, first.metadata.stopReason);
      expect(first.metadata.nodesExamined, lessThanOrEqualTo(preset.maxNodes));
    }
  });
}
