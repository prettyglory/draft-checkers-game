import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/settings/application/settings_controller.dart';
import 'package:draft_game/features/settings/domain/player_settings.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.settings;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            backgroundColor: Colors.transparent,
          ),
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surfaceContainer,
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sections = <Widget>[
                    _AppearanceSettings(
                      settings: settings,
                      controller: controller,
                    ),
                    _GameplaySettings(
                      settings: settings,
                      controller: controller,
                    ),
                    _ConfirmationSettings(
                      settings: settings,
                      controller: controller,
                    ),
                  ];
                  if (constraints.maxWidth >= 800) {
                    return _TabletSettingsLayout(
                      sections: sections,
                      controller: controller,
                    );
                  }
                  return _PhoneSettingsLayout(
                    sections: sections,
                    controller: controller,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PhoneSettingsLayout extends StatelessWidget {
  const _PhoneSettingsLayout({
    required this.sections,
    required this.controller,
  });

  final List<Widget> sections;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('phone-settings-layout'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: <Widget>[
        const _SettingsIntroduction(),
        const SizedBox(height: 20),
        for (final section in sections) ...<Widget>[
          section,
          const SizedBox(height: 16),
        ],
        _ResetSettingsButton(controller: controller),
      ],
    );
  }
}

class _TabletSettingsLayout extends StatelessWidget {
  const _TabletSettingsLayout({
    required this.sections,
    required this.controller,
  });

  final List<Widget> sections;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('tablet-settings-layout'),
      padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _SettingsIntroduction(),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: sections[0]),
                  const SizedBox(width: 20),
                  Expanded(child: sections[1]),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(child: sections[2]),
                  const SizedBox(width: 20),
                  Expanded(child: _ResetSettingsButton(controller: controller)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsIntroduction extends StatelessWidget {
  const _SettingsIntroduction();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Player preferences',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Visual, gameplay, and accessibility choices are saved on this device.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _AppearanceSettings extends StatelessWidget {
  const _AppearanceSettings({required this.settings, required this.controller});

  final PlayerSettings settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'Appearance',
      children: <Widget>[
        Text('Theme', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        _ThemePreferenceControl(settings: settings, controller: controller),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          key: const Key('settings-reduced-motion'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Reduced motion'),
          subtitle: const Text('Remove board selection animations'),
          value: settings.reducedMotion,
          onChanged: controller.setReducedMotion,
        ),
        SwitchListTile.adaptive(
          key: const Key('settings-larger-text'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Larger text'),
          subtitle: const Text('Increase interface and board marker labels'),
          value: settings.largerText,
          onChanged: controller.setLargerText,
        ),
      ],
    );
  }
}

class _ThemePreferenceControl extends StatelessWidget {
  const _ThemePreferenceControl({
    required this.settings,
    required this.controller,
  });

  final PlayerSettings settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const Key('settings-theme-selector'),
      builder: (context, constraints) {
        if (constraints.maxWidth < 280) {
          return DropdownButtonFormField<AppThemePreference>(
            initialValue: settings.themeMode,
            decoration: const InputDecoration(labelText: 'Theme mode'),
            items: AppThemePreference.values
                .map(
                  (theme) => DropdownMenuItem<AppThemePreference>(
                    value: theme,
                    child: Text(_themeLabel(theme)),
                  ),
                )
                .toList(growable: false),
            onChanged: (theme) {
              if (theme != null) controller.setThemeMode(theme);
            },
          );
        }
        return SegmentedButton<AppThemePreference>(
          showSelectedIcon: false,
          segments: const <ButtonSegment<AppThemePreference>>[
            ButtonSegment<AppThemePreference>(
              value: AppThemePreference.system,
              label: Text('System'),
            ),
            ButtonSegment<AppThemePreference>(
              value: AppThemePreference.light,
              label: Text('Light'),
            ),
            ButtonSegment<AppThemePreference>(
              value: AppThemePreference.dark,
              label: Text('Dark'),
            ),
          ],
          selected: <AppThemePreference>{settings.themeMode},
          onSelectionChanged: (selection) {
            controller.setThemeMode(selection.single);
          },
        );
      },
    );
  }
}

class _GameplaySettings extends StatelessWidget {
  const _GameplaySettings({required this.settings, required this.controller});

  final PlayerSettings settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'Gameplay',
      children: <Widget>[
        SwitchListTile.adaptive(
          key: const Key('settings-sound-effects'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Sound effects'),
          value: settings.soundEffects,
          onChanged: controller.setSoundEffects,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<AiDifficulty>(
          key: const Key('settings-default-difficulty'),
          initialValue: settings.defaultAiDifficulty,
          decoration: const InputDecoration(labelText: 'Default AI difficulty'),
          items: AiDifficulty.values
              .map(
                (difficulty) => DropdownMenuItem<AiDifficulty>(
                  value: difficulty,
                  child: Text(difficulty.preset.label),
                ),
              )
              .toList(growable: false),
          onChanged: (difficulty) {
            if (difficulty != null) {
              controller.setDefaultAiDifficulty(difficulty);
            }
          },
        ),
        const SizedBox(height: 14),
        Text('Preferred side', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<PlayerSide>(
          key: const Key('settings-preferred-side'),
          showSelectedIcon: false,
          segments: const <ButtonSegment<PlayerSide>>[
            ButtonSegment<PlayerSide>(
              value: PlayerSide.dark,
              label: Text('Dark'),
            ),
            ButtonSegment<PlayerSide>(
              value: PlayerSide.light,
              label: Text('Light'),
            ),
          ],
          selected: <PlayerSide>{settings.preferredHumanSide},
          onSelectionChanged: (selection) {
            controller.setPreferredHumanSide(selection.single);
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<BoardOrientationPreference>(
          key: const Key('settings-board-orientation'),
          initialValue: settings.boardOrientation,
          decoration: const InputDecoration(labelText: 'Board orientation'),
          items: BoardOrientationPreference.values
              .map(
                (orientation) => DropdownMenuItem<BoardOrientationPreference>(
                  value: orientation,
                  child: Text(_orientationLabel(orientation)),
                ),
              )
              .toList(growable: false),
          onChanged: (orientation) {
            if (orientation != null) {
              controller.setBoardOrientation(orientation);
            }
          },
        ),
      ],
    );
  }
}

class _ConfirmationSettings extends StatelessWidget {
  const _ConfirmationSettings({
    required this.settings,
    required this.controller,
  });

  final PlayerSettings settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'Confirmations',
      children: <Widget>[
        SwitchListTile.adaptive(
          key: const Key('settings-confirm-resign'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Confirm before resign'),
          value: settings.confirmBeforeResign,
          onChanged: controller.setConfirmBeforeResign,
        ),
        SwitchListTile.adaptive(
          key: const Key('settings-confirm-restart'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Confirm before restart'),
          value: settings.confirmBeforeRestart,
          onChanged: controller.setConfirmBeforeRestart,
        ),
      ],
    );
  }
}

class _ResetSettingsButton extends StatelessWidget {
  const _ResetSettingsButton({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('reset-settings-button'),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reset all settings?'),
            content: const Text(
              'Theme, gameplay, and accessibility preferences will return to their defaults.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('confirm-reset-settings-button'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Reset'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) await controller.resetToDefaults();
      },
      icon: const Icon(Icons.restore_rounded),
      label: const Text('Reset to defaults'),
    );
  }
}

String _orientationLabel(BoardOrientationPreference value) {
  return switch (value) {
    BoardOrientationPreference.automatic => 'Automatic',
    BoardOrientationPreference.darkAtBottom => 'Dark at bottom',
    BoardOrientationPreference.lightAtBottom => 'Light at bottom',
  };
}

String _themeLabel(AppThemePreference value) {
  return switch (value) {
    AppThemePreference.system => 'System',
    AppThemePreference.light => 'Light',
    AppThemePreference.dark => 'Dark',
  };
}
