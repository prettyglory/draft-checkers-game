import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/game/presentation/game_board_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('selection exposes only engine-approved next landings', () {
    final viewModel = GameBoardViewModel();
    addTearDown(viewModel.dispose);

    viewModel.tapSquare(BoardPosition(row: 2, column: 1));

    expect(viewModel.selectedPieceId, 'dark-09');
    expect(viewModel.targetPositions, <BoardPosition>{
      BoardPosition(row: 3, column: 0),
      BoardPosition(row: 3, column: 2),
    });
  });

  test('multi-capture previews each step before applying one turn', () {
    final captureState = GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: <Piece>[
        piece('dark-jumper', PlayerSide.dark, 2, 1),
        piece('light-first', PlayerSide.light, 3, 2),
        piece('light-second', PlayerSide.light, 5, 2),
      ],
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );
    final viewModel = GameBoardViewModel(initialState: captureState);
    addTearDown(viewModel.dispose);

    viewModel.tapSquare(BoardPosition(row: 2, column: 1));
    viewModel.tapSquare(BoardPosition(row: 4, column: 3));

    expect(viewModel.state.revision, 0);
    expect(viewModel.isPathInProgress, isTrue);
    expect(
      viewModel.displayPieceAt(BoardPosition(row: 4, column: 3))?.id,
      'dark-jumper',
    );
    expect(viewModel.targetPositions, <BoardPosition>{
      BoardPosition(row: 6, column: 1),
    });

    viewModel.tapSquare(BoardPosition(row: 6, column: 1));

    expect(viewModel.state.revision, 1);
    expect(viewModel.state.status, GameStatus.completed);
    expect(viewModel.selectedPieceId, isNull);
  });

  test('reset restores the WCDF opening state', () {
    final viewModel = GameBoardViewModel();
    addTearDown(viewModel.dispose);
    viewModel.tapSquare(BoardPosition(row: 2, column: 1));
    viewModel.tapSquare(BoardPosition(row: 3, column: 0));
    expect(viewModel.state.revision, 1);

    viewModel.reset();

    expect(viewModel.state.revision, 0);
    expect(viewModel.state.activeSide, PlayerSide.dark);
    expect(viewModel.state.board.pieceCount, 24);
    expect(viewModel.selectedPieceId, isNull);
  });

  test('promotion crowns a man and ends its capture turn', () {
    final promotionState = GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: <Piece>[
        piece('dark-man', PlayerSide.dark, 5, 0),
        piece('light-crowned-jump', PlayerSide.light, 6, 1),
        piece('light-backward-option', PlayerSide.light, 6, 3),
      ],
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );
    final viewModel = GameBoardViewModel(initialState: promotionState);
    addTearDown(viewModel.dispose);

    viewModel.tapSquare(BoardPosition(row: 5, column: 0));
    expect(viewModel.targetPositions, <BoardPosition>{
      BoardPosition(row: 7, column: 2),
    });

    viewModel.tapSquare(BoardPosition(row: 7, column: 2));

    expect(viewModel.state.revision, 1);
    expect(viewModel.state.activeSide, PlayerSide.light);
    expect(viewModel.state.board.pieceById('dark-man')?.rank, PieceRank.king);
    expect(viewModel.state.board.pieceById('light-backward-option'), isNotNull);
  });

  test('king selection exposes backward moves', () {
    final kingState = GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: <Piece>[
        piece('dark-king', PlayerSide.dark, 4, 3, rank: PieceRank.king),
        piece('light-far', PlayerSide.light, 0, 1),
      ],
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );
    final viewModel = GameBoardViewModel(initialState: kingState);
    addTearDown(viewModel.dispose);

    viewModel.tapSquare(BoardPosition(row: 4, column: 3));

    expect(
      viewModel.targetPositions,
      contains(BoardPosition(row: 3, column: 2)),
    );
    expect(
      viewModel.targetPositions,
      contains(BoardPosition(row: 3, column: 4)),
    );
  });
}
