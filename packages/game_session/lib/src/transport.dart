enum TransportEnvelopeKind { command, event, acknowledgment, snapshot, error }

enum TransportConnectionState {
  idle,
  connecting,
  connected,
  reconnecting,
  disconnected,
  closed,
}

/// Address and non-secret discovery metadata for a transport peer.
final class TransportEndpoint {
  TransportEndpoint({
    required this.peerId,
    required this.address,
    Map<String, String> metadata = const <String, String>{},
  }) : metadata = Map<String, String>.unmodifiable(metadata) {
    if (peerId.trim().isEmpty || address.trim().isEmpty) {
      throw ArgumentError('Peer id and address cannot be empty.');
    }
  }

  final String peerId;
  final String address;
  final Map<String, String> metadata;
}

/// Versioned, ordered wire unit used by every remote transport.
final class TransportEnvelope {
  TransportEnvelope({
    required this.messageId,
    required this.sessionId,
    required this.senderId,
    required this.protocolVersion,
    required this.sequence,
    required this.kind,
    required Map<String, Object?> payload,
    this.acknowledgesSequence,
    this.stateHash,
  }) : payload = Map<String, Object?>.unmodifiable(payload) {
    if (messageId.trim().isEmpty ||
        sessionId.trim().isEmpty ||
        senderId.trim().isEmpty) {
      throw ArgumentError('Envelope identifiers cannot be empty.');
    }
    if (protocolVersion < 1) {
      throw ArgumentError.value(
        protocolVersion,
        'protocolVersion',
        'Protocol version must be positive.',
      );
    }
    if (sequence < 0 ||
        (acknowledgesSequence != null && acknowledgesSequence! < 0)) {
      throw ArgumentError('Envelope sequences cannot be negative.');
    }
  }

  final String messageId;
  final String sessionId;
  final String senderId;
  final int protocolVersion;
  final int sequence;
  final TransportEnvelopeKind kind;
  final Map<String, Object?> payload;
  final int? acknowledgesSequence;
  final String? stateHash;
}

/// Byte delivery is transport-specific; ordering/replay semantics are not.
abstract interface class GameTransport {
  TransportConnectionState get connectionState;
  Stream<TransportConnectionState> get connectionStates;
  Stream<TransportEnvelope> get incoming;

  Future<void> connect(TransportEndpoint endpoint);
  Future<void> send(TransportEnvelope envelope);
  Future<void> reconnect();
  Future<void> close();
}
