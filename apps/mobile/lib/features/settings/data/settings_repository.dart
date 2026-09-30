import 'dart:convert';

import 'package:draft_game/features/settings/domain/player_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SettingsRepository {
  Future<PlayerSettings> load();

  Future<void> save(PlayerSettings settings);
}

final class SharedPreferencesSettingsRepository implements SettingsRepository {
  static const storageKey = 'draft_game.player_settings.v1';

  @override
  Future<PlayerSettings> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(storageKey);
      if (encoded == null) return PlayerSettings.defaults;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return PlayerSettings.defaults;
      return PlayerSettings.fromJson(decoded);
    } on Object {
      return PlayerSettings.defaults;
    }
  }

  @override
  Future<void> save(PlayerSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(storageKey, jsonEncode(settings.toJson()));
  }
}
