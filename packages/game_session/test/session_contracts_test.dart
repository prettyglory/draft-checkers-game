import 'package:game_session/game_session.dart';
import 'package:test/test.dart';

void main() {
  group('TransportEnvelope', () {
    test('copies payload and carries replay metadata', () {
      final source = <String, Object?>{'revision': 7};
      final envelope = TransportEnvelope(
        messageId: 'message-1',
        sessionId: 'session-1',
        senderId: 'player-1',
        protocolVersion: 1,
        sequence: 8,
        kind: TransportEnvelopeKind.command,
        payload: source,
        acknowledgesSequence: 6,
        stateHash: 'state-hash',
      );
      source['revision'] = 99;

      expect(envelope.payload['revision'], 7);
      expect(envelope.acknowledgesSequence, 6);
      expect(() => envelope.payload['revision'] = 10, throwsUnsupportedError);
    });

    test('rejects invalid protocol and sequence values', () {
      expect(
        () => TransportEnvelope(
          messageId: 'message-1',
          sessionId: 'session-1',
          senderId: 'player-1',
          protocolVersion: 0,
          sequence: -1,
          kind: TransportEnvelopeKind.command,
          payload: const <String, Object?>{},
        ),
        throwsArgumentError,
      );
    });
  });

  group('GameCommand', () {
    test('requires an expected non-negative state revision', () {
      expect(
        () => ResignCommand(
          commandId: 'command-1',
          actorId: 'player-1',
          expectedRevision: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('CommandReceipt', () {
    test('represents idempotent acceptance explicitly', () {
      const receipt = CommandReceipt.accepted(
        commandId: 'command-1',
        committedSequence: 12,
        duplicate: true,
      );

      expect(receipt.accepted, isTrue);
      expect(receipt.duplicate, isTrue);
      expect(receipt.committedSequence, 12);
      expect(receipt.rejection, isNull);
    });
  });
}
