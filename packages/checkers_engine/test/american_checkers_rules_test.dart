import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();

  Piece piece(
    String id,
    PlayerSide side,
    int row,
    int column, {
    PieceRank rank = PieceRank.man,
  }) {
    return Piece(
      id: id,
      side: side,
      rank: rank,
      position: BoardPosition(row: row, column: column),
    );
  }

  GameState state(
    Iterable<Piece> pieces, {
    PlayerSide activeSide = PlayerSide.dark,
    int ply = 0,
    int revision = 0,
    Iterable<String> previousPositionHashes = const <String>[],
    int noProgressPly = 0,
  }) {
    return GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: engine.descriptor.boardSize,
      pieces: pieces,
      activeSide: activeSide,
      ply: ply,
      revision: revision,
      previousPositionHashes: previousPositionHashes,
      ruleCounters: <String, int>{
        AmericanCheckersRulesEngine.noProgressPlyCounter: noProgressPly,
      },
    );
  }

  Move submittedMove(
    String id,
    String pieceId,
    List<BoardPosition> path, {
    List<String> captures = const <String>[],
  }) {
    return Move(
      id: id,
      pieceId: pieceId,
      path: path,
      capturedPieceIds: captures,
    );
  }

  group('WCDF initial position', () {
    test('places 12 men per side and starts with dark/Red', () {
      final initial = engine.createInitialState();

      expect(initial.activeSide, PlayerSide.dark);
      expect(initial.board.piecesFor(PlayerSide.dark), hasLength(12));
      expect(initial.board.piecesFor(PlayerSide.light), hasLength(12));
      expect(
        initial.pieces.every((candidate) => candidate.rank == PieceRank.man),
        isTrue,
      );
      expect(
        initial.pieces.every(
          (candidate) =>
              (candidate.position.row + candidate.position.column).isOdd,
        ),
        isTrue,
      );
      expect(engine.legalMoves(initial), hasLength(7));
    });

    test('rejects positions that use non-playable squares', () {
      final invalid = state(<Piece>[
        piece('dark-invalid', PlayerSide.dark, 2, 2),
        piece('light-valid', PlayerSide.light, 5, 0),
      ]);

      expect(() => engine.legalMoves(invalid), throwsArgumentError);
    });
  });

  group('WCDF movement and capture rules', () {
    test('men move forward while kings also move backward', () {
      final manState = state(<Piece>[
        piece('light-man', PlayerSide.light, 4, 3),
        piece('dark-far', PlayerSide.dark, 0, 1),
      ], activeSide: PlayerSide.light);
      final kingState = state(<Piece>[
        piece('light-king', PlayerSide.light, 4, 3, rank: PieceRank.king),
        piece('dark-far', PlayerSide.dark, 0, 1),
      ], activeSide: PlayerSide.light);

      expect(
        engine.legalMoves(manState).map((move) => move.destination.row).toSet(),
        <int>{3},
      );
      expect(
        engine
            .legalMoves(kingState)
            .map((move) => move.destination.row)
            .toSet(),
        <int>{3, 5},
      );
    });

    test('men capture forward while kings may capture backward', () {
      final manState = state(<Piece>[
        piece('dark-man', PlayerSide.dark, 4, 3),
        piece('light-behind', PlayerSide.light, 3, 2),
      ]);
      final kingState = state(<Piece>[
        piece('dark-king', PlayerSide.dark, 4, 3, rank: PieceRank.king),
        piece('light-behind', PlayerSide.light, 3, 2),
      ]);

      expect(
        engine.legalMoves(manState).every((move) => !move.isCapture),
        isTrue,
      );
      expect(engine.legalMoves(kingState), hasLength(1));
      expect(engine.legalMoves(kingState).single.isCapture, isTrue);
      expect(
        engine.legalMoves(kingState).single.destination,
        BoardPosition(row: 2, column: 1),
      );
    });

    test('makes a capture compulsory', () {
      final position = state(<Piece>[
        piece('dark-jumper', PlayerSide.dark, 2, 1),
        piece('dark-runner', PlayerSide.dark, 2, 5),
        piece('light-target', PlayerSide.light, 3, 2),
      ]);

      final legal = engine.legalMoves(position);
      final ignoredCapture = submittedMove(
        'ignored-capture',
        'dark-runner',
        <BoardPosition>[
          BoardPosition(row: 2, column: 5),
          BoardPosition(row: 3, column: 4),
        ],
      );

      expect(legal, hasLength(1));
      expect(legal.single.pieceId, 'dark-jumper');
      expect(legal.single.capturedPieceIds, <String>['light-target']);
      expect(
        engine.validateMove(position, ignoredCapture).rejectionCode,
        MoveRejectionCode.captureRequired,
      );
    });

    test('requires a multiple capture to be completed', () {
      final position = state(<Piece>[
        piece('dark-jumper', PlayerSide.dark, 2, 1),
        piece('light-first', PlayerSide.light, 3, 2),
        piece('light-second', PlayerSide.light, 5, 2),
      ]);
      final partial = submittedMove(
        'partial',
        'dark-jumper',
        <BoardPosition>[
          BoardPosition(row: 2, column: 1),
          BoardPosition(row: 4, column: 3),
        ],
        captures: <String>['light-first'],
      );

      final legal = engine.legalMoves(position);

      expect(legal, hasLength(1));
      expect(legal.single.path, <BoardPosition>[
        BoardPosition(row: 2, column: 1),
        BoardPosition(row: 4, column: 3),
        BoardPosition(row: 6, column: 1),
      ]);
      expect(
        engine.validateMove(position, partial).rejectionCode,
        MoveRejectionCode.incompleteCapture,
      );
    });

    test('allows any complete capture instead of requiring the longest', () {
      final position = state(<Piece>[
        piece('dark-jumper', PlayerSide.dark, 2, 3),
        piece('light-left', PlayerSide.light, 3, 2),
        piece('light-right', PlayerSide.light, 3, 4),
        piece('light-follow-up', PlayerSide.light, 5, 6),
      ]);

      final legal = engine.legalMoves(position);

      expect(legal, hasLength(2));
      expect(legal.map((move) => move.captureCount).toSet(), <int>{1, 2});
      expect(
        legal.every((move) => engine.validateMove(position, move).isValid),
        isTrue,
      );
    });

    test('crowns on the king row and ends the capture turn', () {
      final position = state(<Piece>[
        piece('dark-man', PlayerSide.dark, 5, 0),
        piece('light-crowned-jump', PlayerSide.light, 6, 1),
        piece('light-backward-option', PlayerSide.light, 6, 3),
      ]);

      final legal = engine.legalMoves(position);
      final result = engine.applyMove(position, legal.single);

      expect(legal.single.captureCount, 1);
      expect(legal.single.destination, BoardPosition(row: 7, column: 2));
      expect(result.board.pieceById('dark-man')?.rank, PieceRank.king);
      expect(result.board.pieceById('light-backward-option'), isNotNull);
      expect(result.activeSide, PlayerSide.light);
    });
  });

  group('WCDF results and draw rules', () {
    test('wins after taking the opponent last piece', () {
      final position = state(<Piece>[
        piece('dark-jumper', PlayerSide.dark, 2, 1),
        piece('light-last', PlayerSide.light, 3, 2),
      ]);

      final result = engine.applyMove(
        position,
        engine.legalMoves(position).single,
      );

      expect(result.status, GameStatus.completed);
      expect(result.outcome?.type, GameOutcomeType.win);
      expect(result.outcome?.winner, PlayerSide.dark);
      expect(result.outcome?.reason, GameOutcomeReason.noPieces);
    });

    test('wins when the opponent has pieces but no legal move', () {
      final position = state(<Piece>[
        piece('dark-king', PlayerSide.dark, 5, 6, rank: PieceRank.king),
        piece('light-blocked', PlayerSide.light, 0, 1),
      ]);
      final move = engine
          .legalMoves(position)
          .firstWhere(
            (candidate) =>
                candidate.destination == BoardPosition(row: 4, column: 7),
          );

      final result = engine.applyMove(position, move);

      expect(result.status, GameStatus.completed);
      expect(result.outcome?.winner, PlayerSide.dark);
      expect(result.outcome?.reason, GameOutcomeReason.noLegalMoves);
    });

    test('draws when the same position occurs for the third time', () {
      var current = state(<Piece>[
        piece('dark-king', PlayerSide.dark, 2, 1, rank: PieceRank.king),
        piece('light-king', PlayerSide.light, 5, 6, rank: PieceRank.king),
      ]);
      final cycle = <(String, BoardPosition, BoardPosition)>[
        (
          'dark-king',
          BoardPosition(row: 2, column: 1),
          BoardPosition(row: 3, column: 0),
        ),
        (
          'light-king',
          BoardPosition(row: 5, column: 6),
          BoardPosition(row: 4, column: 7),
        ),
        (
          'dark-king',
          BoardPosition(row: 3, column: 0),
          BoardPosition(row: 2, column: 1),
        ),
        (
          'light-king',
          BoardPosition(row: 4, column: 7),
          BoardPosition(row: 5, column: 6),
        ),
      ];

      for (var repetition = 0; repetition < 2; repetition += 1) {
        for (final step in cycle) {
          current = engine.applyMove(
            current,
            submittedMove('cycle-${current.ply}', step.$1, <BoardPosition>[
              step.$2,
              step.$3,
            ]),
          );
        }
      }

      expect(current.status, GameStatus.completed);
      expect(current.outcome?.type, GameOutcomeType.draw);
      expect(current.outcome?.reason, GameOutcomeReason.repetition);
    });

    test('draws after 40 moves per player without capture or man advance', () {
      final previousHashes = <String>[
        for (var index = 0; index < 79; index += 1)
          index.toRadixString(16).padLeft(64, '0'),
      ];
      final position = state(
        <Piece>[
          piece('dark-king', PlayerSide.dark, 2, 1, rank: PieceRank.king),
          piece('light-king', PlayerSide.light, 5, 6, rank: PieceRank.king),
        ],
        ply: 79,
        revision: 79,
        previousPositionHashes: previousHashes,
        noProgressPly: 79,
      );
      final move = submittedMove('quiet-80', 'dark-king', <BoardPosition>[
        BoardPosition(row: 2, column: 1),
        BoardPosition(row: 3, column: 0),
      ]);

      final result = engine.applyMove(position, move);

      expect(result.status, GameStatus.completed);
      expect(result.outcome?.type, GameOutcomeType.draw);
      expect(result.outcome?.reason, GameOutcomeReason.moveLimit);
    });

    test('resets the no-progress counter when a man advances', () {
      final position = state(<Piece>[
        piece('dark-man', PlayerSide.dark, 2, 1),
        piece('light-king', PlayerSide.light, 5, 6, rank: PieceRank.king),
      ], noProgressPly: 79);
      final move = submittedMove('man-advance', 'dark-man', <BoardPosition>[
        BoardPosition(row: 2, column: 1),
        BoardPosition(row: 3, column: 0),
      ]);

      final result = engine.applyMove(position, move);

      expect(result.status, GameStatus.active);
      expect(
        result.ruleCounters[AmericanCheckersRulesEngine.noProgressPlyCounter],
        0,
      );
    });
  });

  test('generated play preserves transition invariants', () {
    var current = engine.createInitialState();

    for (
      var turn = 0;
      turn < 120 && current.status == GameStatus.active;
      turn += 1
    ) {
      final legal = engine.legalMoves(current);
      expect(legal, isNotEmpty);
      expect(
        legal.every((move) => engine.validateMove(current, move).isValid),
        isTrue,
      );

      final selected = legal[turn % legal.length];
      final previousPieceCount = current.board.pieceCount;
      final next = engine.applyMove(current, selected);

      expect(next.revision, current.revision + 1);
      expect(next.ply, current.ply + 1);
      expect(next.positionHistory.length, current.positionHistory.length + 1);
      expect(next.board.pieceCount, previousPieceCount - selected.captureCount);
      current = next;
    }
  });
}
