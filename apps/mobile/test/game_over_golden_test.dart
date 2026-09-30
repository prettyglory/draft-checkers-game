import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/app/theme/app_theme.dart';
import 'package:draft_game/features/game/application/game_configuration.dart';
import 'package:draft_game/features/game/presentation/game_board_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();

  GameState completedState() {
    final initial = engine.createInitialState();
    return GameState(
      rulesetId: initial.rulesetId,
      boardSize: initial.boardSize,
      pieces: initial.pieces,
      activeSide: PlayerSide.light,
      ply: 17,
      revision: 18,
      ruleCounters: initial.ruleCounters,
      status: GameStatus.completed,
      outcome: const GameOutcome.win(
        winner: PlayerSide.dark,
        reason: GameOutcomeReason.resignation,
      ),
    );
  }

  Future<void> pumpGolden(
    WidgetTester tester,
    Size size, {
    ThemeMode themeMode = ThemeMode.light,
    bool scrollPhone = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: GameBoardScreen(
            initialState: completedState(),
            configuration: const GameConfiguration(
              mode: GameMode.humanVsAi,
              humanSide: PlayerSide.light,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (scrollPhone) {
      await tester.drag(
        find.byKey(const Key('phone-game-layout')),
        const Offset(0, -680),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('phone game over matches its light baseline', (tester) async {
    await pumpGolden(tester, const Size(390, 844), scrollPhone: true);

    await expectLater(
      find.byType(GameBoardScreen),
      matchesGoldenFile('goldens/game_over_phone.png'),
    );
  });

  testWidgets('phone game over matches its dark baseline', (tester) async {
    await pumpGolden(
      tester,
      const Size(390, 844),
      themeMode: ThemeMode.dark,
      scrollPhone: true,
    );

    await expectLater(
      find.byType(GameBoardScreen),
      matchesGoldenFile('goldens/game_over_phone_dark.png'),
    );
  });

  testWidgets('tablet game over matches its light baseline', (tester) async {
    await pumpGolden(tester, const Size(1180, 820));

    await expectLater(
      find.byType(GameBoardScreen),
      matchesGoldenFile('goldens/game_over_tablet.png'),
    );
  });

  testWidgets('tablet game over matches its dark baseline', (tester) async {
    await pumpGolden(tester, const Size(1180, 820), themeMode: ThemeMode.dark);

    await expectLater(
      find.byType(GameBoardScreen),
      matchesGoldenFile('goldens/game_over_tablet_dark.png'),
    );
  });
}
