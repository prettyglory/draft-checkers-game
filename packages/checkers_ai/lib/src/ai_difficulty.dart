import 'package:checkers_engine/checkers_engine.dart';

import 'ai_search.dart';
import 'aspiration_window.dart';
import 'beginner_strategy.dart';
import 'iterative_deepening_strategy.dart';
import 'move_ordering.dart';
import 'position_evaluator.dart';
import 'search_budget.dart';
import 'transposition_table.dart';

enum AiDifficulty { beginner, easy, medium, hard, expert }

enum AiStrategyKind { seededBeginner, iterativeDeepening }

final class AiDifficultyPreset {
  const AiDifficultyPreset({
    required this.difficulty,
    required this.label,
    required this.strategyKind,
    required this.maxDepth,
    required this.maxNodes,
    required this.seed,
    required this.transpositionEntries,
    required this.maxQuiescenceDepth,
    required this.useTacticalOrdering,
    required this.useAspirationWindows,
    required this.usePrincipalVariationSearch,
    required this.useKillerHistoryHeuristics,
    required this.useLateMoveReductions,
    required this.useEndgameEvaluation,
  });

  final AiDifficulty difficulty;
  final String label;
  final AiStrategyKind strategyKind;
  final int maxDepth;
  final int maxNodes;
  final int seed;
  final int transpositionEntries;
  final int maxQuiescenceDepth;
  final bool useTacticalOrdering;
  final bool useAspirationWindows;
  final bool usePrincipalVariationSearch;
  final bool useKillerHistoryHeuristics;
  final bool useLateMoveReductions;
  final bool useEndgameEvaluation;

  SearchBudget get budget =>
      SearchBudget(maxDepth: maxDepth, maxNodes: maxNodes);

  AiStrategy createStrategy({required RulesEngine rulesEngine}) {
    if (strategyKind == AiStrategyKind.seededBeginner) {
      return BeginnerStrategy(rulesEngine: rulesEngine, seed: seed);
    }
    return IterativeDeepeningStrategy(
      rulesEngine: rulesEngine,
      evaluator: PositionEvaluator(
        rulesEngine: rulesEngine,
        endgameWeights: useEndgameEvaluation
            ? EndgameEvaluationWeights()
            : null,
      ),
      moveOrdering: MoveOrdering(useTacticalOrdering: useTacticalOrdering),
      transpositionTable: TranspositionTable(maxEntries: transpositionEntries),
      maxQuiescenceDepth: maxQuiescenceDepth,
      aspirationWindow: useAspirationWindows
          ? AspirationWindowConfig()
          : AspirationWindowConfig.disabled(),
      usePrincipalVariationSearch: usePrincipalVariationSearch,
      useKillerHistoryHeuristics: useKillerHistoryHeuristics,
      lateMoveReductions: useLateMoveReductions
          ? LateMoveReductionConfig()
          : LateMoveReductionConfig.disabled(),
    );
  }
}

extension AiDifficultyConfiguration on AiDifficulty {
  AiDifficultyPreset get preset => switch (this) {
    AiDifficulty.beginner => const AiDifficultyPreset(
      difficulty: AiDifficulty.beginner,
      label: 'Beginner',
      strategyKind: AiStrategyKind.seededBeginner,
      maxDepth: 1,
      maxNodes: 1,
      seed: 0,
      transpositionEntries: 0,
      maxQuiescenceDepth: 0,
      useTacticalOrdering: false,
      useAspirationWindows: false,
      usePrincipalVariationSearch: false,
      useKillerHistoryHeuristics: false,
      useLateMoveReductions: false,
      useEndgameEvaluation: false,
    ),
    AiDifficulty.easy => const AiDifficultyPreset(
      difficulty: AiDifficulty.easy,
      label: 'Easy',
      strategyKind: AiStrategyKind.iterativeDeepening,
      maxDepth: 2,
      maxNodes: 500,
      seed: 0,
      transpositionEntries: 2000,
      maxQuiescenceDepth: 0,
      useTacticalOrdering: true,
      useAspirationWindows: false,
      usePrincipalVariationSearch: false,
      useKillerHistoryHeuristics: false,
      useLateMoveReductions: false,
      useEndgameEvaluation: false,
    ),
    AiDifficulty.medium => const AiDifficultyPreset(
      difficulty: AiDifficulty.medium,
      label: 'Medium',
      strategyKind: AiStrategyKind.iterativeDeepening,
      maxDepth: 3,
      maxNodes: 2500,
      seed: 0,
      transpositionEntries: 4000,
      maxQuiescenceDepth: 4,
      useTacticalOrdering: true,
      useAspirationWindows: true,
      usePrincipalVariationSearch: true,
      useKillerHistoryHeuristics: true,
      useLateMoveReductions: false,
      useEndgameEvaluation: false,
    ),
    AiDifficulty.hard => const AiDifficultyPreset(
      difficulty: AiDifficulty.hard,
      label: 'Hard',
      strategyKind: AiStrategyKind.iterativeDeepening,
      maxDepth: 4,
      maxNodes: 10000,
      seed: 0,
      transpositionEntries: 10000,
      maxQuiescenceDepth: 8,
      useTacticalOrdering: true,
      useAspirationWindows: true,
      usePrincipalVariationSearch: true,
      useKillerHistoryHeuristics: true,
      useLateMoveReductions: true,
      useEndgameEvaluation: false,
    ),
    AiDifficulty.expert => const AiDifficultyPreset(
      difficulty: AiDifficulty.expert,
      label: 'Expert',
      strategyKind: AiStrategyKind.iterativeDeepening,
      maxDepth: 5,
      maxNodes: 25000,
      seed: 0,
      transpositionEntries: 10000,
      maxQuiescenceDepth: 8,
      useTacticalOrdering: true,
      useAspirationWindows: true,
      usePrincipalVariationSearch: true,
      useKillerHistoryHeuristics: true,
      useLateMoveReductions: true,
      useEndgameEvaluation: true,
    ),
  };
}
