import 'package:draft_game/features/settings/data/settings_repository.dart';
import 'package:draft_game/features/settings/domain/player_settings.dart';

final class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository([this.stored = PlayerSettings.defaults]);

  PlayerSettings stored;
  int saveCount = 0;

  @override
  Future<PlayerSettings> load() async => stored;

  @override
  Future<void> save(PlayerSettings settings) async {
    stored = settings;
    saveCount += 1;
  }
}
