import 'dart:async';

import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/game/application/ai_turn_runner.dart';
import 'package:draft_game/features/game/application/game_configuration.dart';
import 'package:draft_game/features/game/presentation/game_board_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_session/game_session.dart';

import 'support/controlled_ai_turn_runner.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();
  const actors = <String, PlayerSide>{
    'local-dark': PlayerSide.dark,
    'local-light': PlayerSide.light,
  };

  InProcessGameSession createSession({GameState? initialState}) {
    return InProcessGameSession(
      id: 'view-model-test',
      rulesEngine: engine,
      initialState: initialState ?? engine.createInitialState(),
      actorSides: actors,
    );
  }

  GameBoardViewModel createViewModel(InProcessGameSession session) {
    return GameBoardViewModel(
      session: session,
      actorIdsBySide: const <PlayerSide, String>{
        PlayerSide.dark: 'local-dark',
        PlayerSide.light: 'local-light',
      },
    );
  }

  GameBoardViewModel createAiViewModel(
    InProcessGameSession session,
    AiTurnRunner runner, {
    PlayerSide humanSide = PlayerSide.dark,
    AiDifficulty difficulty = AiDifficulty.medium,
  }) {
    return GameBoardViewModel(
      session: session,
      actorIdsBySide: const <PlayerSide, String>{
        PlayerSide.dark: 'local-dark',
        PlayerSide.light: 'local-light',
      },
      configuration: GameConfiguration(
        mode: GameMode.humanVsAi,
        humanSide: humanSide,
        difficulty: difficulty,
      ),
      aiTurnRunner: runner,
    );
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

  test('selection exposes only session-approved next landings', () async {
    final viewModel = createViewModel(createSession());
    addTearDown(viewModel.dispose);

    await viewModel.tapSquare(BoardPosition(row: 2, column: 1));

    expect(viewModel.selectedPieceId, 'dark-09');
    expect(viewModel.targetPositions, <BoardPosition>{
      BoardPosition(row: 3, column: 0),
      BoardPosition(row: 3, column: 2),
    });
  });

  test('multi-capture previews each step before applying one turn', () async {
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
    final viewModel = createViewModel(
      createSession(initialState: captureState),
    );
    addTearDown(viewModel.dispose);

    await viewModel.tapSquare(BoardPosition(row: 2, column: 1));
    await viewModel.tapSquare(BoardPosition(row: 4, column: 3));

    expect(viewModel.state.revision, 0);
    expect(viewModel.isPathInProgress, isTrue);
    expect(
      viewModel.displayPieceAt(BoardPosition(row: 4, column: 3))?.id,
      'dark-jumper',
    );
    expect(viewModel.targetPositions, <BoardPosition>{
      BoardPosition(row: 6, column: 1),
    });

    await viewModel.tapSquare(BoardPosition(row: 6, column: 1));

    expect(viewModel.state.revision, 1);
    expect(viewModel.state.status, GameStatus.completed);
    expect(viewModel.selectedPieceId, isNull);
    expect(viewModel.lastCommandReceipt?.accepted, isTrue);
  });

  test('reset restores the WCDF opening state through the session', () async {
    final viewModel = createViewModel(createSession());
    addTearDown(viewModel.dispose);
    await viewModel.tapSquare(BoardPosition(row: 2, column: 1));
    await viewModel.tapSquare(BoardPosition(row: 3, column: 0));
    expect(viewModel.state.revision, 1);

    await viewModel.reset();

    expect(viewModel.state.revision, 2);
    expect(viewModel.state.activeSide, PlayerSide.dark);
    expect(viewModel.state.board.pieceCount, 24);
    expect(viewModel.selectedPieceId, isNull);
  });

  test('promotion crowns a man and ends its capture turn', () async {
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
    final viewModel = createViewModel(
      createSession(initialState: promotionState),
    );
    addTearDown(viewModel.dispose);

    await viewModel.tapSquare(BoardPosition(row: 5, column: 0));
    expect(viewModel.targetPositions, <BoardPosition>{
      BoardPosition(row: 7, column: 2),
    });

    await viewModel.tapSquare(BoardPosition(row: 7, column: 2));

    expect(viewModel.state.revision, 1);
    expect(viewModel.state.activeSide, PlayerSide.light);
    expect(viewModel.state.board.pieceById('dark-man')?.rank, PieceRank.king);
    expect(viewModel.state.board.pieceById('light-backward-option'), isNotNull);
  });

  test('king selection exposes backward moves', () async {
    final kingState = GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: <Piece>[
        piece('dark-king', PlayerSide.dark, 4, 3, rank: PieceRank.king),
        piece('light-far', PlayerSide.light, 0, 1),
      ],
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );
    final viewModel = createViewModel(createSession(initialState: kingState));
    addTearDown(viewModel.dispose);

    await viewModel.tapSquare(BoardPosition(row: 4, column: 3));

    expect(
      viewModel.targetPositions,
      contains(BoardPosition(row: 3, column: 2)),
    );
    expect(
      viewModel.targetPositions,
      contains(BoardPosition(row: 3, column: 4)),
    );
  });

  test(
    'reflects authoritative session updates from outside the view model',
    () async {
      final session = createSession();
      final viewModel = createViewModel(session);
      addTearDown(viewModel.dispose);

      final receipt = await session.submit(
        ResignCommand(
          commandId: 'external-resignation',
          actorId: 'local-light',
          expectedRevision: 0,
        ),
      );
      await pumpEventQueue();

      expect(receipt.accepted, isTrue);
      expect(viewModel.state, same(session.currentState));
      expect(viewModel.state.status, GameStatus.completed);
      expect(viewModel.statusTitle, 'Dark wins');
      expect(viewModel.statusDetail, 'Light resigned.');
    },
  );

  test('AI moves only on its turn through the authoritative session', () async {
    final session = createSession();
    final runner = ControlledAiTurnRunner();
    final viewModel = createAiViewModel(session, runner);
    addTearDown(viewModel.dispose);
    await pumpEventQueue();

    expect(runner.requests, isEmpty);
    expect(viewModel.canHumanInteract, isTrue);

    await viewModel.tapSquare(BoardPosition(row: 2, column: 1));
    await viewModel.tapSquare(BoardPosition(row: 3, column: 0));

    expect(viewModel.state.activeSide, PlayerSide.light);
    expect(viewModel.aiTurnStatus, AiTurnStatus.thinking);
    expect(runner.requests, hasLength(1));
    expect(runner.requests.single.state.revision, 1);
    expect(runner.requests.single.difficulty, AiDifficulty.medium);

    await viewModel.tapSquare(runner.requests.single.legalMoves.first.origin);
    expect(viewModel.selectedPieceId, isNull);
    expect(viewModel.selectablePieceIds, isEmpty);

    final selectedMove = runner.requests.single.legalMoves.first;
    runner.completeWithMove(selectedMove);
    await pumpEventQueue();

    expect(viewModel.state, same(session.currentState));
    expect(viewModel.state.revision, 2);
    expect(viewModel.state.activeSide, PlayerSide.dark);
    expect(viewModel.lastCommandReceipt?.accepted, isTrue);
    expect(viewModel.aiTurnStatus, AiTurnStatus.moveCompleted);
    expect(viewModel.canHumanInteract, isTrue);
  });

  test('AI opens when the human chooses Light', () async {
    final runner = ControlledAiTurnRunner();
    final viewModel = createAiViewModel(
      createSession(),
      runner,
      humanSide: PlayerSide.light,
      difficulty: AiDifficulty.easy,
    );
    addTearDown(viewModel.dispose);

    await pumpEventQueue();

    expect(runner.requests, hasLength(1));
    expect(runner.requests.single.state.activeSide, PlayerSide.dark);
    expect(runner.requests.single.difficulty, AiDifficulty.easy);
    expect(viewModel.canHumanInteract, isFalse);
    expect(viewModel.statusTitle, 'Computer is thinking');
  });

  test('reset cancels a pending AI search and ignores its result', () async {
    final runner = ControlledAiTurnRunner();
    final viewModel = createAiViewModel(createSession(), runner);
    addTearDown(viewModel.dispose);
    await pumpEventQueue();
    await viewModel.tapSquare(BoardPosition(row: 2, column: 1));
    await viewModel.tapSquare(BoardPosition(row: 3, column: 0));
    expect(runner.hasPendingSearch, isTrue);
    final cancellationsBefore = runner.cancellationCount;

    await viewModel.reset();
    await pumpEventQueue();

    expect(runner.cancellationCount, greaterThan(cancellationsBefore));
    expect(viewModel.state.revision, 2);
    expect(viewModel.state.activeSide, PlayerSide.dark);
    expect(viewModel.state.board.pieceCount, 24);
    expect(viewModel.aiTurnStatus, AiTurnStatus.ready);
    expect(runner.requests, hasLength(1));
  });

  test('difficulty change cancels search and starts a fresh match', () async {
    final runner = ControlledAiTurnRunner();
    final viewModel = createAiViewModel(createSession(), runner);
    addTearDown(viewModel.dispose);
    await pumpEventQueue();
    await viewModel.tapSquare(BoardPosition(row: 2, column: 1));
    await viewModel.tapSquare(BoardPosition(row: 3, column: 0));
    final cancellationsBefore = runner.cancellationCount;

    await viewModel.setDifficulty(AiDifficulty.expert);
    await pumpEventQueue();

    expect(viewModel.configuration.difficulty, AiDifficulty.expert);
    expect(runner.cancellationCount, greaterThan(cancellationsBefore));
    expect(viewModel.state.revision, 2);
    expect(viewModel.state.activeSide, PlayerSide.dark);
    expect(viewModel.aiTurnStatus, AiTurnStatus.ready);
  });

  test('disposing the view model cancels pending AI work', () async {
    final runner = ControlledAiTurnRunner();
    final viewModel = createAiViewModel(
      createSession(),
      runner,
      humanSide: PlayerSide.light,
    );
    await pumpEventQueue();
    expect(runner.hasPendingSearch, isTrue);

    viewModel.dispose();
    await pumpEventQueue();

    expect(runner.disposed, isTrue);
    expect(runner.hasPendingSearch, isFalse);
  });

  test(
    'either human side can resign and repeated resignation is ignored',
    () async {
      final viewModel = createViewModel(createSession());
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      final receipt = await viewModel.resign(PlayerSide.light);
      final revision = viewModel.state.revision;
      final repeated = await viewModel.resign(PlayerSide.light);

      expect(receipt?.accepted, isTrue);
      expect(viewModel.state.status, GameStatus.completed);
      expect(viewModel.state.outcome?.winner, PlayerSide.dark);
      expect(viewModel.state.outcome?.reason, GameOutcomeReason.resignation);
      expect(viewModel.matchResultLabel, 'Dark wins');
      expect(viewModel.sideResultLabel, 'Dark won · Light lost');
      expect(repeated, isNull);
      expect(viewModel.state.revision, revision);
    },
  );

  test('AI side can resign and records the human result', () async {
    final runner = ControlledAiTurnRunner();
    final viewModel = createAiViewModel(
      createSession(),
      runner,
      humanSide: PlayerSide.light,
    );
    addTearDown(viewModel.dispose);
    await pumpEventQueue();

    await viewModel.resign(PlayerSide.dark);

    expect(viewModel.state.outcome?.winner, PlayerSide.light);
    expect(viewModel.matchResultLabel, 'You win');
    expect(viewModel.sideResultLabel, 'Your Light side won.');
    expect(runner.hasPendingSearch, isFalse);
  });

  test('draw offer can be declined and then accepted', () async {
    final viewModel = createViewModel(createSession());
    addTearDown(viewModel.dispose);
    await pumpEventQueue();

    final offered = await viewModel.offerDraw(PlayerSide.dark);
    expect(offered?.accepted, isTrue);
    expect(viewModel.pendingDrawOffer?.side, PlayerSide.dark);
    expect(viewModel.canHumanInteract, isFalse);

    final declined = await viewModel.respondToDraw(
      side: PlayerSide.light,
      accepted: false,
    );
    expect(declined?.accepted, isTrue);
    expect(viewModel.pendingDrawOffer, isNull);
    expect(viewModel.state.status, GameStatus.active);

    await viewModel.offerDraw(PlayerSide.light);
    final accepted = await viewModel.respondToDraw(
      side: PlayerSide.dark,
      accepted: true,
    );
    final repeated = await viewModel.respondToDraw(
      side: PlayerSide.dark,
      accepted: true,
    );

    expect(accepted?.accepted, isTrue);
    expect(viewModel.state.status, GameStatus.completed);
    expect(viewModel.state.outcome?.type, GameOutcomeType.draw);
    expect(viewModel.state.outcome?.reason, GameOutcomeReason.drawAgreement);
    expect(viewModel.matchResultLabel, 'Draw');
    expect(repeated, isNull);
  });

  test(
    'AI draw response is authoritative and cannot be controlled by human',
    () async {
      final runner = ControlledAiTurnRunner();
      final viewModel = createAiViewModel(createSession(), runner);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      final offered = await viewModel.offerDraw(PlayerSide.dark);

      expect(offered?.accepted, isTrue);
      expect(viewModel.pendingDrawOffer, isNull);
      expect(viewModel.state.status, GameStatus.active);
      expect(
        await viewModel.respondToDraw(side: PlayerSide.light, accepted: true),
        isNull,
      );
    },
  );

  test('completed game ignores further board input', () async {
    final viewModel = createViewModel(createSession());
    addTearDown(viewModel.dispose);
    await pumpEventQueue();
    await viewModel.resign(PlayerSide.light);
    final revision = viewModel.state.revision;

    await viewModel.tapSquare(BoardPosition(row: 2, column: 1));
    await viewModel.tapSquare(BoardPosition(row: 3, column: 0));

    expect(viewModel.selectedPieceId, isNull);
    expect(viewModel.state.revision, revision);
    expect(viewModel.legalMoves, isEmpty);
  });

  test(
    'completion cancels AI search and restart ignores its stale result',
    () async {
      final runner = _StubbornAiTurnRunner();
      final viewModel = createAiViewModel(
        createSession(),
        runner,
        humanSide: PlayerSide.light,
      );
      addTearDown(viewModel.dispose);
      await pumpEventQueue();
      expect(runner.requests, hasLength(1));

      await viewModel.restart();
      await pumpEventQueue();
      expect(runner.cancellationCount, greaterThan(0));
      expect(runner.requests, hasLength(2));
      expect(viewModel.state.revision, 1);

      runner.complete(0);
      await pumpEventQueue();

      expect(viewModel.state.revision, 1);
      expect(viewModel.state.activeSide, PlayerSide.dark);
      expect(viewModel.aiTurnStatus, AiTurnStatus.thinking);
    },
  );
}

final class _StubbornAiTurnRunner implements AiTurnRunner {
  final List<AiTurnRequestRecord> requests = <AiTurnRequestRecord>[];
  final List<Completer<AiSearchResult>> _completers =
      <Completer<AiSearchResult>>[];
  int cancellationCount = 0;

  @override
  Future<AiSearchResult> chooseMove({
    required AiDifficulty difficulty,
    required GameState state,
    required List<Move> legalMoves,
  }) {
    requests.add(
      AiTurnRequestRecord(
        difficulty: difficulty,
        state: state,
        legalMoves: List<Move>.unmodifiable(legalMoves),
      ),
    );
    final completer = Completer<AiSearchResult>();
    _completers.add(completer);
    return completer.future;
  }

  void complete(int index) {
    final request = requests[index];
    _completers[index].complete(
      AiSearchResult(
        move: request.legalMoves.first,
        metadata: AiSearchMetadata(
          strategyId: 'stubborn-test-ai',
          nodesExamined: 1,
          completedDepth: 1,
          elapsed: Duration.zero,
          stopReason: SearchStopReason.completed,
        ),
      ),
    );
  }

  @override
  void cancel() {
    cancellationCount += 1;
  }

  @override
  void dispose() {
    cancel();
    for (final completer in _completers) {
      if (!completer.isCompleted) {
        completer.completeError(const AiSearchCancelledException());
      }
    }
  }
}
