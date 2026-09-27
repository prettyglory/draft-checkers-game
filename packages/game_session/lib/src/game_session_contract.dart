import 'package:checkers_engine/checkers_engine.dart';

import 'game_command.dart';
import 'session_update.dart';

enum SessionAuthority {
  /// The current process validates and applies all commands.
  localDevice,

  /// One nearby device validates commands for both peers.
  nearbyHost,

  /// The authenticated backend validates commands for both clients.
  onlineServer,
}

enum CommandRejection {
  unauthenticated,
  unauthorizedActor,
  staleRevision,
  invalidCommand,
  illegalMove,
  rateLimited,
  sessionUnavailable,
  gameCompleted,
}

final class CommandReceipt {
  const CommandReceipt._({
    required this.commandId,
    required this.accepted,
    required this.duplicate,
    this.committedSequence,
    this.rejection,
  });

  const CommandReceipt.accepted({
    required String commandId,
    required int committedSequence,
    bool duplicate = false,
  }) : this._(
         commandId: commandId,
         accepted: true,
         duplicate: duplicate,
         committedSequence: committedSequence,
       );

  const CommandReceipt.rejected({
    required String commandId,
    required CommandRejection rejection,
  }) : this._(
         commandId: commandId,
         accepted: false,
         duplicate: false,
         rejection: rejection,
       );

  final String commandId;
  final bool accepted;
  final bool duplicate;
  final int? committedSequence;
  final CommandRejection? rejection;
}

/// The sole session API consumed by game presentation code.
abstract interface class GameSession {
  String get id;
  SessionAuthority get authority;
  GameState get currentState;
  SessionConnectionState get connectionState;
  Stream<SessionUpdate> get updates;

  Future<void> start();
  Future<CommandReceipt> submit(GameCommand command);
  Future<void> reconnect();
  Future<void> close();
}
