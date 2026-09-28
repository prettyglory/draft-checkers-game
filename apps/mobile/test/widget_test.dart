import 'dart:ui' show SemanticsAction;

import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/app/draft_game_app.dart';
import 'package:draft_game/app/theme/app_theme.dart';
import 'package:draft_game/features/game/presentation/game_board_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAtSize(
    WidgetTester tester,
    Size size, {
    Widget? child,
    double textScaleFactor = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(child ?? const DraftGameApp());
    await tester.pumpAndSettle();
  }

  Piece piece(
    String id,
    PlayerSide side,
    int row,
    int column, {
    PieceRank rank = PieceRank.man,
  }) {
    return Piece(
      id: id,
      side: side,
      rank: rank,
      position: BoardPosition(row: row, column: column),
    );
  }

  testWidgets('renders a complete playable board on a phone', (tester) async {
    await pumpAtSize(tester, const Size(390, 844));

    expect(find.byKey(const Key('phone-game-layout')), findsOneWidget);
    expect(find.byKey(const Key('game-board')), findsOneWidget);
    expect(find.text('Draft Game'), findsOneWidget);
    expect(find.text('Phase 4 · Playable board'), findsOneWidget);
    expect(find.text('Dark to move'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('board-cell-'),
      ),
      findsNWidgets(64),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('piece-'),
      ),
      findsNWidgets(24),
    );
  });

  testWidgets('switches to the side-panel layout on a tablet', (tester) async {
    await pumpAtSize(tester, const Size(1180, 820));

    expect(find.byKey(const Key('wide-game-layout')), findsOneWidget);
    expect(find.byKey(const Key('phone-game-layout')), findsNothing);
    final boardSize = tester.getSize(find.byKey(const Key('game-board')));
    expect(boardSize.width, boardSize.height);
    expect(boardSize.width, inInclusiveRange(384, 680));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits the compact tablet breakpoint without overflow', (
    tester,
  ) async {
    await pumpAtSize(tester, const Size(820, 620));

    expect(find.byKey(const Key('wide-game-layout')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('game-board'))).width, 414);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports narrow screens and doubled text scaling', (
    tester,
  ) async {
    await pumpAtSize(tester, const Size(320, 700), textScaleFactor: 2);

    expect(find.byKey(const Key('phone-game-layout')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('game-board'))).width, 384);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects a piece and applies a highlighted legal move', (
    tester,
  ) async {
    await pumpAtSize(tester, const Size(430, 900));

    await tester.tap(find.byKey(const Key('square-2-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('target-3-0')), findsOneWidget);
    expect(find.byKey(const Key('target-3-2')), findsOneWidget);
    expect(find.text('Choose a highlighted landing square.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('square-3-0')));
    await tester.pumpAndSettle();

    expect(find.text('Light to move'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('square-3-0')),
        matching: find.byKey(const Key('piece-dark-09')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('guides every landing in a mandatory multi-capture', (
    tester,
  ) async {
    final captureState = GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: <Piece>[
        piece('dark-jumper', PlayerSide.dark, 2, 1),
        piece('light-first', PlayerSide.light, 3, 2),
        piece('light-second', PlayerSide.light, 5, 2),
      ],
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );
    await pumpAtSize(
      tester,
      const Size(430, 900),
      child: MaterialApp(
        theme: AppTheme.light,
        home: GameBoardScreen(initialState: captureState),
      ),
    );

    expect(find.byKey(const Key('capture-required-banner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('square-2-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('target-4-3')), findsOneWidget);

    await tester.tap(find.byKey(const Key('square-4-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('path-4-3-1')), findsOneWidget);
    expect(find.byKey(const Key('target-6-1')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('square-4-3')),
        matching: find.byKey(const Key('piece-dark-jumper')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('square-6-1')));
    await tester.pumpAndSettle();
    expect(find.text('Dark wins'), findsOneWidget);
    expect(find.byKey(const Key('capture-required-banner')), findsNothing);
  });

  testWidgets('crowns a promoted piece and renders its king marker', (
    tester,
  ) async {
    final promotionState = GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: <Piece>[
        piece('dark-man', PlayerSide.dark, 5, 0),
        piece('light-crowned-jump', PlayerSide.light, 6, 1),
        piece('light-backward-option', PlayerSide.light, 6, 3),
      ],
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );
    await pumpAtSize(
      tester,
      const Size(430, 900),
      child: MaterialApp(
        theme: AppTheme.light,
        home: GameBoardScreen(initialState: promotionState),
      ),
    );

    await tester.tap(find.byKey(const Key('square-5-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('square-7-2')));
    await tester.pumpAndSettle();

    final promotedPiece = find.byKey(const Key('piece-dark-man'));
    expect(
      find.descendant(
        of: promotedPiece,
        matching: find.byIcon(Icons.star_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byKey(const Key('square-7-2'))).label,
      contains('dark king'),
    );
    expect(
      find.byKey(const Key('piece-light-backward-option')),
      findsOneWidget,
    );
    expect(find.text('Light to move'), findsOneWidget);
  });

  testWidgets('lets a king move backward through the board UI', (tester) async {
    final kingState = GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: <Piece>[
        piece('dark-king', PlayerSide.dark, 4, 3, rank: PieceRank.king),
        piece('light-far', PlayerSide.light, 6, 1),
      ],
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );
    await pumpAtSize(
      tester,
      const Size(430, 900),
      child: MaterialApp(
        theme: AppTheme.light,
        home: GameBoardScreen(initialState: kingState),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('piece-dark-king')),
        matching: find.byIcon(Icons.star_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('square-4-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('target-3-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('square-3-2')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('square-3-2')),
        matching: find.byKey(const Key('piece-dark-king')),
      ),
      findsOneWidget,
    );
    expect(find.text('Light to move'), findsOneWidget);
  });

  testWidgets('presents and follows both branches of a capture choice', (
    tester,
  ) async {
    final branchingState = GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: <Piece>[
        piece('dark-jumper', PlayerSide.dark, 2, 3),
        piece('light-left', PlayerSide.light, 3, 2),
        piece('light-right', PlayerSide.light, 3, 4),
        piece('light-follow-up', PlayerSide.light, 5, 6),
      ],
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );
    await pumpAtSize(
      tester,
      const Size(430, 900),
      child: MaterialApp(
        theme: AppTheme.light,
        home: GameBoardScreen(initialState: branchingState),
      ),
    );

    await tester.tap(find.byKey(const Key('square-2-3')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('target-4-1')), findsOneWidget);
    expect(find.byKey(const Key('target-4-5')), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('square-4-1'))).label,
      contains('legal destination'),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('square-4-5'))).label,
      contains('next capture landing'),
    );

    await tester.tap(find.byKey(const Key('square-4-5')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('path-4-5-1')), findsOneWidget);
    expect(find.byKey(const Key('target-6-7')), findsOneWidget);
    expect(find.byKey(const Key('target-4-1')), findsNothing);
    expect(
      tester
          .getSemantics(find.byKey(const Key('square-4-5')))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );

    await tester.tap(find.byKey(const Key('square-6-7')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('piece-light-right')), findsNothing);
    expect(find.byKey(const Key('piece-light-follow-up')), findsNothing);
    expect(find.text('Light to move'), findsOneWidget);
  });

  testWidgets('supports keyboard traversal and activation of legal squares', (
    tester,
  ) async {
    final keyboardState = GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: <Piece>[
        piece('dark-keyboard', PlayerSide.dark, 2, 1),
        piece('light-far', PlayerSide.light, 6, 1),
      ],
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );
    await pumpAtSize(
      tester,
      const Size(430, 900),
      child: MaterialApp(
        theme: AppTheme.light,
        home: GameBoardScreen(initialState: keyboardState),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tester.binding.focusManager.primaryFocus, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('target-3-0')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tester.binding.focusManager.primaryFocus, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('square-3-0')),
        matching: find.byKey(const Key('piece-dark-keyboard')),
      ),
      findsOneWidget,
    );
    expect(find.text('Light to move'), findsOneWidget);
  });

  testWidgets('exposes labeled squares and meets accessibility guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpAtSize(tester, const Size(430, 900));

    final square = tester.getSemantics(find.byKey(const Key('square-2-1')));
    expect(square.label, contains('Square 9, dark man, selectable'));

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
