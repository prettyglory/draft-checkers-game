import 'dart:convert';

import 'board_position.dart';
import 'move.dart';

/// Canonical JSON serialization for a complete move intent.
final class MoveCodec {
  const MoveCodec();

  String encode(Move move) => jsonEncode(toJson(move));

  Move decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Move is not valid JSON: ${error.message}');
    }
    return fromJson(_asObjectMap(decoded, 'move'));
  }

  Map<String, Object?> toJson(Move move) {
    return <String, Object?>{
      'id': move.id,
      'pieceId': move.pieceId,
      'path': <Object?>[
        for (final position in move.path)
          <String, Object?>{'row': position.row, 'column': position.column},
      ],
      'capturedPieceIds': <Object?>[...move.capturedPieceIds],
    };
  }

  Move fromJson(Map<String, Object?> json) {
    try {
      final pathJson = _asList(json['path'], 'path');
      final capturedIdsJson = _asList(
        json['capturedPieceIds'],
        'capturedPieceIds',
      );
      return Move(
        id: _asString(json['id'], 'id'),
        pieceId: _asString(json['pieceId'], 'pieceId'),
        path: <BoardPosition>[
          for (var index = 0; index < pathJson.length; index += 1)
            _positionFromJson(
              _asObjectMap(pathJson[index], 'path[$index]'),
              index,
            ),
        ],
        capturedPieceIds: <String>[
          for (var index = 0; index < capturedIdsJson.length; index += 1)
            _asString(capturedIdsJson[index], 'capturedPieceIds[$index]'),
        ],
      );
    } on FormatException {
      rethrow;
    } on ArgumentError catch (error) {
      throw FormatException('Invalid move: $error');
    }
  }

  static BoardPosition _positionFromJson(Map<String, Object?> json, int index) {
    return BoardPosition(
      row: _asInt(json['row'], 'path[$index].row'),
      column: _asInt(json['column'], 'path[$index].column'),
    );
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
}
