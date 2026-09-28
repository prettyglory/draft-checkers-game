import 'dart:convert';

import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  const codec = GameStateCodec();

  Piece piece({
    required String id,
    required PlayerSide side,
    required PieceRank rank,
    required int row,
    required int column,
  }) {
    return Piece(
      id: id,
      side: side,
      rank: rank,
      position: BoardPosition(row: row, column: column),
    );
  }

  GameState state({
    Iterable<Piece>? pieces,
    int revision = 7,
    Iterable<String> previousPositionHashes = const <String>[],
    Map<String, int> ruleCounters = const <String, int>{},
  }) {
    return GameState(
      rulesetId: 'american',
      boardSize: 8,
      pieces:
          pieces ??
          <Piece>[
            piece(
              id: 'light-1',
              side: PlayerSide.light,
              rank: PieceRank.man,
              row: 5,
              column: 0,
            ),
            piece(
              id: 'dark-1',
              side: PlayerSide.dark,
              rank: PieceRank.king,
              row: 2,
              column: 3,
            ),
          ],
      activeSide: PlayerSide.light,
      ply: 7,
      revision: revision,
      previousPositionHashes: previousPositionHashes,
      ruleCounters: ruleCounters,
    );
  }

  group('position hash', () {
    test('is canonical across input and piece identity order', () {
      final first = state();
      final second = state(
        pieces: <Piece>[
          piece(
            id: 'renamed-dark',
            side: PlayerSide.dark,
            rank: PieceRank.king,
            row: 2,
            column: 3,
          ),
          piece(
            id: 'renamed-light',
            side: PlayerSide.light,
            rank: PieceRank.man,
            row: 5,
            column: 0,
          ),
        ],
      );

      expect(first.positionHash, second.positionHash);
      expect(first.positionHash, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('changes with position or active side', () {
      final original = state();
      final moved = state(
        pieces: <Piece>[
          piece(
            id: 'light-1',
            side: PlayerSide.light,
            rank: PieceRank.man,
            row: 4,
            column: 1,
          ),
        ],
      );
      final otherTurn = GameState(
        rulesetId: original.rulesetId,
        boardSize: original.boardSize,
        pieces: original.pieces,
        activeSide: PlayerSide.dark,
        ply: original.ply,
        revision: original.revision,
      );

      expect(moved.positionHash, isNot(original.positionHash));
      expect(otherTurn.positionHash, isNot(original.positionHash));
    });
  });

  group('GameStateCodec', () {
    test('round-trips a snapshot with canonical output', () {
      final original = state(
        previousPositionHashes: <String>[List<String>.filled(64, 'a').join()],
        ruleCounters: const <String, int>{'quietPly': 12},
      );

      final encoded = codec.encode(original);
      final decoded = codec.decode(encoded);

      expect(codec.encode(decoded), encoded);
      expect(decoded.rulesetId, original.rulesetId);
      expect(decoded.boardSize, original.boardSize);
      expect(decoded.pieces, original.pieces);
      expect(decoded.activeSide, original.activeSide);
      expect(decoded.ply, original.ply);
      expect(decoded.revision, original.revision);
      expect(decoded.positionHash, original.positionHash);
      expect(decoded.positionHistory, original.positionHistory);
      expect(decoded.ruleCounters, original.ruleCounters);
      expect(codec.snapshotHash(decoded), codec.snapshotHash(original));
    });

    test('snapshot hash includes identities and revision', () {
      final original = state();
      final newer = state(revision: original.revision + 1);
      final renamed = state(
        pieces: <Piece>[
          piece(
            id: 'different-id',
            side: PlayerSide.light,
            rank: PieceRank.man,
            row: 5,
            column: 0,
          ),
          original.pieces.firstWhere(
            (candidate) => candidate.side == PlayerSide.dark,
          ),
        ],
      );

      expect(newer.positionHash, original.positionHash);
      expect(renamed.positionHash, original.positionHash);
      expect(codec.snapshotHash(newer), isNot(codec.snapshotHash(original)));
      expect(codec.snapshotHash(renamed), isNot(codec.snapshotHash(original)));
    });

    test('rejects unsupported versions and tampered hashes', () {
      final json = codec.toJson(state());
      final unsupported = <String, Object?>{...json, 'schemaVersion': 3};
      final tampered = <String, Object?>{
        ...json,
        'positionHash': List<String>.filled(64, '0').join(),
      };

      expect(() => codec.fromJson(unsupported), throwsFormatException);
      expect(() => codec.decode(jsonEncode(tampered)), throwsFormatException);
    });

    test('normalizes malformed domain values to format errors', () {
      final json = codec.toJson(state());
      json['pieces'] = <Object?>[
        <String, Object?>{
          'id': 'light-1',
          'side': 'light',
          'rank': 'man',
          'row': -1,
          'column': 0,
        },
      ];

      expect(() => codec.fromJson(json), throwsFormatException);
    });

    test('migrates schema version 1 snapshots with default history', () {
      final original = state();
      final legacy = codec.toJson(original)
        ..['schemaVersion'] = 1
        ..remove('positionHistory')
        ..remove('ruleCounters');

      final decoded = codec.fromJson(legacy);

      expect(decoded.positionHistory, <String>[decoded.positionHash]);
      expect(decoded.ruleCounters, isEmpty);
    });

    test('round-trips a completed outcome', () {
      final completed = GameState(
        rulesetId: 'american',
        boardSize: 8,
        pieces: const <Piece>[],
        activeSide: PlayerSide.light,
        ply: 80,
        revision: 80,
        status: GameStatus.completed,
        outcome: const GameOutcome.win(
          winner: PlayerSide.dark,
          reason: GameOutcomeReason.noPieces,
        ),
      );

      final decoded = codec.decode(codec.encode(completed));

      expect(decoded.status, GameStatus.completed);
      expect(decoded.outcome?.type, GameOutcomeType.win);
      expect(decoded.outcome?.reason, GameOutcomeReason.noPieces);
      expect(decoded.outcome?.winner, PlayerSide.dark);
    });
  });
}
