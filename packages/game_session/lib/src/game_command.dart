import 'package:checkers_engine/checkers_engine.dart';

sealed class GameCommand {
  GameCommand({
    required this.commandId,
    required this.actorId,
    required this.expectedRevision,
  }) {
    if (commandId.trim().isEmpty || actorId.trim().isEmpty) {
      throw ArgumentError('Command and actor ids cannot be empty.');
    }
    if (expectedRevision < 0) {
      throw ArgumentError.value(
        expectedRevision,
        'expectedRevision',
        'Expected revision cannot be negative.',
      );
    }
  }

  final String commandId;
  final String actorId;
  final int expectedRevision;
}

final class SubmitMoveCommand extends GameCommand {
  SubmitMoveCommand({
    required super.commandId,
    required super.actorId,
    required super.expectedRevision,
    required this.move,
  });

  final Move move;
}

final class ResignCommand extends GameCommand {
  ResignCommand({
    required super.commandId,
    required super.actorId,
    required super.expectedRevision,
  });
}

final class OfferDrawCommand extends GameCommand {
  OfferDrawCommand({
    required super.commandId,
    required super.actorId,
    required super.expectedRevision,
  });
}

final class RespondToDrawCommand extends GameCommand {
  RespondToDrawCommand({
    required super.commandId,
    required super.actorId,
    required super.expectedRevision,
    required this.accepted,
  });

  final bool accepted;
}
