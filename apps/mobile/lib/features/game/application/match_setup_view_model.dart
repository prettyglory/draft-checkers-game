import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/game/application/game_configuration.dart';
import 'package:flutter/foundation.dart';

final class MatchSetupViewModel extends ChangeNotifier {
  MatchSetupViewModel({
    GameMode? initialMode = GameMode.localTwoPlayer,
    PlayerSide? initialHumanSide = PlayerSide.dark,
    AiDifficulty? initialDifficulty = AiDifficulty.medium,
  }) : _mode = initialMode,
       _humanSide = initialHumanSide,
       _difficulty = initialDifficulty;

  GameMode? _mode;
  PlayerSide? _humanSide;
  AiDifficulty? _difficulty;
  static const GameRuleset _ruleset = GameRuleset.american;

  GameMode? get mode => _mode;
  PlayerSide? get humanSide => _humanSide;
  AiDifficulty? get difficulty => _difficulty;
  GameRuleset get ruleset => _ruleset;

  bool get canStart {
    final mode = _mode;
    if (mode == null) return false;
    return mode == GameMode.localTwoPlayer ||
        (_humanSide != null && _difficulty != null);
  }

  GameConfiguration? get configuration {
    if (!canStart) return null;
    return GameConfiguration(
      mode: _mode!,
      humanSide: _humanSide ?? PlayerSide.dark,
      difficulty: _difficulty ?? AiDifficulty.medium,
      ruleset: _ruleset,
    );
  }

  void setMode(GameMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void setHumanSide(PlayerSide side) {
    if (_humanSide == side) return;
    _humanSide = side;
    notifyListeners();
  }

  void setDifficulty(AiDifficulty difficulty) {
    if (_difficulty == difficulty) return;
    _difficulty = difficulty;
    notifyListeners();
  }
}
