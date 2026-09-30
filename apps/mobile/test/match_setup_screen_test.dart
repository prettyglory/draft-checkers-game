import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/app/draft_game_app.dart';
import 'package:draft_game/app/theme/app_theme.dart';
import 'package:draft_game/features/game/application/game_configuration.dart';
import 'package:draft_game/features/game/application/match_setup_view_model.dart';
import 'package:draft_game/features/game/presentation/game_board_screen.dart';
import 'package:draft_game/features/game/presentation/match_setup_screen.dart';
import 'package:draft_game/features/settings/application/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/controlled_ai_turn_runner.dart';
import 'support/memory_settings_repository.dart';

void main() {
  Future<void> pumpAtSize(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(430, 1000),
    double textScaleFactor = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  }

  MaterialApp setupApp({
    MatchSetupViewModel? viewModel,
    MatchBoardBuilder? boardBuilder,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: MatchSetupScreen(viewModel: viewModel, boardBuilder: boardBuilder),
    );
  }

  Future<DraftGameApp> draftGameApp() async {
    final controller = SettingsController(
      settingsRepository: MemorySettingsRepository(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    return DraftGameApp(settingsController: controller);
  }

  testWidgets('app opens on valid Human vs Human setup', (tester) async {
    await pumpAtSize(tester, await draftGameApp());

    expect(find.byType(MatchSetupScreen), findsOneWidget);
    expect(find.byKey(const Key('phone-setup-layout')), findsOneWidget);
    expect(find.text('Two players'), findsOneWidget);
    expect(find.text('American Checkers'), findsOneWidget);

    final selector = tester.widget<SegmentedButton<GameMode>>(
      find.byKey(const Key('setup-mode-selector')),
    );
    expect(selector.selected, <GameMode>{GameMode.localTwoPlayer});
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('start-game-button')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Human vs AI setup selects every difficulty and both sides', (
    tester,
  ) async {
    final viewModel = MatchSetupViewModel();
    addTearDown(viewModel.dispose);
    await pumpAtSize(tester, setupApp(viewModel: viewModel));

    await tester.tap(find.text('Computer'));
    await tester.pump();

    for (final difficulty in AiDifficulty.values) {
      final chip = find.byKey(
        ValueKey<String>('difficulty-${difficulty.name}'),
      );
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
      expect(viewModel.difficulty, difficulty);
    }

    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(viewModel.humanSide, PlayerSide.light);

    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(viewModel.humanSide, PlayerSide.dark);
  });

  testWidgets('incomplete configuration disables Start Game', (tester) async {
    final viewModel = MatchSetupViewModel(initialMode: null);
    addTearDown(viewModel.dispose);
    await pumpAtSize(tester, setupApp(viewModel: viewModel));

    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('start-game-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('setup supports narrow screens and doubled text scaling', (
    tester,
  ) async {
    await pumpAtSize(
      tester,
      await draftGameApp(),
      size: const Size(320, 700),
      textScaleFactor: 2,
    );

    expect(find.byKey(const Key('phone-setup-layout')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Start Game navigates with the selected configuration', (
    tester,
  ) async {
    GameConfiguration? receivedConfiguration;
    await pumpAtSize(
      tester,
      setupApp(
        boardBuilder: (configuration) {
          receivedConfiguration = configuration;
          return const Scaffold(body: Text('Configured board'));
        },
      ),
    );

    await tester.tap(find.text('Computer'));
    await tester.pump();
    await tester.tap(find.text('Light'));
    await tester.tap(find.byKey(const ValueKey<String>('difficulty-hard')));
    await tester.ensureVisible(find.byKey(const Key('start-game-button')));
    await tester.tap(find.byKey(const Key('start-game-button')));
    await tester.pumpAndSettle();

    expect(find.text('Configured board'), findsOneWidget);
    expect(receivedConfiguration?.mode, GameMode.humanVsAi);
    expect(receivedConfiguration?.humanSide, PlayerSide.light);
    expect(receivedConfiguration?.difficulty, AiDifficulty.hard);
    expect(receivedConfiguration?.ruleset, GameRuleset.american);
  });

  testWidgets(
    'AI opens, blocks input, preserves setup on reset, and cancels on exit',
    (tester) async {
      final runner = ControlledAiTurnRunner();
      await pumpAtSize(
        tester,
        setupApp(
          boardBuilder: (configuration) => GameBoardScreen(
            configuration: configuration,
            aiTurnRunnerFactory: () => runner,
          ),
        ),
      );

      await tester.tap(find.text('Computer'));
      await tester.pump();
      await tester.tap(find.text('Light'));
      await tester.ensureVisible(find.byKey(const Key('start-game-button')));
      await tester.tap(find.byKey(const Key('start-game-button')));
      await tester.pumpAndSettle();

      expect(find.byType(GameBoardScreen), findsOneWidget);
      expect(runner.requests, hasLength(1));
      expect(runner.requests.single.state.activeSide, PlayerSide.dark);
      expect(find.text('Computer is thinking'), findsOneWidget);
      expect(find.text('Human vs AI · Medium'), findsOneWidget);
      expect(find.text('You play Light · AI: Dark'), findsOneWidget);

      await tester.tap(find.byKey(const Key('square-2-1')));
      await tester.pump();
      expect(find.byKey(const Key('target-3-0')), findsNothing);

      await tester.drag(
        find.byKey(const Key('phone-game-layout')),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('restart-match-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-restart-button')));
      await tester.pumpAndSettle();
      expect(runner.requests, hasLength(2));
      expect(runner.cancellationCount, greaterThan(0));
      expect(find.text('You play Light · AI: Dark'), findsOneWidget);

      await tester.tap(find.byKey(const Key('leave-match-button')));
      await tester.pumpAndSettle();
      expect(find.text('Leave active match?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-leave-button')));
      await tester.pumpAndSettle();

      expect(find.byType(MatchSetupScreen), findsOneWidget);
      expect(runner.disposed, isTrue);
      expect(runner.hasPendingSearch, isFalse);
    },
  );

  testWidgets('setup meets accessibility guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAtSize(tester, await draftGameApp());

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
