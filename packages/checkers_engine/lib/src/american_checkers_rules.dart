import 'board.dart';
import 'board_position.dart';
import 'game_state.dart';
import 'move.dart';
import 'piece.dart';
import 'rules_engine.dart';
import 'ruleset_descriptor.dart';

typedef _Direction = ({int rows, int columns});

/// WCDF American Checkers / English Draughts rules.
final class AmericanCheckersRulesEngine implements RulesEngine {
  const AmericanCheckersRulesEngine();

  static const String rulesetId = 'american';
  static const String noProgressPlyCounter = 'american.noProgressPly';
  static const int noProgressDrawPlyLimit = 80;
  static const int _boardSize = 8;

  static final RulesetDescriptor _descriptor = RulesetDescriptor(
    id: rulesetId,
    displayName: 'American Checkers',
    boardSize: _boardSize,
    piecesPerSide: 12,
    importantDifferences: const <String>[
      'Men move and capture diagonally forward only.',
      'Captures are compulsory; any complete capture sequence may be chosen.',
      'A man that reaches the king row ends its turn and is crowned.',
    ],
  );

  static const List<_Direction> _kingDirections = <_Direction>[
    (rows: -1, columns: -1),
    (rows: -1, columns: 1),
    (rows: 1, columns: -1),
    (rows: 1, columns: 1),
  ];

  @override
  RulesetDescriptor get descriptor => _descriptor;

  @override
  GameState createInitialState() {
    final pieces = <Piece>[];
    var darkNumber = 1;
    var lightNumber = 1;
    for (var row = 0; row < _boardSize; row += 1) {
      for (var column = 0; column < _boardSize; column += 1) {
        if (!_isPlayable(row, column)) {
          continue;
        }
        if (row < 3) {
          pieces.add(
            Piece(
              id: 'dark-${darkNumber.toString().padLeft(2, '0')}',
              side: PlayerSide.dark,
              rank: PieceRank.man,
              position: BoardPosition(row: row, column: column),
            ),
          );
          darkNumber += 1;
        } else if (row > 4) {
          pieces.add(
            Piece(
              id: 'light-${lightNumber.toString().padLeft(2, '0')}',
              side: PlayerSide.light,
              rank: PieceRank.man,
              position: BoardPosition(row: row, column: column),
            ),
          );
          lightNumber += 1;
        }
      }
    }

    return GameState(
      rulesetId: rulesetId,
      boardSize: _boardSize,
      pieces: pieces,
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
      ruleCounters: const <String, int>{noProgressPlyCounter: 0},
    );
  }

  @override
  List<Move> legalMoves(GameState state) {
    _requireCompatible(state);
    if (state.status == GameStatus.completed) {
      return const <Move>[];
    }

    final captures = <Move>[];
    for (final piece in state.board.piecesFor(state.activeSide)) {
      captures.addAll(_captureMoves(state, piece));
    }
    if (captures.isNotEmpty) {
      captures.sort(_compareMoves);
      return List<Move>.unmodifiable(captures);
    }

    final ordinaryMoves = <Move>[];
    for (final piece in state.board.piecesFor(state.activeSide)) {
      for (final direction in _directionsFor(piece)) {
        final destination = _offset(piece.position, direction, distance: 1);
        if (destination == null || !state.board.isEmptyAt(destination)) {
          continue;
        }
        final path = <BoardPosition>[piece.position, destination];
        ordinaryMoves.add(
          Move(
            id: _moveId(state.revision, piece.id, path),
            pieceId: piece.id,
            path: path,
          ),
        );
      }
    }
    ordinaryMoves.sort(_compareMoves);
    return List<Move>.unmodifiable(ordinaryMoves);
  }

  @override
  MoveValidation validateMove(GameState state, Move move) {
    _requireCompatible(state);
    if (state.status == GameStatus.completed) {
      return const MoveValidation.invalid(
        MoveRejectionCode.gameAlreadyCompleted,
      );
    }
    final piece = state.board.pieceById(move.pieceId);
    if (piece == null) {
      return const MoveValidation.invalid(MoveRejectionCode.pieceNotFound);
    }
    if (piece.side != state.activeSide) {
      return const MoveValidation.invalid(MoveRejectionCode.wrongTurn);
    }
    if (piece.position != move.origin) {
      return const MoveValidation.invalid(MoveRejectionCode.staleState);
    }

    final legal = legalMoves(state);
    if (legal.any((candidate) => _sameMove(candidate, move))) {
      return const MoveValidation.valid();
    }
    if (legal.any((candidate) => candidate.isCapture) && !move.isCapture) {
      return const MoveValidation.invalid(MoveRejectionCode.captureRequired);
    }
    if (move.isCapture &&
        legal.any((candidate) => _isCapturePrefix(move, candidate))) {
      return const MoveValidation.invalid(MoveRejectionCode.incompleteCapture);
    }
    return const MoveValidation.invalid(MoveRejectionCode.illegalMovement);
  }

  @override
  GameState applyMove(GameState state, Move move) {
    final validation = validateMove(state, move);
    if (!validation.isValid) {
      throw StateError(
        'Cannot apply move ${move.id}: ${validation.rejectionCode}.',
      );
    }

    final movingPiece = state.board.pieceById(move.pieceId)!;
    final promotes =
        movingPiece.rank == PieceRank.man &&
        _isKingRow(movingPiece.side, move.destination.row);
    final board = state.board.applyMove(move, promote: promotes);
    final nextSide = _opponent(state.activeSide);
    final noProgressPly = move.isCapture || movingPiece.rank == PieceRank.man
        ? 0
        : (state.ruleCounters[noProgressPlyCounter] ?? 0) + 1;
    final counters = <String, int>{
      ...state.ruleCounters,
      noProgressPlyCounter: noProgressPly,
    };
    final provisional = GameState(
      rulesetId: state.rulesetId,
      boardSize: state.boardSize,
      pieces: board.pieces,
      activeSide: nextSide,
      ply: state.ply + 1,
      revision: state.revision + 1,
      previousPositionHashes: state.positionHistory,
      ruleCounters: counters,
    );

    final opponentPieces = board.piecesFor(nextSide);
    if (opponentPieces.isEmpty) {
      return _complete(
        provisional,
        previousPositionHashes: state.positionHistory,
        outcome: GameOutcome.win(
          winner: movingPiece.side,
          reason: GameOutcomeReason.noPieces,
        ),
      );
    }
    if (legalMoves(provisional).isEmpty) {
      return _complete(
        provisional,
        previousPositionHashes: state.positionHistory,
        outcome: GameOutcome.win(
          winner: movingPiece.side,
          reason: GameOutcomeReason.noLegalMoves,
        ),
      );
    }
    if (provisional.positionOccurrenceCount(provisional.positionHash) >= 3) {
      return _complete(
        provisional,
        previousPositionHashes: state.positionHistory,
        outcome: const GameOutcome.draw(reason: GameOutcomeReason.repetition),
      );
    }
    if (noProgressPly >= noProgressDrawPlyLimit) {
      return _complete(
        provisional,
        previousPositionHashes: state.positionHistory,
        outcome: const GameOutcome.draw(reason: GameOutcomeReason.moveLimit),
      );
    }
    return provisional;
  }

  List<Move> _captureMoves(GameState state, Piece piece) {
    final result = <Move>[];

    void search(
      BoardPosition current,
      List<BoardPosition> path,
      List<String> capturedIds,
    ) {
      var extended = false;
      for (final direction in _directionsFor(piece)) {
        final jumped = _offset(current, direction, distance: 1);
        final landing = _offset(current, direction, distance: 2);
        if (jumped == null || landing == null) {
          continue;
        }
        final jumpedPiece = _pieceDuringCapture(
          state.board,
          movingPieceId: piece.id,
          current: current,
          path: path,
          position: jumped,
        );
        final landingPiece = _pieceDuringCapture(
          state.board,
          movingPieceId: piece.id,
          current: current,
          path: path,
          position: landing,
        );
        if (jumpedPiece == null ||
            jumpedPiece.side == piece.side ||
            capturedIds.contains(jumpedPiece.id) ||
            landingPiece != null) {
          continue;
        }

        extended = true;
        final nextPath = <BoardPosition>[...path, landing];
        final nextCapturedIds = <String>[...capturedIds, jumpedPiece.id];
        final reachesKingRow =
            piece.rank == PieceRank.man && _isKingRow(piece.side, landing.row);
        if (reachesKingRow) {
          result.add(
            Move(
              id: _moveId(state.revision, piece.id, nextPath),
              pieceId: piece.id,
              path: nextPath,
              capturedPieceIds: nextCapturedIds,
            ),
          );
        } else {
          search(landing, nextPath, nextCapturedIds);
        }
      }

      if (!extended && capturedIds.isNotEmpty) {
        result.add(
          Move(
            id: _moveId(state.revision, piece.id, path),
            pieceId: piece.id,
            path: path,
            capturedPieceIds: capturedIds,
          ),
        );
      }
    }

    search(piece.position, <BoardPosition>[piece.position], <String>[]);
    return result;
  }

  static Piece? _pieceDuringCapture(
    Board board, {
    required String movingPieceId,
    required BoardPosition current,
    required List<BoardPosition> path,
    required BoardPosition position,
  }) {
    if (position == current) {
      return board.pieceById(movingPieceId);
    }
    if (path.contains(position)) {
      return null;
    }
    return board.pieceAt(position);
  }

  static Iterable<_Direction> _directionsFor(Piece piece) {
    if (piece.rank == PieceRank.king) {
      return _kingDirections;
    }
    final forward = piece.side == PlayerSide.dark ? 1 : -1;
    return <_Direction>[
      (rows: forward, columns: -1),
      (rows: forward, columns: 1),
    ];
  }

  static BoardPosition? _offset(
    BoardPosition origin,
    _Direction direction, {
    required int distance,
  }) {
    final row = origin.row + direction.rows * distance;
    final column = origin.column + direction.columns * distance;
    if (row < 0 || row >= _boardSize || column < 0 || column >= _boardSize) {
      return null;
    }
    return BoardPosition(row: row, column: column);
  }

  static bool _sameMove(Move first, Move second) {
    return first.pieceId == second.pieceId &&
        _sameList(first.path, second.path) &&
        _sameList(first.capturedPieceIds, second.capturedPieceIds);
  }

  static bool _isCapturePrefix(Move prefix, Move complete) {
    return complete.captureCount > prefix.captureCount &&
        prefix.pieceId == complete.pieceId &&
        _isPrefix(prefix.path, complete.path) &&
        _isPrefix(prefix.capturedPieceIds, complete.capturedPieceIds);
  }

  static bool _sameList<T>(List<T> first, List<T> second) {
    return first.length == second.length && _isPrefix(first, second);
  }

  static bool _isPrefix<T>(List<T> prefix, List<T> complete) {
    if (prefix.length > complete.length) {
      return false;
    }
    for (var index = 0; index < prefix.length; index += 1) {
      if (prefix[index] != complete[index]) {
        return false;
      }
    }
    return true;
  }

  static int _compareMoves(Move first, Move second) {
    return first.id.compareTo(second.id);
  }

  static String _moveId(
    int revision,
    String pieceId,
    List<BoardPosition> path,
  ) {
    final encodedPath = path
        .map((position) => '${position.row}${position.column}')
        .join('-');
    return '$revision:$pieceId:$encodedPath';
  }

  static PlayerSide _opponent(PlayerSide side) {
    return side == PlayerSide.dark ? PlayerSide.light : PlayerSide.dark;
  }

  static bool _isPlayable(int row, int column) => (row + column).isOdd;

  static bool _isKingRow(PlayerSide side, int row) {
    return side == PlayerSide.dark ? row == _boardSize - 1 : row == 0;
  }

  static GameState _complete(
    GameState state, {
    required Iterable<String> previousPositionHashes,
    required GameOutcome outcome,
  }) {
    return GameState(
      rulesetId: state.rulesetId,
      boardSize: state.boardSize,
      pieces: state.pieces,
      activeSide: state.activeSide,
      ply: state.ply,
      revision: state.revision,
      previousPositionHashes: previousPositionHashes,
      ruleCounters: state.ruleCounters,
      status: GameStatus.completed,
      outcome: outcome,
    );
  }

  void _requireCompatible(GameState state) {
    if (state.rulesetId != rulesetId || state.boardSize != _boardSize) {
      throw ArgumentError(
        'American Checkers requires ruleset "$rulesetId" on an '
        '$_boardSize x $_boardSize board.',
      );
    }
    if (state.pieces.any(
      (piece) => !_isPlayable(piece.position.row, piece.position.column),
    )) {
      throw ArgumentError(
        'American Checkers pieces must occupy playable dark squares.',
      );
    }
  }
}
