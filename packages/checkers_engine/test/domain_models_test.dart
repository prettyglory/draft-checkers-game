import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  group('BoardPosition', () {
    test('uses value equality and board bounds', () {
      final first = BoardPosition(row: 3, column: 5);
      final same = BoardPosition(row: 3, column: 5);

      expect(first, same);
      expect(first.isInside(8), isTrue);
      expect(first.isInside(4), isFalse);
    });

    test('rejects negative coordinates in every build mode', () {
      expect(() => BoardPosition(row: -1, column: 0), throwsRangeError);
    });
  });

  group('Move', () {
    test('retains a complete immutable capture path', () {
      final sourcePath = <BoardPosition>[
        BoardPosition(row: 5, column: 0),
        BoardPosition(row: 3, column: 2),
        BoardPosition(row: 1, column: 4),
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
        () => move.path.add(BoardPosition(row: 0, column: 5)),
        throwsUnsupportedError,
      );
    });

    test('rejects an incomplete path', () {
      expect(
        () => Move(
          id: 'move-1',
          pieceId: 'light-1',
          path: <BoardPosition>[BoardPosition(row: 1, column: 2)],
        ),
        throwsArgumentError,
      );
    });

    test('rejects capture paths whose landing count does not match', () {
      expect(
        () => Move(
          id: 'move-1',
          pieceId: 'light-1',
          path: <BoardPosition>[
            BoardPosition(row: 5, column: 0),
            BoardPosition(row: 3, column: 2),
            BoardPosition(row: 1, column: 4),
          ],
          capturedPieceIds: const <String>['dark-1'],
        ),
        throwsArgumentError,
      );
    });
  });

  group('GameState', () {
    test('rejects two pieces on one square', () {
      final square = BoardPosition(row: 1, column: 2);
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
        status: GameStatus.completed,
        outcome: const GameOutcome.win(
          winner: PlayerSide.dark,
          reason: GameOutcomeReason.noPieces,
        ),
      );

      expect(state.outcome?.winner, PlayerSide.dark);
      expect(state.positionHash, hasLength(64));
      expect(
        () => state.positionHistory.add(state.positionHash),
        throwsUnsupportedError,
      );
      expect(() => state.ruleCounters['counter'] = 1, throwsUnsupportedError);
    });
  });

  group('Board', () {
    final light = Piece(
      id: 'light-1',
      side: PlayerSide.light,
      rank: PieceRank.man,
      position: BoardPosition(row: 5, column: 0),
    );
    final dark = Piece(
      id: 'dark-1',
      side: PlayerSide.dark,
      rank: PieceRank.man,
      position: BoardPosition(row: 2, column: 3),
    );

    test('indexes immutable piece placement', () {
      final source = <Piece>[light, dark];
      final board = Board(size: 8, pieces: source);
      source.clear();

      expect(board.pieceCount, 2);
      expect(board.pieceAt(BoardPosition(row: 5, column: 0)), light);
      expect(board.piecesFor(PlayerSide.dark), <Piece>[dark]);
      expect(() => board.pieces.clear(), throwsUnsupportedError);
    });

    test('materializes a single-pass piece source exactly once', () {
      var wasRead = false;
      Iterable<Piece> pieces() sync* {
        if (wasRead) {
          return;
        }
        wasRead = true;
        yield light;
        yield dark;
      }

      final board = Board(size: 8, pieces: pieces());

      expect(board.pieceCount, 2);
      expect(board.pieceAt(light.position), light);
      expect(board.pieceAt(dark.position), dark);
    });

    test('returns new boards for move, capture, and promotion operations', () {
      final original = Board(size: 8, pieces: <Piece>[light, dark]);
      final moved = original.movePiece(
        pieceId: light.id,
        to: BoardPosition(row: 4, column: 1),
      );
      final captured = moved.removePieces(<String>[dark.id]);
      final promoted = captured.promotePiece(light.id);

      expect(original.pieceAt(light.position), light);
      expect(moved.pieceAt(BoardPosition(row: 4, column: 1))?.id, light.id);
      expect(captured.pieceById(dark.id), isNull);
      expect(promoted.pieceById(light.id)?.rank, PieceRank.king);
    });

    test('preserves piece invariants for every empty board destination', () {
      final original = Board(size: 8, pieces: <Piece>[light, dark]);

      for (var row = 0; row < original.size; row += 1) {
        for (var column = 0; column < original.size; column += 1) {
          final destination = BoardPosition(row: row, column: column);
          if (!original.isEmptyAt(destination)) {
            continue;
          }

          final moved = original.movePiece(pieceId: light.id, to: destination);
          final movedPiece = moved.pieceById(light.id);

          expect(moved.pieceCount, original.pieceCount);
          expect(movedPiece?.id, light.id);
          expect(movedPiece?.side, light.side);
          expect(movedPiece?.rank, light.rank);
          expect(movedPiece?.position, destination);
          expect(moved.pieceById(dark.id), dark);
          expect(original.pieceById(light.id), light);
        }
      }
    });

    test('atomically applies a validated capture and promotion', () {
      final original = Board(size: 8, pieces: <Piece>[light, dark]);
      final move = Move(
        id: 'capture-1',
        pieceId: light.id,
        path: <BoardPosition>[light.position, BoardPosition(row: 1, column: 4)],
        capturedPieceIds: <String>[dark.id],
      );

      final result = original.applyMove(move, promote: true);

      expect(result.pieceById(dark.id), isNull);
      expect(result.pieceById(light.id)?.position, move.destination);
      expect(result.pieceById(light.id)?.rank, PieceRank.king);
      expect(original.pieceById(dark.id), dark);
      expect(original.pieceById(light.id), light);
    });

    test('rejects stale origins and friendly captures', () {
      final friend = Piece(
        id: 'light-2',
        side: PlayerSide.light,
        rank: PieceRank.man,
        position: BoardPosition(row: 3, column: 2),
      );
      final board = Board(size: 8, pieces: <Piece>[light, friend]);
      final staleMove = Move(
        id: 'stale',
        pieceId: light.id,
        path: <BoardPosition>[
          BoardPosition(row: 4, column: 1),
          BoardPosition(row: 2, column: 3),
        ],
      );
      final friendlyCapture = Move(
        id: 'friendly',
        pieceId: light.id,
        path: <BoardPosition>[light.position, BoardPosition(row: 1, column: 4)],
        capturedPieceIds: <String>[friend.id],
      );

      expect(() => board.applyMove(staleMove), throwsStateError);
      expect(() => board.applyMove(friendlyCapture), throwsStateError);
    });

    test('rejects collisions and missing piece operations', () {
      final board = Board(size: 8, pieces: <Piece>[light, dark]);

      expect(
        () => board.movePiece(pieceId: light.id, to: dark.position),
        throwsStateError,
      );
      expect(() => board.removePieces(<String>['missing']), throwsStateError);
      expect(
        () => board.replacePiece(
          Piece(
            id: light.id,
            side: PlayerSide.dark,
            rank: light.rank,
            position: light.position,
          ),
        ),
        throwsStateError,
      );
    });
  });
}
