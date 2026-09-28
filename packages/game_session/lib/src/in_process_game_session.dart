import 'dart:async';
import 'dart:collection';

import 'package:checkers_engine/checkers_engine.dart';

import 'game_command.dart';
import 'game_session_contract.dart';
import 'session_update.dart';

final class InProcessGameSession implements GameSession {
  InProcessGameSession({
    required this.id,
    required RulesEngine rulesEngine,
    required GameState initialState,
    required Map<String, PlayerSide> actorSides,
    DateTime Function()? clock,
  }) : _rulesEngine = rulesEngine,
       _state = initialState,
       _actorSides = UnmodifiableMapView<String, PlayerSide>(
         Map<String, PlayerSide>.of(actorSides),
       ),
       _clock = clock ?? DateTime.now {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Session id cannot be empty.');
    }
    if (initialState.rulesetId != rulesEngine.descriptor.id ||
        initialState.boardSize != rulesEngine.descriptor.boardSize) {
      throw ArgumentError('Initial state does not match the rules engine.');
    }
    if (actorSides.length != PlayerSide.values.length ||
        actorSides.keys.any((actorId) => actorId.trim().isEmpty) ||
        actorSides.values.toSet().length != PlayerSide.values.length) {
      throw ArgumentError(
        'Actor assignments require one non-empty actor id per side.',
      );
    }
  }

  @override
  final String id;

  final RulesEngine _rulesEngine;
  final Map<String, PlayerSide> _actorSides;
  final DateTime Function() _clock;
  final StreamController<SessionUpdate> _updates =
      StreamController<SessionUpdate>.broadcast();
  final Map<String, _ProcessedCommand> _processed =
      <String, _ProcessedCommand>{};

  GameState _state;
  DrawOffer? _pendingDrawOffer;
  SessionConnectionState _connectionState = SessionConnectionState.idle;
  int _sequence = 0;

  @override
  SessionAuthority get authority => SessionAuthority.localDevice;

  @override
  GameState get currentState => _state;

  @override
  List<Move> get legalMoves => List<Move>.unmodifiable(
    _state.status == GameStatus.completed
        ? const <Move>[]
        : _rulesEngine.legalMoves(_state),
  );

  @override
  DrawOffer? get pendingDrawOffer => _pendingDrawOffer;

  @override
  SessionConnectionState get connectionState => _connectionState;

  @override
  Stream<SessionUpdate> get updates => _updates.stream;

  @override
  Future<void> start() {
    if (_connectionState == SessionConnectionState.closed) {
      throw StateError('A closed session cannot be started.');
    }
    if (_connectionState == SessionConnectionState.connected) {
      return Future<void>.value();
    }
    _connectionState = SessionConnectionState.connected;
    _emitConnectionChanged();
    return Future<void>.value();
  }

  @override
  Future<CommandReceipt> submit(GameCommand command) {
    final fingerprint = _fingerprint(command);
    final processed = _processed[command.commandId];
    if (processed != null) {
      if (processed.fingerprint != fingerprint) {
        return Future<CommandReceipt>.value(
          CommandReceipt.rejected(
            commandId: command.commandId,
            rejection: CommandRejection.invalidCommand,
          ),
        );
      }
      return Future<CommandReceipt>.value(_asDuplicate(processed.receipt));
    }

    final receipt = _process(command);
    _processed[command.commandId] = _ProcessedCommand(
      fingerprint: fingerprint,
      receipt: receipt,
    );
    return Future<CommandReceipt>.value(receipt);
  }

  @override
  Future<void> reconnect() => start();

  @override
  Future<void> close() async {
    if (_connectionState == SessionConnectionState.closed) {
      return;
    }
    _pendingDrawOffer = null;
    _connectionState = SessionConnectionState.closed;
    _emitConnectionChanged();
    await _updates.close();
  }

  CommandReceipt _process(GameCommand command) {
    if (_connectionState != SessionConnectionState.connected) {
      return _reject(command, CommandRejection.sessionUnavailable);
    }

    final actorSide = _actorSides[command.actorId];
    if (actorSide == null) {
      return _reject(command, CommandRejection.unauthorizedActor);
    }
    if (command.expectedRevision != _state.revision) {
      return _reject(command, CommandRejection.staleRevision);
    }

    if (command is StartNewGameCommand) {
      _pendingDrawOffer = null;
      _state = _createNewGameState();
      final sequence = _nextSequence();
      _updates.add(
        StateReplaced(
          sessionId: id,
          sequence: sequence,
          occurredAt: _clock(),
          state: _state,
        ),
      );
      return CommandReceipt.accepted(
        commandId: command.commandId,
        committedSequence: sequence,
      );
    }

    if (_state.status == GameStatus.completed) {
      return _reject(command, CommandRejection.gameCompleted);
    }

    return switch (command) {
      SubmitMoveCommand() => _submitMove(command, actorSide),
      ResignCommand() => _resign(command, actorSide),
      OfferDrawCommand() => _offerDraw(command, actorSide),
      RespondToDrawCommand() => _respondToDraw(command, actorSide),
      StartNewGameCommand() => throw StateError('Handled above.'),
    };
  }

  CommandReceipt _submitMove(SubmitMoveCommand command, PlayerSide actorSide) {
    if (_pendingDrawOffer != null) {
      return _reject(command, CommandRejection.invalidCommand);
    }
    if (actorSide != _state.activeSide) {
      return _reject(command, CommandRejection.unauthorizedActor);
    }
    final validation = _rulesEngine.validateMove(_state, command.move);
    if (!validation.isValid) {
      return _reject(command, CommandRejection.illegalMove);
    }

    _state = _rulesEngine.applyMove(_state, command.move);
    final sequence = _nextSequence();
    _updates.add(
      MoveCommitted(
        sessionId: id,
        sequence: sequence,
        occurredAt: _clock(),
        move: command.move,
        state: _state,
      ),
    );
    return CommandReceipt.accepted(
      commandId: command.commandId,
      committedSequence: sequence,
    );
  }

  CommandReceipt _resign(ResignCommand command, PlayerSide actorSide) {
    _pendingDrawOffer = null;
    final winner = actorSide == PlayerSide.dark
        ? PlayerSide.light
        : PlayerSide.dark;
    _state = _completeGame(
      GameOutcome.win(winner: winner, reason: GameOutcomeReason.resignation),
    );
    final sequence = _nextSequence();
    _updates.add(
      StateReplaced(
        sessionId: id,
        sequence: sequence,
        occurredAt: _clock(),
        state: _state,
      ),
    );
    return CommandReceipt.accepted(
      commandId: command.commandId,
      committedSequence: sequence,
    );
  }

  CommandReceipt _offerDraw(OfferDrawCommand command, PlayerSide actorSide) {
    if (_pendingDrawOffer != null) {
      return _reject(command, CommandRejection.invalidCommand);
    }
    final offer = DrawOffer(
      commandId: command.commandId,
      actorId: command.actorId,
      side: actorSide,
      offeredAtRevision: _state.revision,
    );
    _pendingDrawOffer = offer;
    final sequence = _nextSequence();
    _updates.add(
      DrawOffered(
        sessionId: id,
        sequence: sequence,
        occurredAt: _clock(),
        offer: offer,
      ),
    );
    return CommandReceipt.accepted(
      commandId: command.commandId,
      committedSequence: sequence,
    );
  }

  CommandReceipt _respondToDraw(
    RespondToDrawCommand command,
    PlayerSide actorSide,
  ) {
    final offer = _pendingDrawOffer;
    if (offer == null ||
        command.offerCommandId != offer.commandId ||
        actorSide == offer.side) {
      return _reject(command, CommandRejection.invalidCommand);
    }
    _pendingDrawOffer = null;
    if (command.accepted) {
      _state = _completeGame(
        const GameOutcome.draw(reason: GameOutcomeReason.drawAgreement),
      );
    }
    final sequence = _nextSequence();
    _updates.add(
      DrawOfferResolved(
        sessionId: id,
        sequence: sequence,
        occurredAt: _clock(),
        offer: offer,
        accepted: command.accepted,
        state: _state,
      ),
    );
    return CommandReceipt.accepted(
      commandId: command.commandId,
      committedSequence: sequence,
    );
  }

  GameState _completeGame(GameOutcome outcome) {
    return GameState(
      rulesetId: _state.rulesetId,
      boardSize: _state.boardSize,
      pieces: _state.pieces,
      activeSide: _state.activeSide,
      ply: _state.ply,
      revision: _state.revision + 1,
      previousPositionHashes: _state.positionHistory.take(
        _state.positionHistory.length - 1,
      ),
      ruleCounters: _state.ruleCounters,
      status: GameStatus.completed,
      outcome: outcome,
    );
  }

  GameState _createNewGameState() {
    final initial = _rulesEngine.createInitialState();
    return GameState(
      rulesetId: initial.rulesetId,
      boardSize: initial.boardSize,
      pieces: initial.pieces,
      activeSide: initial.activeSide,
      ply: initial.ply,
      revision: _state.revision + 1,
      ruleCounters: initial.ruleCounters,
    );
  }

  CommandReceipt _reject(GameCommand command, CommandRejection rejection) {
    return CommandReceipt.rejected(
      commandId: command.commandId,
      rejection: rejection,
    );
  }

  int _nextSequence() {
    _sequence += 1;
    return _sequence;
  }

  void _emitConnectionChanged() {
    _updates.add(
      ConnectionChanged(
        sessionId: id,
        sequence: _nextSequence(),
        occurredAt: _clock(),
        connectionState: _connectionState,
      ),
    );
  }

  static CommandReceipt _asDuplicate(CommandReceipt receipt) {
    if (receipt.accepted) {
      return CommandReceipt.accepted(
        commandId: receipt.commandId,
        committedSequence: receipt.committedSequence!,
        duplicate: true,
      );
    }
    return CommandReceipt.rejected(
      commandId: receipt.commandId,
      rejection: receipt.rejection!,
      duplicate: true,
    );
  }

  static String _fingerprint(GameCommand command) {
    final base =
        '${command.runtimeType}|${command.actorId}|'
        '${command.expectedRevision}';
    return switch (command) {
      SubmitMoveCommand(:final move) =>
        '$base|${move.id}|${move.pieceId}|'
            '${move.path.map((position) => '${position.row},${position.column}').join(';')}|'
            '${move.capturedPieceIds.join(';')}',
      RespondToDrawCommand(:final offerCommandId, :final accepted) =>
        '$base|$offerCommandId|$accepted',
      _ => base,
    };
  }
}

final class _ProcessedCommand {
  const _ProcessedCommand({required this.fingerprint, required this.receipt});

  final String fingerprint;
  final CommandReceipt receipt;
}
