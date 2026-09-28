import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'board_position.dart';
import 'game_state.dart';
import 'piece.dart';

/// Versioned, canonical JSON serialization for authoritative game snapshots.
final class GameStateCodec {
  const GameStateCodec();

  static const int schemaVersion = 1;

  String encode(GameState state) => jsonEncode(toJson(state));

  GameState decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Game state is not valid JSON: ${error.message}');
    }
    return fromJson(_asObjectMap(decoded, 'game state'));
  }

  Map<String, Object?> toJson(GameState state) {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'rulesetId': state.rulesetId,
      'boardSize': state.boardSize,
      'pieces': <Object?>[
        for (final piece in state.pieces)
          <String, Object?>{
            'id': piece.id,
            'side': piece.side.name,
            'rank': piece.rank.name,
            'row': piece.position.row,
            'column': piece.position.column,
          },
      ],
      'activeSide': state.activeSide.name,
      'ply': state.ply,
      'revision': state.revision,
      'positionHash': state.positionHash,
      'status': state.status.name,
      'outcome': switch (state.outcome) {
        null => null,
        final outcome => <String, Object?>{
          'type': outcome.type.name,
          'reason': outcome.reason.name,
          'winner': outcome.winner?.name,
        },
      },
    };
  }

  GameState fromJson(Map<String, Object?> json) {
    try {
      return _fromJson(json);
    } on FormatException {
      rethrow;
    } on ArgumentError catch (error) {
      throw FormatException('Invalid game state: $error');
    }
  }

  GameState _fromJson(Map<String, Object?> json) {
    final version = _asInt(json['schemaVersion'], 'schemaVersion');
    if (version != schemaVersion) {
      throw FormatException(
        'Unsupported game-state schema version $version; expected '
        '$schemaVersion.',
      );
    }

    final piecesJson = _asList(json['pieces'], 'pieces');
    final pieces = <Piece>[
      for (var index = 0; index < piecesJson.length; index += 1)
        _pieceFromJson(
          _asObjectMap(piecesJson[index], 'pieces[$index]'),
          index,
        ),
    ];
    final outcomeJson = json['outcome'];

    return GameState(
      rulesetId: _asString(json['rulesetId'], 'rulesetId'),
      boardSize: _asInt(json['boardSize'], 'boardSize'),
      pieces: pieces,
      activeSide: _enumByName(
        PlayerSide.values,
        _asString(json['activeSide'], 'activeSide'),
        'activeSide',
      ),
      ply: _asInt(json['ply'], 'ply'),
      revision: _asInt(json['revision'], 'revision'),
      positionHash: _asString(json['positionHash'], 'positionHash'),
      status: _enumByName(
        GameStatus.values,
        _asString(json['status'], 'status'),
        'status',
      ),
      outcome: outcomeJson == null
          ? null
          : _outcomeFromJson(_asObjectMap(outcomeJson, 'outcome')),
    );
  }

  /// Hashes the full canonical snapshot, including identities and counters.
  String snapshotHash(GameState state) {
    return sha256.convert(utf8.encode(encode(state))).toString();
  }

  static Piece _pieceFromJson(Map<String, Object?> json, int index) {
    return Piece(
      id: _asString(json['id'], 'pieces[$index].id'),
      side: _enumByName(
        PlayerSide.values,
        _asString(json['side'], 'pieces[$index].side'),
        'pieces[$index].side',
      ),
      rank: _enumByName(
        PieceRank.values,
        _asString(json['rank'], 'pieces[$index].rank'),
        'pieces[$index].rank',
      ),
      position: BoardPosition(
        row: _asInt(json['row'], 'pieces[$index].row'),
        column: _asInt(json['column'], 'pieces[$index].column'),
      ),
    );
  }

  static GameOutcome _outcomeFromJson(Map<String, Object?> json) {
    final type = _enumByName(
      GameOutcomeType.values,
      _asString(json['type'], 'outcome.type'),
      'outcome.type',
    );
    final reason = _enumByName(
      GameOutcomeReason.values,
      _asString(json['reason'], 'outcome.reason'),
      'outcome.reason',
    );
    final winnerValue = json['winner'];

    return switch (type) {
      GameOutcomeType.win => GameOutcome.win(
        winner: _enumByName(
          PlayerSide.values,
          _asString(winnerValue, 'outcome.winner'),
          'outcome.winner',
        ),
        reason: reason,
      ),
      GameOutcomeType.draw => _drawOutcome(reason, winnerValue),
    };
  }

  static GameOutcome _drawOutcome(
    GameOutcomeReason reason,
    Object? winnerValue,
  ) {
    if (winnerValue != null) {
      throw const FormatException('A drawn game cannot have a winner.');
    }
    return GameOutcome.draw(reason: reason);
  }

  static Map<String, Object?> _asObjectMap(Object? value, String field) {
    if (value is! Map<Object?, Object?>) {
      throw FormatException('$field must be a JSON object.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw FormatException('$field contains a non-string key.');
      }
      result[key] = entry.value;
    }
    return result;
  }

  static List<Object?> _asList(Object? value, String field) {
    if (value is! List<Object?>) {
      throw FormatException('$field must be a JSON array.');
    }
    return value;
  }

  static String _asString(Object? value, String field) {
    if (value is! String) {
      throw FormatException('$field must be a string.');
    }
    return value;
  }

  static int _asInt(Object? value, String field) {
    if (value is! int) {
      throw FormatException('$field must be an integer.');
    }
    return value;
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String name,
    String field,
  ) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    throw FormatException('$field has unknown value "$name".');
  }
}
