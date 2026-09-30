import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';

enum GameMode { localTwoPlayer, humanVsAi }

enum GameRuleset { american }

extension GameRulesetConfiguration on GameRuleset {
  String get id => switch (this) {
    GameRuleset.american => AmericanCheckersRulesEngine.rulesetId,
  };

  String get label => switch (this) {
    GameRuleset.american => 'American Checkers',
  };

  RulesEngine createEngine() => switch (this) {
    GameRuleset.american => const AmericanCheckersRulesEngine(),
  };
}

final class GameConfiguration {
  const GameConfiguration({
    this.mode = GameMode.localTwoPlayer,
    this.humanSide = PlayerSide.dark,
    this.difficulty = AiDifficulty.medium,
    this.ruleset = GameRuleset.american,
  });

  final GameMode mode;
  final PlayerSide humanSide;
  final AiDifficulty difficulty;
  final GameRuleset ruleset;

  PlayerSide? get aiSide => mode == GameMode.humanVsAi
      ? switch (humanSide) {
          PlayerSide.dark => PlayerSide.light,
          PlayerSide.light => PlayerSide.dark,
        }
      : null;

  GameConfiguration copyWith({
    GameMode? mode,
    PlayerSide? humanSide,
    AiDifficulty? difficulty,
    GameRuleset? ruleset,
  }) {
    return GameConfiguration(
      mode: mode ?? this.mode,
      humanSide: humanSide ?? this.humanSide,
      difficulty: difficulty ?? this.difficulty,
      ruleset: ruleset ?? this.ruleset,
    );
  }
}
