import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';

enum GameMode { localTwoPlayer, humanVsAi }

final class GameConfiguration {
  const GameConfiguration({
    this.mode = GameMode.localTwoPlayer,
    this.humanSide = PlayerSide.dark,
    this.difficulty = AiDifficulty.medium,
  });

  final GameMode mode;
  final PlayerSide humanSide;
  final AiDifficulty difficulty;

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
  }) {
    return GameConfiguration(
      mode: mode ?? this.mode,
      humanSide: humanSide ?? this.humanSide,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}
