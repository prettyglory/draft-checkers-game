import 'dart:async';
import 'dart:math' as math;

import 'package:draft_game/app/theme/app_theme.dart';
import 'package:draft_game/features/game/presentation/match_setup_screen.dart';
import 'package:draft_game/features/settings/application/settings_controller.dart';
import 'package:draft_game/features/settings/data/settings_repository.dart';
import 'package:draft_game/features/settings/domain/player_settings.dart';
import 'package:flutter/material.dart';

class DraftGameApp extends StatefulWidget {
  const DraftGameApp({this.settingsController, super.key});

  final SettingsController? settingsController;

  @override
  State<DraftGameApp> createState() => _DraftGameAppState();
}

class _DraftGameAppState extends State<DraftGameApp> {
  late final SettingsController _settingsController;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.settingsController == null;
    _settingsController =
        widget.settingsController ??
        SettingsController(
          settingsRepository: SharedPreferencesSettingsRepository(),
        );
    unawaited(_settingsController.initialize());
  }

  @override
  void dispose() {
    if (_ownsController) _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settingsController,
      builder: (context, _) {
        final settings = _settingsController.settings;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Draft Game',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeMode(settings.themeMode),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final scale = settings.largerText
                ? math.max(1.15, media.textScaler.scale(1))
                : media.textScaler.scale(1);
            return MediaQuery(
              data: media.copyWith(
                disableAnimations:
                    media.disableAnimations || settings.reducedMotion,
                textScaler: TextScaler.linear(scale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: _settingsController.initialized
              ? MatchSetupScreen(
                  preferences: settings,
                  settingsController: _settingsController,
                )
              : const _SettingsLoadingScreen(),
        );
      },
    );
  }
}

class _SettingsLoadingScreen extends StatelessWidget {
  const _SettingsLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Loading player settings',
          child: const Icon(Icons.grid_view_rounded, size: 42),
        ),
      ),
    );
  }
}

ThemeMode _themeMode(AppThemePreference preference) {
  return switch (preference) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };
}
