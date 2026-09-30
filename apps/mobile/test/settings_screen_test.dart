import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/app/draft_game_app.dart';
import 'package:draft_game/app/theme/app_theme.dart';
import 'package:draft_game/features/game/presentation/game_board_screen.dart';
import 'package:draft_game/features/settings/application/settings_controller.dart';
import 'package:draft_game/features/settings/domain/player_settings.dart';
import 'package:draft_game/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_settings_repository.dart';

void main() {
  Future<SettingsController> pumpSettingsApp(
    WidgetTester tester, {
    PlayerSettings initial = PlayerSettings.defaults,
    Size size = const Size(430, 1000),
    double textScaleFactor = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = SettingsController(
      settingsRepository: MemorySettingsRepository(initial),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(DraftGameApp(settingsController: controller));
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  }

  testWidgets('theme switches immediately', (tester) async {
    final controller = await pumpSettingsApp(tester);
    await openSettings(tester);

    final dark = find.descendant(
      of: find.byKey(const Key('settings-theme-selector')),
      matching: find.text('Dark'),
    );
    await tester.tap(dark);
    await tester.pumpAndSettle();

    expect(controller.settings.themeMode, AppThemePreference.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('reduced motion and larger text update MediaQuery', (
    tester,
  ) async {
    final controller = await pumpSettingsApp(tester);
    await openSettings(tester);

    await tester.tap(find.byKey(const Key('settings-reduced-motion')));
    await tester.pumpAndSettle();
    expect(controller.settings.reducedMotion, isTrue);
    expect(
      MediaQuery.disableAnimationsOf(
        tester.element(find.byType(SettingsScreen)),
      ),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('settings-larger-text')));
    await tester.pumpAndSettle();
    expect(controller.settings.largerText, isTrue);
    expect(
      MediaQuery.textScalerOf(tester.element(find.byType(SettingsScreen)))
          .scale(1),
      greaterThanOrEqualTo(1.15),
    );
  });

  testWidgets('saved AI defaults prepopulate match setup', (tester) async {
    await pumpSettingsApp(
      tester,
      initial: const PlayerSettings(
        defaultAiDifficulty: AiDifficulty.expert,
        preferredHumanSide: PlayerSide.light,
      ),
    );

    await tester.tap(find.text('Computer'));
    await tester.pumpAndSettle();

    final sideSelector = tester.widget<SegmentedButton<PlayerSide>>(
      find.byKey(const Key('setup-side-selector')),
    );
    final expertChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey<String>('difficulty-expert')),
    );
    expect(sideSelector.selected, <PlayerSide>{PlayerSide.light});
    expect(expertChip.selected, isTrue);
  });

  testWidgets('reset to defaults requires confirmation', (tester) async {
    final controller = await pumpSettingsApp(
      tester,
      initial: const PlayerSettings(
        themeMode: AppThemePreference.dark,
        reducedMotion: true,
        defaultAiDifficulty: AiDifficulty.expert,
      ),
    );
    await openSettings(tester);
    await tester.drag(
      find.byKey(const Key('phone-settings-layout')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reset-settings-button')));
    await tester.pumpAndSettle();
    expect(find.text('Reset all settings?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-reset-settings-button')));
    await tester.pumpAndSettle();
    expect(controller.settings, PlayerSettings.defaults);
  });

  testWidgets('settings supports narrow screens and doubled text scaling', (
    tester,
  ) async {
    await pumpSettingsApp(
      tester,
      size: const Size(320, 700),
      textScaleFactor: 2,
    );
    await openSettings(tester);

    expect(find.byKey(const Key('phone-settings-layout')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('board orientation preference rotates logical coordinates', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const GameBoardScreen(
          preferences: PlayerSettings(
            boardOrientation: BoardOrientationPreference.darkAtBottom,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boardTopLeft = tester.getTopLeft(find.byKey(const Key('game-board')));
    final rotatedTopLeft = tester.getTopLeft(
      find.byKey(const Key('board-cell-7-7')),
    );
    expect(rotatedTopLeft.dx, closeTo(boardTopLeft.dx, 0.1));
    expect(rotatedTopLeft.dy, closeTo(boardTopLeft.dy, 0.1));
  });

  testWidgets('disabled confirmations apply actions immediately', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const GameBoardScreen(
          preferences: PlayerSettings(
            confirmBeforeResign: false,
            confirmBeforeRestart: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('phone-game-layout')),
      const Offset(0, -720),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('restart-match-button')));
    await tester.pumpAndSettle();
    expect(find.text('Restart current match?'), findsNothing);

    await tester.tap(find.byKey(const Key('resign-button')));
    await tester.pumpAndSettle();
    expect(find.text('Which side resigns?'), findsNothing);
    expect(find.byKey(const Key('game-over-card')), findsOneWidget);
  });
}
