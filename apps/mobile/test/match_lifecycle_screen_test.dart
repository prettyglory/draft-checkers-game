import 'package:draft_game/app/theme/app_theme.dart';
import 'package:draft_game/features/game/presentation/game_board_screen.dart';
import 'package:draft_game/features/game/presentation/match_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/controlled_ai_turn_runner.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark, home: home),
    );
    await tester.pumpAndSettle();
  }

  Future<void> showActions(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('phone-game-layout')),
      const Offset(0, -720),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('human resignation confirms and shows complete result details', (
    tester,
  ) async {
    await pumpApp(tester, const GameBoardScreen());
    await showActions(tester);

    await tester.tap(find.byKey(const Key('resign-button')));
    await tester.pumpAndSettle();
    expect(find.text('Which side resigns?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('resign-light-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('game-over-card')), findsOneWidget);
    expect(find.text('Dark wins'), findsOneWidget);
    expect(find.text('Dark won · Light lost'), findsOneWidget);
    expect(find.text('Light resigned.'), findsOneWidget);
    expect(find.text('0 plies played'), findsOneWidget);
    expect(find.byKey(const Key('rematch-button')), findsOneWidget);
    expect(find.byKey(const Key('game-over-setup-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('square-2-1')));
    await tester.pump();
    expect(find.byKey(const Key('target-3-0')), findsNothing);
  });

  testWidgets('draw offer can be declined and then accepted once', (
    tester,
  ) async {
    await pumpApp(tester, const GameBoardScreen());
    await showActions(tester);

    await tester.tap(find.byKey(const Key('offer-draw-button')));
    await tester.pumpAndSettle();
    expect(find.text('Dark offered a draw'), findsOneWidget);

    await tester.tap(find.byKey(const Key('decline-draw-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('draw-offer-card')), findsNothing);

    await tester.tap(find.byKey(const Key('offer-draw-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accept-draw-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('game-over-card')), findsOneWidget);
    expect(find.text('Draw'), findsOneWidget);
    expect(find.text('Dark and Light drew.'), findsOneWidget);
    expect(find.text('Both players agreed to a draw.'), findsOneWidget);
    expect(find.byKey(const Key('accept-draw-button')), findsNothing);
  });

  testWidgets('restart requires confirmation and keeps the current match', (
    tester,
  ) async {
    await pumpApp(tester, const GameBoardScreen());
    await tester.tap(find.byKey(const Key('square-2-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('square-3-0')));
    await tester.pumpAndSettle();
    expect(find.text('Light to move'), findsOneWidget);
    await showActions(tester);

    await tester.tap(find.byKey(const Key('restart-match-button')));
    await tester.pumpAndSettle();
    expect(find.text('Restart current match?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-restart-button')));
    await tester.pumpAndSettle();

    expect(find.text('Dark to move'), findsOneWidget);
    expect(find.text('Human vs Human'), findsOneWidget);
    expect(find.byKey(const Key('rematch-button')), findsNothing);
  });

  testWidgets('rematch preserves AI setup and starts a fresh opening search', (
    tester,
  ) async {
    final runners = <ControlledAiTurnRunner>[];
    await pumpApp(
      tester,
      MatchSetupScreen(
        boardBuilder: (configuration) => GameBoardScreen(
          configuration: configuration,
          aiTurnRunnerFactory: () {
            final runner = ControlledAiTurnRunner();
            runners.add(runner);
            return runner;
          },
        ),
      ),
    );

    await tester.tap(find.text('Computer'));
    await tester.pump();
    await tester.tap(find.text('Light'));
    await tester.ensureVisible(find.byKey(const Key('start-game-button')));
    await tester.tap(find.byKey(const Key('start-game-button')));
    await tester.pumpAndSettle();
    expect(runners, hasLength(1));
    expect(runners.single.requests.single.state.revision, 0);

    await showActions(tester);
    await tester.tap(find.byKey(const Key('resign-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-resign-button')));
    await tester.pumpAndSettle();
    expect(find.text('Computer wins'), findsOneWidget);
    expect(find.text('You resigned.'), findsOneWidget);
    expect(find.text('Medium computer'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rematch-button')));
    await tester.tap(find.byKey(const Key('rematch-button')));
    await tester.pumpAndSettle();

    expect(runners, hasLength(2));
    expect(runners.first.disposed, isTrue);
    expect(runners.last.requests, hasLength(1));
    expect(runners.last.requests.single.state.revision, 0);
    expect(runners.last.requests.single.state.ply, 0);
    expect(find.text('Computer is thinking'), findsOneWidget);
    expect(find.text('Human vs AI · Medium'), findsOneWidget);
    expect(find.text('You play Light · AI: Dark'), findsOneWidget);
  });

  testWidgets('completed match returns to setup without leave confirmation', (
    tester,
  ) async {
    await pumpApp(
      tester,
      MatchSetupScreen(
        boardBuilder: (configuration) =>
            GameBoardScreen(configuration: configuration),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('start-game-button')));
    await tester.tap(find.byKey(const Key('start-game-button')));
    await tester.pumpAndSettle();
    await showActions(tester);
    await tester.tap(find.byKey(const Key('resign-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resign-light-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('game-over-setup-button')));
    await tester.pumpAndSettle();

    expect(find.byType(MatchSetupScreen), findsOneWidget);
    expect(find.text('Leave active match?'), findsNothing);
  });

  testWidgets('system back confirms before leaving an active match', (
    tester,
  ) async {
    await pumpApp(
      tester,
      MatchSetupScreen(
        boardBuilder: (configuration) =>
            GameBoardScreen(configuration: configuration),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('start-game-button')));
    await tester.tap(find.byKey(const Key('start-game-button')));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Leave active match?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byType(GameBoardScreen), findsOneWidget);
  });

  testWidgets('game-over actions meet accessibility guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, const GameBoardScreen());
    await showActions(tester);
    await tester.tap(find.byKey(const Key('resign-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resign-light-button')));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
