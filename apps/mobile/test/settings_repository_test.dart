import 'dart:convert';

import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/settings/data/settings_repository.dart';
import 'package:draft_game/features/settings/domain/player_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('persists and reloads settings through shared preferences', () async {
    final repository = SharedPreferencesSettingsRepository();
    const expected = PlayerSettings(
      themeMode: AppThemePreference.light,
      soundEffects: false,
      reducedMotion: true,
      defaultAiDifficulty: AiDifficulty.hard,
      preferredHumanSide: PlayerSide.light,
      confirmBeforeResign: false,
      boardOrientation: BoardOrientationPreference.lightAtBottom,
      largerText: true,
    );

    await repository.save(expected);
    final reloaded = await SharedPreferencesSettingsRepository().load();

    expect(reloaded, expected);
  });

  test('malformed storage falls back to defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesSettingsRepository.storageKey: '{not-json',
    });

    final settings = await SharedPreferencesSettingsRepository().load();

    expect(settings, PlayerSettings.defaults);
  });

  test('wrong JSON shape falls back to defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesSettingsRepository.storageKey: jsonEncode(<Object>[1]),
    });

    final settings = await SharedPreferencesSettingsRepository().load();

    expect(settings, PlayerSettings.defaults);
  });

  test('wrong stored value type falls back to defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesSettingsRepository.storageKey: 42,
    });

    final settings = await SharedPreferencesSettingsRepository().load();

    expect(settings, PlayerSettings.defaults);
  });
}
