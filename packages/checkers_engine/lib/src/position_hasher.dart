import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'piece.dart';

/// Produces the canonical hash used for repetition and position comparison.
abstract final class PositionHasher {
  static String compute({
    required String rulesetId,
    required int boardSize,
    required Iterable<Piece> pieces,
    required PlayerSide activeSide,
  }) {
    final orderedPieces = pieces.toList()
      ..sort((first, second) {
        final rowComparison = first.position.row.compareTo(second.position.row);
        if (rowComparison != 0) {
          return rowComparison;
        }
        final columnComparison = first.position.column.compareTo(
          second.position.column,
        );
        if (columnComparison != 0) {
          return columnComparison;
        }
        final sideComparison = first.side.index.compareTo(second.side.index);
        if (sideComparison != 0) {
          return sideComparison;
        }
        return first.rank.index.compareTo(second.rank.index);
      });
    final canonicalPosition = <Object?>[
      1,
      rulesetId,
      boardSize,
      activeSide.name,
      for (final piece in orderedPieces)
        <Object?>[
          piece.position.row,
          piece.position.column,
          piece.side.name,
          piece.rank.name,
        ],
    ];

    return sha256
        .convert(utf8.encode(jsonEncode(canonicalPosition)))
        .toString();
  }
}
