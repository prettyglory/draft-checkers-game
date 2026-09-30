import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/settings/domain/player_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults are stable and production-safe', () {
    const settings = PlayerSettings.defaults;

    expect(settings.themeMode, AppThemePreference.system);
    expect(settings.soundEffects, isTrue);
    expect(settings.reducedMotion, isFalse);
    expect(settings.defaultAiDifficulty, AiDifficulty.medium);
    expect(settings.preferredHumanSide, PlayerSide.dark);
    expect(settings.confirmBeforeResign, isTrue);
    expect(settings.confirmBeforeRestart, isTrue);
    expect(settings.boardOrientation, BoardOrientationPreference.automatic);
    expect(settings.largerText, isFalse);
  });

  test('round-trips every typed preference', () {
    const settings = PlayerSettings(
      themeMode: AppThemePreference.dark,
      soundEffects: false,
      reducedMotion: true,
      defaultAiDifficulty: AiDifficulty.expert,
      preferredHumanSide: PlayerSide.light,
      confirmBeforeResign: false,
      confirmBeforeRestart: false,
      boardOrientation: BoardOrientationPreference.darkAtBottom,
      largerText: true,
    );

    expect(PlayerSettings.fromJson(settings.toJson()), settings);
  });

  test('invalid fields fall back independently to defaults', () {
    final settings = PlayerSettings.fromJson(<String, Object?>{
      'themeMode': 'sepia',
      'soundEffects': 'yes',
      'reducedMotion': true,
      'defaultAiDifficulty': 'impossible',
      'preferredHumanSide': 4,
      'confirmBeforeResign': false,
      'confirmBeforeRestart': null,
      'boardOrientation': 'sideways',
      'largerText': true,
    });

    expect(settings.themeMode, AppThemePreference.system);
    expect(settings.soundEffects, isTrue);
    expect(settings.reducedMotion, isTrue);
    expect(settings.defaultAiDifficulty, AiDifficulty.medium);
    expect(settings.preferredHumanSide, PlayerSide.dark);
    expect(settings.confirmBeforeResign, isFalse);
    expect(settings.confirmBeforeRestart, isTrue);
    expect(settings.boardOrientation, BoardOrientationPreference.automatic);
    expect(settings.largerText, isTrue);
  });
}
