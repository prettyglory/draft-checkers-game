import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  group('BoardPosition', () {
    test('uses value equality and board bounds', () {
      const first = BoardPosition(row: 3, column: 5);
      const same = BoardPosition(row: 3, column: 5);

      expect(first, same);
      expect(first.isInside(8), isTrue);
      expect(first.isInside(4), isFalse);
    });
  });

  group('Move', () {
    test('retains a complete immutable capture path', () {
      final sourcePath = <BoardPosition>[
        const BoardPosition(row: 5, column: 0),
        const BoardPosition(row: 3, column: 2),
        const BoardPosition(row: 1, column: 4),
      ];
      final move = Move(
        id: 'move-1',
        pieceId: 'light-1',
        path: sourcePath,
        capturedPieceIds: const <String>['dark-1', 'dark-2'],
      );
      sourcePath.clear();

      expect(move.path, hasLength(3));
      expect(move.captureCount, 2);
      expect(
        () => move.path.add(const BoardPosition(row: 0, column: 5)),
        throwsUnsupportedError,
      );
    });

    test('rejects an incomplete path', () {
      expect(
        () => Move(
          id: 'move-1',
          pieceId: 'light-1',
          path: const <BoardPosition>[BoardPosition(row: 1, column: 2)],
        ),
        throwsArgumentError,
      );
    });
  });

  group('GameState', () {
    test('rejects two pieces on one square', () {
      const square = BoardPosition(row: 1, column: 2);
      expect(
        () => GameState(
          rulesetId: 'american',
          boardSize: 8,
          pieces: <Piece>[
            Piece(
              id: 'light-1',
              side: PlayerSide.light,
              rank: PieceRank.man,
              position: square,
            ),
            Piece(
              id: 'dark-1',
              side: PlayerSide.dark,
              rank: PieceRank.man,
              position: square,
            ),
          ],
          activeSide: PlayerSide.light,
          ply: 0,
          revision: 0,
          positionHash: 'hash',
        ),
        throwsArgumentError,
      );
    });

    test('requires an outcome exactly when completed', () {
      expect(
        () => GameState(
          rulesetId: 'american',
          boardSize: 8,
          pieces: const <Piece>[],
          activeSide: PlayerSide.light,
          ply: 40,
          revision: 40,
          positionHash: 'hash',
          status: GameStatus.completed,
        ),
        throwsArgumentError,
      );

      final state = GameState(
        rulesetId: 'american',
        boardSize: 8,
        pieces: const <Piece>[],
        activeSide: PlayerSide.light,
        ply: 40,
        revision: 40,
        positionHash: 'hash',
        status: GameStatus.completed,
        outcome: const GameOutcome.win(
          winner: PlayerSide.dark,
          reason: GameOutcomeReason.noPieces,
        ),
      );

      expect(state.outcome?.winner, PlayerSide.dark);
    });
  });
}
