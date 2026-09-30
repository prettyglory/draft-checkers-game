import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';

enum AppThemePreference { system, light, dark }

enum BoardOrientationPreference { automatic, darkAtBottom, lightAtBottom }

final class PlayerSettings {
  const PlayerSettings({
    this.themeMode = AppThemePreference.system,
    this.soundEffects = true,
    this.reducedMotion = false,
    this.defaultAiDifficulty = AiDifficulty.medium,
    this.preferredHumanSide = PlayerSide.dark,
    this.confirmBeforeResign = true,
    this.confirmBeforeRestart = true,
    this.boardOrientation = BoardOrientationPreference.automatic,
    this.largerText = false,
  });

  static const PlayerSettings defaults = PlayerSettings();

  final AppThemePreference themeMode;
  final bool soundEffects;
  final bool reducedMotion;
  final AiDifficulty defaultAiDifficulty;
  final PlayerSide preferredHumanSide;
  final bool confirmBeforeResign;
  final bool confirmBeforeRestart;
  final BoardOrientationPreference boardOrientation;
  final bool largerText;

  PlayerSettings copyWith({
    AppThemePreference? themeMode,
    bool? soundEffects,
    bool? reducedMotion,
    AiDifficulty? defaultAiDifficulty,
    PlayerSide? preferredHumanSide,
    bool? confirmBeforeResign,
    bool? confirmBeforeRestart,
    BoardOrientationPreference? boardOrientation,
    bool? largerText,
  }) {
    return PlayerSettings(
      themeMode: themeMode ?? this.themeMode,
      soundEffects: soundEffects ?? this.soundEffects,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      defaultAiDifficulty: defaultAiDifficulty ?? this.defaultAiDifficulty,
      preferredHumanSide: preferredHumanSide ?? this.preferredHumanSide,
      confirmBeforeResign: confirmBeforeResign ?? this.confirmBeforeResign,
      confirmBeforeRestart: confirmBeforeRestart ?? this.confirmBeforeRestart,
      boardOrientation: boardOrientation ?? this.boardOrientation,
      largerText: largerText ?? this.largerText,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'schemaVersion': 1,
      'themeMode': themeMode.name,
      'soundEffects': soundEffects,
      'reducedMotion': reducedMotion,
      'defaultAiDifficulty': defaultAiDifficulty.name,
      'preferredHumanSide': preferredHumanSide.name,
      'confirmBeforeResign': confirmBeforeResign,
      'confirmBeforeRestart': confirmBeforeRestart,
      'boardOrientation': boardOrientation.name,
      'largerText': largerText,
    };
  }

  factory PlayerSettings.fromJson(Map<String, Object?> json) {
    const defaults = PlayerSettings.defaults;
    return PlayerSettings(
      themeMode: _enumValue(
        AppThemePreference.values,
        json['themeMode'],
        defaults.themeMode,
      ),
      soundEffects: _boolValue(json['soundEffects'], defaults.soundEffects),
      reducedMotion: _boolValue(json['reducedMotion'], defaults.reducedMotion),
      defaultAiDifficulty: _enumValue(
        AiDifficulty.values,
        json['defaultAiDifficulty'],
        defaults.defaultAiDifficulty,
      ),
      preferredHumanSide: _enumValue(
        PlayerSide.values,
        json['preferredHumanSide'],
        defaults.preferredHumanSide,
      ),
      confirmBeforeResign: _boolValue(
        json['confirmBeforeResign'],
        defaults.confirmBeforeResign,
      ),
      confirmBeforeRestart: _boolValue(
        json['confirmBeforeRestart'],
        defaults.confirmBeforeRestart,
      ),
      boardOrientation: _enumValue(
        BoardOrientationPreference.values,
        json['boardOrientation'],
        defaults.boardOrientation,
      ),
      largerText: _boolValue(json['largerText'], defaults.largerText),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PlayerSettings &&
        other.themeMode == themeMode &&
        other.soundEffects == soundEffects &&
        other.reducedMotion == reducedMotion &&
        other.defaultAiDifficulty == defaultAiDifficulty &&
        other.preferredHumanSide == preferredHumanSide &&
        other.confirmBeforeResign == confirmBeforeResign &&
        other.confirmBeforeRestart == confirmBeforeRestart &&
        other.boardOrientation == boardOrientation &&
        other.largerText == largerText;
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    soundEffects,
    reducedMotion,
    defaultAiDifficulty,
    preferredHumanSide,
    confirmBeforeResign,
    confirmBeforeRestart,
    boardOrientation,
    largerText,
  );

  static bool _boolValue(Object? value, bool fallback) {
    return value is bool ? value : fallback;
  }

  static T _enumValue<T extends Enum>(
    List<T> values,
    Object? value,
    T fallback,
  ) {
    if (value is! String) return fallback;
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    return fallback;
  }
}
