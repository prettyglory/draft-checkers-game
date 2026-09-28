import 'package:checkers_engine/checkers_engine.dart';
import 'package:game_session/game_session.dart';
import 'package:test/test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();
  const darkActor = 'local-dark';
  const lightActor = 'local-light';

  InProcessGameSession createSession({GameState? initialState}) {
    return InProcessGameSession(
      id: 'local-game',
      rulesEngine: engine,
      initialState: initialState ?? engine.createInitialState(),
      actorSides: const <String, PlayerSide>{
        darkActor: PlayerSide.dark,
        lightActor: PlayerSide.light,
      },
      clock: () => DateTime.utc(2026, 9, 28),
    );
  }

  SubmitMoveCommand moveCommand(
    InProcessGameSession session, {
    String commandId = 'move-1',
    String actorId = darkActor,
    int? expectedRevision,
    Move? move,
  }) {
    return SubmitMoveCommand(
      commandId: commandId,
      actorId: actorId,
      expectedRevision: expectedRevision ?? session.currentState.revision,
      move: move ?? session.legalMoves.first,
    );
  }

  group('construction and lifecycle', () {
    test('requires exactly one actor for each side', () {
      expect(
        () => InProcessGameSession(
          id: 'invalid',
          rulesEngine: engine,
          initialState: engine.createInitialState(),
          actorSides: const <String, PlayerSide>{darkActor: PlayerSide.dark},
        ),
        throwsArgumentError,
      );
    });

    test('starts, reconnects idempotently, and closes in sequence', () async {
      final session = createSession();
      final updates = <SessionUpdate>[];
      final subscription = session.updates.listen(updates.add);

      await session.start();
      await session.reconnect();
      await session.close();
      await subscription.cancel();

      expect(session.authority, SessionAuthority.localDevice);
      expect(session.connectionState, SessionConnectionState.closed);
      expect(updates, hasLength(2));
      expect(updates.map((update) => update.sequence), <int>[1, 2]);
      expect(
        (updates.first as ConnectionChanged).connectionState,
        SessionConnectionState.connected,
      );
      expect(
        (updates.last as ConnectionChanged).connectionState,
        SessionConnectionState.closed,
      );
    });

    test('rejects commands until started', () async {
      final session = createSession();
      addTearDown(session.close);

      final receipt = await session.submit(moveCommand(session));

      expect(receipt.accepted, isFalse);
      expect(receipt.rejection, CommandRejection.sessionUnavailable);
      expect(session.currentState.revision, 0);
    });
  });

  group('move authority', () {
    test('commits a valid move and emits the authoritative state', () async {
      final session = createSession();
      addTearDown(session.close);
      final updates = <SessionUpdate>[];
      final subscription = session.updates.listen(updates.add);
      addTearDown(subscription.cancel);
      await session.start();
      final command = moveCommand(session);

      final receipt = await session.submit(command);
      await pumpEventQueue();

      expect(receipt.accepted, isTrue);
      expect(receipt.committedSequence, 2);
      expect(session.currentState.revision, 1);
      expect(session.currentState.ply, 1);
      expect(session.currentState.activeSide, PlayerSide.light);
      final committed = updates.whereType<MoveCommitted>().single;
      expect(committed.sequence, 2);
      expect(committed.move, same(command.move));
      expect(committed.state, same(session.currentState));
    });

    test('rejects wrong actors, illegal moves, and stale revisions', () async {
      final session = createSession();
      addTearDown(session.close);
      await session.start();
      final legal = session.legalMoves.first;
      final illegal = Move(
        id: 'illegal',
        pieceId: legal.pieceId,
        path: <BoardPosition>[legal.destination, legal.origin],
      );

      final wrongActor = await session.submit(
        moveCommand(session, commandId: 'wrong-actor', actorId: lightActor),
      );
      final illegalMove = await session.submit(
        moveCommand(session, commandId: 'illegal', move: illegal),
      );
      final stale = await session.submit(
        moveCommand(session, commandId: 'stale', expectedRevision: 1),
      );
      final unknownActor = await session.submit(
        moveCommand(session, commandId: 'unknown-actor', actorId: 'unknown'),
      );

      expect(wrongActor.rejection, CommandRejection.unauthorizedActor);
      expect(unknownActor.rejection, CommandRejection.unauthorizedActor);
      expect(illegalMove.rejection, CommandRejection.illegalMove);
      expect(stale.rejection, CommandRejection.staleRevision);
      expect(session.currentState.revision, 0);
    });

    test('deduplicates command ids without repeating side effects', () async {
      final session = createSession();
      addTearDown(session.close);
      await session.start();
      final command = moveCommand(session);

      final first = await session.submit(command);
      final duplicate = await session.submit(command);
      final collision = await session.submit(
        ResignCommand(
          commandId: command.commandId,
          actorId: lightActor,
          expectedRevision: session.currentState.revision,
        ),
      );
      final moveIdCollision = await session.submit(
        SubmitMoveCommand(
          commandId: command.commandId,
          actorId: command.actorId,
          expectedRevision: command.expectedRevision,
          move: Move(
            id: 'different-move-id',
            pieceId: command.move.pieceId,
            path: command.move.path,
            capturedPieceIds: command.move.capturedPieceIds,
          ),
        ),
      );

      expect(first.accepted, isTrue);
      expect(duplicate.accepted, isTrue);
      expect(duplicate.duplicate, isTrue);
      expect(duplicate.committedSequence, first.committedSequence);
      expect(collision.rejection, CommandRejection.invalidCommand);
      expect(moveIdCollision.rejection, CommandRejection.invalidCommand);
      expect(session.currentState.revision, 1);
    });

    test('deduplicates rejected commands', () async {
      final session = createSession();
      addTearDown(session.close);
      await session.start();
      final command = moveCommand(
        session,
        commandId: 'stale',
        expectedRevision: 1,
      );

      final first = await session.submit(command);
      final duplicate = await session.submit(command);

      expect(first.rejection, CommandRejection.staleRevision);
      expect(first.duplicate, isFalse);
      expect(duplicate.rejection, CommandRejection.staleRevision);
      expect(duplicate.duplicate, isTrue);
    });
  });

  group('administrative commands', () {
    test('allows either side to resign outside its turn', () async {
      final session = createSession();
      addTearDown(session.close);
      await session.start();
      final history = session.currentState.positionHistory;

      final receipt = await session.submit(
        ResignCommand(
          commandId: 'resign-light',
          actorId: lightActor,
          expectedRevision: 0,
        ),
      );

      expect(receipt.accepted, isTrue);
      expect(session.currentState.status, GameStatus.completed);
      expect(session.currentState.outcome?.winner, PlayerSide.dark);
      expect(
        session.currentState.outcome?.reason,
        GameOutcomeReason.resignation,
      );
      expect(session.currentState.revision, 1);
      expect(session.currentState.ply, 0);
      expect(session.currentState.positionHistory, history);

      final completed = await session.submit(
        OfferDrawCommand(
          commandId: 'completed-offer',
          actorId: darkActor,
          expectedRevision: 1,
        ),
      );
      expect(completed.rejection, CommandRejection.gameCompleted);
    });

    test('supports declining and then accepting draw offers', () async {
      final session = createSession();
      addTearDown(session.close);
      await session.start();

      final offerReceipt = await session.submit(
        OfferDrawCommand(
          commandId: 'offer-1',
          actorId: darkActor,
          expectedRevision: 0,
        ),
      );
      final declineReceipt = await session.submit(
        RespondToDrawCommand(
          commandId: 'decline-1',
          actorId: lightActor,
          expectedRevision: 0,
          offerCommandId: 'offer-1',
          accepted: false,
        ),
      );

      expect(offerReceipt.accepted, isTrue);
      expect(declineReceipt.accepted, isTrue);
      expect(session.pendingDrawOffer, isNull);
      expect(session.currentState.status, GameStatus.active);
      expect(session.currentState.revision, 0);

      await session.submit(
        OfferDrawCommand(
          commandId: 'offer-2',
          actorId: lightActor,
          expectedRevision: 0,
        ),
      );
      final acceptReceipt = await session.submit(
        RespondToDrawCommand(
          commandId: 'accept-2',
          actorId: darkActor,
          expectedRevision: 0,
          offerCommandId: 'offer-2',
          accepted: true,
        ),
      );

      expect(acceptReceipt.accepted, isTrue);
      expect(session.pendingDrawOffer, isNull);
      expect(session.currentState.status, GameStatus.completed);
      expect(session.currentState.outcome?.type, GameOutcomeType.draw);
      expect(
        session.currentState.outcome?.reason,
        GameOutcomeReason.drawAgreement,
      );
      expect(session.currentState.revision, 1);
      expect(session.currentState.ply, 0);
    });

    test('enforces draw response ownership and pending-offer policy', () async {
      final session = createSession();
      addTearDown(session.close);
      await session.start();
      await session.submit(
        OfferDrawCommand(
          commandId: 'offer',
          actorId: darkActor,
          expectedRevision: 0,
        ),
      );

      final selfResponse = await session.submit(
        RespondToDrawCommand(
          commandId: 'self-response',
          actorId: darkActor,
          expectedRevision: 0,
          offerCommandId: 'offer',
          accepted: true,
        ),
      );
      final blockedMove = await session.submit(
        moveCommand(session, commandId: 'blocked-move'),
      );

      expect(selfResponse.rejection, CommandRejection.invalidCommand);
      expect(blockedMove.rejection, CommandRejection.invalidCommand);
      expect(session.pendingDrawOffer, isNotNull);
    });

    test('starts a fresh authoritative game through a command', () async {
      final session = createSession();
      addTearDown(session.close);
      await session.start();
      await session.submit(moveCommand(session));

      final receipt = await session.submit(
        StartNewGameCommand(
          commandId: 'new-game',
          actorId: lightActor,
          expectedRevision: 1,
        ),
      );

      expect(receipt.accepted, isTrue);
      expect(session.currentState.revision, 2);
      expect(session.currentState.ply, 0);
      expect(session.currentState.activeSide, PlayerSide.dark);
      expect(session.currentState.board.pieceCount, 24);

      final delayed = await session.submit(
        SubmitMoveCommand(
          commandId: 'delayed-before-reset',
          actorId: darkActor,
          expectedRevision: 0,
          move: session.legalMoves.first,
        ),
      );
      expect(delayed.rejection, CommandRejection.staleRevision);
    });

    test('draw responses identify the offer they resolve', () async {
      final session = createSession();
      addTearDown(session.close);
      await session.start();
      await session.submit(
        OfferDrawCommand(
          commandId: 'offer-old',
          actorId: darkActor,
          expectedRevision: 0,
        ),
      );
      await session.submit(
        RespondToDrawCommand(
          commandId: 'decline-old',
          actorId: lightActor,
          expectedRevision: 0,
          offerCommandId: 'offer-old',
          accepted: false,
        ),
      );
      await session.submit(
        OfferDrawCommand(
          commandId: 'offer-current',
          actorId: lightActor,
          expectedRevision: 0,
        ),
      );

      final delayedResponse = await session.submit(
        RespondToDrawCommand(
          commandId: 'delayed-response',
          actorId: darkActor,
          expectedRevision: 0,
          offerCommandId: 'offer-old',
          accepted: true,
        ),
      );

      expect(delayedResponse.rejection, CommandRejection.invalidCommand);
      expect(session.pendingDrawOffer?.commandId, 'offer-current');
      expect(session.currentState.status, GameStatus.active);
    });
  });

  test('emits one strictly ordered update per accepted action', () async {
    final session = createSession();
    final updates = <SessionUpdate>[];
    final subscription = session.updates.listen(updates.add);
    addTearDown(() async {
      await subscription.cancel();
      await session.close();
    });
    await session.start();
    await session.submit(
      OfferDrawCommand(
        commandId: 'offer',
        actorId: darkActor,
        expectedRevision: 0,
      ),
    );
    await session.submit(
      RespondToDrawCommand(
        commandId: 'decline',
        actorId: lightActor,
        expectedRevision: 0,
        offerCommandId: 'offer',
        accepted: false,
      ),
    );
    await session.submit(moveCommand(session));
    await pumpEventQueue();

    expect(updates.map((update) => update.sequence), <int>[1, 2, 3, 4]);
    expect(updates[0], isA<ConnectionChanged>());
    expect(updates[1], isA<DrawOffered>());
    expect(updates[2], isA<DrawOfferResolved>());
    expect(updates[3], isA<MoveCommitted>());
  });
}
