import 'package:checkers_ai/checkers_ai.dart';
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

  AiSearchRequest request(
    GameState state, {
    int? maxNodes,
    int maxDepth = 1,
    AiCancellationToken cancellationToken = const NoCancellationToken(),
  }) {
    return AiSearchRequest(
      state: state,
      legalMoves: engine.legalMoves(state),
      budget: SearchBudget(maxDepth: maxDepth, maxNodes: maxNodes),
      cancellationToken: cancellationToken,
    );
  }

  test('finds an immediate tactical win', () async {
    final position = state(<Piece>[
      piece('dark-king', PlayerSide.dark, 5, 6, rank: PieceRank.king),
      piece('light-blocked', PlayerSide.light, 0, 1),
    ]);
    final strategy = FixedDepthAlphaBetaStrategy(rulesEngine: engine);

    final result = await strategy.chooseMove(request(position));

    expect(engine.validateMove(position, result.move).isValid, isTrue);
    expect(
      engine.applyMove(position, result.move).status,
      GameStatus.completed,
    );
    expect(result.metadata.completedDepth, 1);
    expect(result.metadata.stopReason, SearchStopReason.depthLimit);
  });

  test('returns a deterministic legal move from the opening', () async {
    final position = engine.createInitialState();
    final strategy = FixedDepthAlphaBetaStrategy(rulesEngine: engine);

    final first = await strategy.chooseMove(request(position, maxDepth: 2));
    final second = await strategy.chooseMove(request(position, maxDepth: 2));

    expect(first.move.id, second.move.id);
    expect(engine.validateMove(position, first.move).isValid, isTrue);
    expect(first.metadata.nodesExamined, greaterThan(0));
    expect(first.metadata.completedDepth, 2);
  });

  test('stops at the node budget and still returns a legal fallback', () async {
    final position = engine.createInitialState();
    final strategy = FixedDepthAlphaBetaStrategy(rulesEngine: engine);

    final result = await strategy.chooseMove(
      request(position, maxDepth: 4, maxNodes: 1),
    );

    expect(result.metadata.nodesExamined, 1);
    expect(result.metadata.completedDepth, 0);
    expect(result.metadata.stopReason, SearchStopReason.nodeLimit);
    expect(engine.validateMove(position, result.move).isValid, isTrue);
  });

  test('requires an explicit depth budget', () async {
    final position = engine.createInitialState();
    final strategy = FixedDepthAlphaBetaStrategy(rulesEngine: engine);

    await expectLater(
      strategy.chooseMove(
        AiSearchRequest(
          state: position,
          legalMoves: engine.legalMoves(position),
          budget: SearchBudget(maxNodes: 10),
        ),
      ),
      throwsA(
        isA<AiSearchException>().having(
          (error) => error.failure,
          'failure',
          AiSearchFailure.missingDepthBudget,
        ),
      ),
    );
  });

  test('honors cancellation before search', () async {
    final position = engine.createInitialState();
    final controller = AiCancellationController()..cancel();
    final strategy = FixedDepthAlphaBetaStrategy(rulesEngine: engine);

    await expectLater(
      strategy.chooseMove(
        request(position, cancellationToken: controller.token),
      ),
      throwsA(isA<AiSearchCancelledException>()),
    );
  });
}
