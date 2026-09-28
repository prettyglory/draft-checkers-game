import 'package:checkers_engine/checkers_engine.dart';

enum SessionConnectionState {
  idle,
  connecting,
  connected,
  reconnecting,
  disconnected,
  closed,
}

final class DrawOffer {
  DrawOffer({
    required this.commandId,
    required this.actorId,
    required this.side,
    required this.offeredAtRevision,
  }) {
    if (commandId.trim().isEmpty || actorId.trim().isEmpty) {
      throw ArgumentError('Command and actor ids cannot be empty.');
    }
    if (offeredAtRevision < 0) {
      throw ArgumentError.value(
        offeredAtRevision,
        'offeredAtRevision',
        'Offered revision cannot be negative.',
      );
    }
  }

  final String commandId;
  final String actorId;
  final PlayerSide side;
  final int offeredAtRevision;
}

sealed class SessionUpdate {
  SessionUpdate({
    required this.sessionId,
    required this.sequence,
    required this.occurredAt,
  }) {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError.value(
        sessionId,
        'sessionId',
        'Session id cannot be empty.',
      );
    }
    if (sequence < 0) {
      throw ArgumentError.value(
        sequence,
        'sequence',
        'Sequence cannot be negative.',
      );
    }
  }

  final String sessionId;
  final int sequence;
  final DateTime occurredAt;
}

final class StateReplaced extends SessionUpdate {
  StateReplaced({
    required super.sessionId,
    required super.sequence,
    required super.occurredAt,
    required this.state,
  });

  final GameState state;
}

final class MoveCommitted extends SessionUpdate {
  MoveCommitted({
    required super.sessionId,
    required super.sequence,
    required super.occurredAt,
    required this.move,
    required this.state,
  });

  final Move move;
  final GameState state;
}

final class ConnectionChanged extends SessionUpdate {
  ConnectionChanged({
    required super.sessionId,
    required super.sequence,
    required super.occurredAt,
    required this.connectionState,
  });

  final SessionConnectionState connectionState;
}

final class DrawOffered extends SessionUpdate {
  DrawOffered({
    required super.sessionId,
    required super.sequence,
    required super.occurredAt,
    required this.offer,
  });

  final DrawOffer offer;
}

final class DrawOfferResolved extends SessionUpdate {
  DrawOfferResolved({
    required super.sessionId,
    required super.sequence,
    required super.occurredAt,
    required this.offer,
    required this.accepted,
    required this.state,
  });

  final DrawOffer offer;
  final bool accepted;
  final GameState state;
}
