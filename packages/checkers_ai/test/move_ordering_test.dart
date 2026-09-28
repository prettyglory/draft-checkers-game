import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();
  const ordering = MoveOrdering();

  Piece piece(String id, PlayerSide side, int row, int column) {
    return Piece(
      id: id,
      side: side,
      rank: PieceRank.man,
      position: BoardPosition(row: row, column: column),
    );
  }

  GameState state(Iterable<Piece> pieces) {
    return GameState(
      rulesetId: AmericanCheckersRulesEngine.rulesetId,
      boardSize: 8,
      pieces: pieces,
      activeSide: PlayerSide.dark,
      ply: 0,
      revision: 0,
    );
  }

  test('orders longer captures before shorter captures', () {
    final position = state(<Piece>[
      piece('dark-jumper', PlayerSide.dark, 2, 3),
      piece('light-left', PlayerSide.light, 3, 2),
      piece('light-right', PlayerSide.light, 3, 4),
      piece('light-follow-up', PlayerSide.light, 5, 6),
    ]);
    final legalMoves = engine.legalMoves(position);

    final ordered = ordering.order(position, legalMoves);

    expect(ordered.map((move) => move.captureCount), <int>[2, 1]);
  });

  test('orders promotions before ordinary moves', () {
    final position = state(<Piece>[
      piece('dark-promoter', PlayerSide.dark, 6, 1),
      piece('dark-runner', PlayerSide.dark, 2, 5),
      piece('light-far', PlayerSide.light, 0, 7),
    ]);
    final legalMoves = engine.legalMoves(position);

    final ordered = ordering.order(position, legalMoves);

    expect(ordered.first.pieceId, 'dark-promoter');
    expect(ordered.first.destination.row, 7);
  });

  test('places a preferred principal move first', () {
    final position = engine.createInitialState();
    final legalMoves = engine.legalMoves(position);
    final preferred = legalMoves.last;

    final ordered = ordering.order(
      position,
      legalMoves,
      preferredMoveId: preferred.id,
    );

    expect(ordered.first.id, preferred.id);
  });

  test('does not mutate input and keeps deterministic tie breaking', () {
    final position = engine.createInitialState();
    final source = engine.legalMoves(position).reversed.toList();
    final originalIds = source.map((move) => move.id).toList();

    final ordered = ordering.order(position, source);

    expect(source.map((move) => move.id), originalIds);
    expect(
      ordered.map((move) => move.id),
      ordered.map((move) => move.id).toList()..sort(),
    );
    expect(() => ordered.clear(), throwsUnsupportedError);
  });
}
