import 'package:checkers_engine/checkers_engine.dart';

enum SessionConnectionState {
  idle,
  connecting,
  connected,
  reconnecting,
  disconnected,
  closed,
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
