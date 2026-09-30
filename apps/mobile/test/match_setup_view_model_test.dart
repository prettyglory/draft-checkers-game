import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/game/application/game_configuration.dart';
import 'package:draft_game/features/game/application/match_setup_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to a valid Human vs Human configuration', () {
    final viewModel = MatchSetupViewModel();

    expect(viewModel.canStart, isTrue);
    expect(viewModel.configuration?.mode, GameMode.localTwoPlayer);
    expect(viewModel.configuration?.ruleset, GameRuleset.american);
    expect(viewModel.configuration?.ruleset.id, 'american');
  });

  test('Human vs AI requires a side and difficulty', () {
    final viewModel = MatchSetupViewModel(
      initialMode: GameMode.humanVsAi,
      initialHumanSide: null,
      initialDifficulty: null,
    );

    expect(viewModel.canStart, isFalse);
    expect(viewModel.configuration, isNull);

    viewModel.setHumanSide(PlayerSide.light);
    expect(viewModel.canStart, isFalse);

    viewModel.setDifficulty(AiDifficulty.hard);
    expect(viewModel.canStart, isTrue);
    expect(viewModel.configuration?.humanSide, PlayerSide.light);
    expect(viewModel.configuration?.aiSide, PlayerSide.dark);
    expect(viewModel.configuration?.difficulty, AiDifficulty.hard);
  });

  test('missing mode prevents starting', () {
    final missingMode = MatchSetupViewModel(initialMode: null);

    expect(missingMode.canStart, isFalse);
    expect(missingMode.configuration, isNull);
  });

  test('preserves every supported AI difficulty in configuration', () {
    final viewModel = MatchSetupViewModel(initialMode: GameMode.humanVsAi);

    for (final difficulty in AiDifficulty.values) {
      viewModel.setDifficulty(difficulty);
      expect(viewModel.configuration?.difficulty, difficulty);
    }
  });

  test('preserves both human side selections in configuration', () {
    final viewModel = MatchSetupViewModel(initialMode: GameMode.humanVsAi);

    for (final side in PlayerSide.values) {
      viewModel.setHumanSide(side);
      expect(viewModel.configuration?.humanSide, side);
      expect(viewModel.configuration?.aiSide, isNot(side));
    }
  });
}
