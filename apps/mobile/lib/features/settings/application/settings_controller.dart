import 'dart:async';

import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/settings/data/settings_repository.dart';
import 'package:draft_game/features/settings/domain/player_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppSoundEffect { startMatch }

abstract interface class SoundEffectOutput {
  Future<void> play(AppSoundEffect effect);
}

final class SystemSoundEffectOutput implements SoundEffectOutput {
  @override
  Future<void> play(AppSoundEffect effect) {
    return SystemSound.play(SystemSoundType.click);
  }
}

final class SettingsController extends ChangeNotifier {
  SettingsController({
    required SettingsRepository settingsRepository,
    SoundEffectOutput? soundEffectOutput,
  }) : _repository = settingsRepository,
       _soundEffectOutput = soundEffectOutput ?? SystemSoundEffectOutput();

  final SettingsRepository _repository;
  final SoundEffectOutput _soundEffectOutput;
  PlayerSettings _settings = PlayerSettings.defaults;
  Future<void> _saveQueue = Future<void>.value();
  Future<void>? _initializeFuture;
  Object? _persistenceError;
  bool _initialized = false;
  bool _disposed = false;

  PlayerSettings get settings => _settings;
  bool get initialized => _initialized;
  Object? get persistenceError => _persistenceError;

  Future<void> initialize() {
    return _initializeFuture ??= _load();
  }

  Future<void> _load() async {
    try {
      _settings = await _repository.load();
      _persistenceError = null;
    } catch (error) {
      _settings = PlayerSettings.defaults;
      _persistenceError = error;
    }
    _initialized = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> setThemeMode(AppThemePreference value) {
    return _update(_settings.copyWith(themeMode: value));
  }

  Future<void> setSoundEffects(bool value) {
    return _update(_settings.copyWith(soundEffects: value));
  }

  Future<void> setReducedMotion(bool value) {
    return _update(_settings.copyWith(reducedMotion: value));
  }

  Future<void> setDefaultAiDifficulty(AiDifficulty value) {
    return _update(_settings.copyWith(defaultAiDifficulty: value));
  }

  Future<void> setPreferredHumanSide(PlayerSide value) {
    return _update(_settings.copyWith(preferredHumanSide: value));
  }

  Future<void> setConfirmBeforeResign(bool value) {
    return _update(_settings.copyWith(confirmBeforeResign: value));
  }

  Future<void> setConfirmBeforeRestart(bool value) {
    return _update(_settings.copyWith(confirmBeforeRestart: value));
  }

  Future<void> setBoardOrientation(BoardOrientationPreference value) {
    return _update(_settings.copyWith(boardOrientation: value));
  }

  Future<void> setLargerText(bool value) {
    return _update(_settings.copyWith(largerText: value));
  }

  Future<void> resetToDefaults() => _update(PlayerSettings.defaults);

  Future<void> playSound(AppSoundEffect effect) async {
    if (_settings.soundEffects) await _soundEffectOutput.play(effect);
  }

  Future<void> _update(PlayerSettings next) {
    if (next == _settings) return Future<void>.value();
    _settings = next;
    _persistenceError = null;
    if (!_disposed) notifyListeners();
    _saveQueue = _saveQueue.then((_) async {
      try {
        await _repository.save(next);
      } catch (error) {
        _persistenceError = error;
        if (!_disposed) notifyListeners();
      }
    });
    return _saveQueue;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
