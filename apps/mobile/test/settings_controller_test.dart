import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/settings/application/settings_controller.dart';
import 'package:draft_game/features/settings/domain/player_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_settings_repository.dart';

void main() {
  test('loads, persists, and reloads player preferences', () async {
    final repository = MemorySettingsRepository();
    final controller = SettingsController(settingsRepository: repository);
    await controller.initialize();

    await controller.setThemeMode(AppThemePreference.dark);
    await controller.setReducedMotion(true);
    await controller.setDefaultAiDifficulty(AiDifficulty.expert);
    await controller.setPreferredHumanSide(PlayerSide.light);

    final reloaded = SettingsController(settingsRepository: repository);
    await reloaded.initialize();

    expect(reloaded.settings.themeMode, AppThemePreference.dark);
    expect(reloaded.settings.reducedMotion, isTrue);
    expect(reloaded.settings.defaultAiDifficulty, AiDifficulty.expert);
    expect(reloaded.settings.preferredHumanSide, PlayerSide.light);
    expect(repository.saveCount, 4);
  });

  test('reset restores and persists every default', () async {
    final repository = MemorySettingsRepository(
      const PlayerSettings(
        themeMode: AppThemePreference.dark,
        soundEffects: false,
        reducedMotion: true,
        defaultAiDifficulty: AiDifficulty.expert,
        preferredHumanSide: PlayerSide.light,
        confirmBeforeResign: false,
        confirmBeforeRestart: false,
        boardOrientation: BoardOrientationPreference.darkAtBottom,
        largerText: true,
      ),
    );
    final controller = SettingsController(settingsRepository: repository);
    await controller.initialize();

    await controller.resetToDefaults();

    expect(controller.settings, PlayerSettings.defaults);
    expect(repository.stored, PlayerSettings.defaults);
  });

  test('sound output is gated by the sound preference', () async {
    final output = _RecordingSoundOutput();
    final controller = SettingsController(
      settingsRepository: MemorySettingsRepository(),
      soundEffectOutput: output,
    );
    await controller.initialize();

    await controller.playSound(AppSoundEffect.startMatch);
    await controller.setSoundEffects(false);
    await controller.playSound(AppSoundEffect.startMatch);

    expect(output.effects, <AppSoundEffect>[AppSoundEffect.startMatch]);
  });
}

final class _RecordingSoundOutput implements SoundEffectOutput {
  final List<AppSoundEffect> effects = <AppSoundEffect>[];

  @override
  Future<void> play(AppSoundEffect effect) async {
    effects.add(effect);
  }
}
