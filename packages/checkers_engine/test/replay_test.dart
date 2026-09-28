import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  const moveCodec = MoveCodec();
  const replayer = GameReplayer();

  final initialState = GameState(
    rulesetId: 'test-rules',
    boardSize: 8,
    pieces: <Piece>[
      Piece(
        id: 'light-1',
        side: PlayerSide.light,
        rank: PieceRank.man,
        position: BoardPosition(row: 5, column: 0),
      ),
    ],
    activeSide: PlayerSide.light,
    ply: 0,
    revision: 0,
  );
  final legalMove = Move(
    id: 'move-1',
    pieceId: 'light-1',
    path: <BoardPosition>[
      BoardPosition(row: 5, column: 0),
      BoardPosition(row: 4, column: 1),
    ],
  );

  group('MoveCodec', () {
    test('round-trips a complete move canonically', () {
      final capture = Move(
        id: 'capture-1',
        pieceId: 'light-1',
        path: <BoardPosition>[
          BoardPosition(row: 5, column: 0),
          BoardPosition(row: 3, column: 2),
          BoardPosition(row: 1, column: 4),
        ],
        capturedPieceIds: const <String>['dark-1', 'dark-2'],
      );

      final encoded = moveCodec.encode(capture);
      final decoded = moveCodec.decode(encoded);

      expect(moveCodec.encode(decoded), encoded);
      expect(decoded.id, capture.id);
      expect(decoded.pieceId, capture.pieceId);
      expect(decoded.path, capture.path);
      expect(decoded.capturedPieceIds, capture.capturedPieceIds);
    });

    test('rejects malformed coordinates as format errors', () {
      expect(
        () => moveCodec.decode(
          '{"id":"move-1","pieceId":"light-1","path":['
          '{"row":-1,"column":0},{"row":0,"column":1}],'
          '"capturedPieceIds":[]}',
        ),
        throwsFormatException,
      );
    });
  });

  group('GameReplayer', () {
    test('returns an immutable state for every replay point', () {
      const engine = _TestRulesEngine();

      final states = replayer.replay(
        rulesEngine: engine,
        initialState: initialState,
        moves: <Move>[legalMove],
      );

      expect(states, hasLength(2));
      expect(states.last.revision, 1);
      expect(states.last.ply, 1);
      expect(states.last.activeSide, PlayerSide.dark);
      expect(
        states.last.board.pieceById('light-1')?.position,
        legalMove.destination,
      );
      expect(() => states.clear(), throwsUnsupportedError);
    });

    test('reports the index and reason for an illegal move', () {
      const engine = _TestRulesEngine();
      final illegalMove = Move(
        id: 'illegal',
        pieceId: 'light-1',
        path: <BoardPosition>[
          BoardPosition(row: 5, column: 0),
          BoardPosition(row: 3, column: 2),
        ],
      );

      expect(
        () => replayer.replay(
          rulesEngine: engine,
          initialState: initialState,
          moves: <Move>[illegalMove],
        ),
        throwsA(
          isA<GameReplayException>()
              .having((error) => error.moveIndex, 'moveIndex', 0)
              .having(
                (error) => error.rejectionCode,
                'rejectionCode',
                MoveRejectionCode.illegalMovement,
              ),
        ),
      );
    });

    test('rejects engines that violate revision invariants', () {
      const engine = _TestRulesEngine(revisionDelta: 2);

      expect(
        () => replayer.replay(
          rulesEngine: engine,
          initialState: initialState,
          moves: <Move>[legalMove],
        ),
        throwsA(
          isA<GameReplayException>().having(
            (error) => error.message,
            'message',
            contains('expected 1'),
          ),
        ),
      );
    });
  });
}

final class _TestRulesEngine implements RulesEngine {
  const _TestRulesEngine({this.revisionDelta = 1});

  final int revisionDelta;

  @override
  RulesetDescriptor get descriptor => RulesetDescriptor(
    id: 'test-rules',
    displayName: 'Test Rules',
    boardSize: 8,
    piecesPerSide: 1,
    importantDifferences: const <String>['Only one move is legal.'],
  );

  @override
  GameState createInitialState() {
    return GameState(
      rulesetId: descriptor.id,
      boardSize: descriptor.boardSize,
      pieces: <Piece>[
        Piece(
          id: 'light-1',
          side: PlayerSide.light,
          rank: PieceRank.man,
          position: BoardPosition(row: 5, column: 0),
        ),
      ],
      activeSide: PlayerSide.light,
      ply: 0,
      revision: 0,
    );
  }

  @override
  List<Move> legalMoves(GameState state) {
    if (state.activeSide != PlayerSide.light) {
      return const <Move>[];
    }
    return <Move>[
      Move(
        id: 'legal',
        pieceId: 'light-1',
        path: <BoardPosition>[
          BoardPosition(row: 5, column: 0),
          BoardPosition(row: 4, column: 1),
        ],
      ),
    ];
  }

  @override
  MoveValidation validateMove(GameState state, Move move) {
    final expected = legalMoves(state);
    if (expected.isEmpty) {
      return const MoveValidation.invalid(MoveRejectionCode.wrongTurn);
    }
    final legal = expected.single;
    if (move.pieceId != legal.pieceId ||
        move.origin != legal.origin ||
        move.destination != legal.destination ||
        move.isCapture) {
      return const MoveValidation.invalid(MoveRejectionCode.illegalMovement);
    }
    return const MoveValidation.valid();
  }

  @override
  GameState applyMove(GameState state, Move move) {
    final validation = validateMove(state, move);
    if (!validation.isValid) {
      throw StateError('Cannot apply an invalid move.');
    }
    final board = state.board.applyMove(move);
    return GameState(
      rulesetId: state.rulesetId,
      boardSize: state.boardSize,
      pieces: board.pieces,
      activeSide: PlayerSide.dark,
      ply: state.ply + 1,
      revision: state.revision + revisionDelta,
    );
  }
}
