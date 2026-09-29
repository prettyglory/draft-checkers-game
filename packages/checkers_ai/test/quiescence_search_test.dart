import 'dart:io';

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
    RulesEngine rulesEngine,
    GameState position, {
    int maxDepth = 1,
    int? maxNodes,
    Duration? maxDuration,
    AiCancellationToken cancellationToken = const NoCancellationToken(),
  }) {
    return AiSearchRequest(
      state: position,
      legalMoves: rulesEngine.legalMoves(position),
      budget: SearchBudget(
        maxDepth: maxDepth,
        maxNodes: maxNodes,
        maxDuration: maxDuration,
      ),
      cancellationToken: cancellationToken,
    );
  }

  GameState horizonPosition() => state(<Piece>[
    piece('dark-man', PlayerSide.dark, 2, 1),
    piece('light-man', PlayerSide.light, 4, 3),
  ]);

  GameState forcingSequencePosition() => state(<Piece>[
    piece('dark-man', PlayerSide.dark, 2, 1),
    piece('dark-recapturer', PlayerSide.dark, 4, 1),
    piece('light-blocker', PlayerSide.light, 3, 0),
    piece('light-victim', PlayerSide.light, 3, 2),
    piece('light-king', PlayerSide.light, 3, 4, rank: PieceRank.king),
  ]);

  test(
    'avoids a horizon capture that static frontier evaluation misses',
    () async {
      final position = horizonPosition();
      final staticStrategy = FixedDepthAlphaBetaStrategy(
        rulesEngine: engine,
        maxQuiescenceDepth: 0,
      );
      final quiescentStrategy = FixedDepthAlphaBetaStrategy(
        rulesEngine: engine,
      );

      final staticResult = await staticStrategy.chooseMove(
        request(engine, position),
      );
      final quiescentResult = await quiescentStrategy.chooseMove(
        request(engine, position),
      );

      expect(staticResult.move.destination, BoardPosition(row: 3, column: 2));
      expect(
        quiescentResult.move.destination,
        BoardPosition(row: 3, column: 0),
      );
      expect(quiescentResult.metadata.quiescence.maximumDepth, 1);
    },
  );

  test(
    'follows forced capture continuations until the position is stable',
    () async {
      final position = forcingSequencePosition();
      final strategy = FixedDepthAlphaBetaStrategy(rulesEngine: engine);
      final rootCapture = engine.legalMoves(position).single;
      final firstFrontier = engine.applyMove(position, rootCapture);
      final lightCapture = engine.legalMoves(firstFrontier).single;
      final secondFrontier = engine.applyMove(firstFrontier, lightCapture);
      final darkCapture = engine.legalMoves(secondFrontier).single;
      final stable = engine.applyMove(secondFrontier, darkCapture);

      expect(rootCapture.id, '0:dark-man:21-43');
      expect(rootCapture.capturedPieceIds, <String>['light-victim']);
      expect(firstFrontier.activeSide, PlayerSide.light);
      expect(lightCapture.id, '1:light-king:34-52');
      expect(lightCapture.capturedPieceIds, <String>['dark-man']);
      expect(secondFrontier.activeSide, PlayerSide.dark);
      expect(darkCapture.id, '2:dark-recapturer:41-63');
      expect(darkCapture.capturedPieceIds, <String>['light-king']);
      expect(stable.activeSide, PlayerSide.light);
      expect(stable.status, GameStatus.active);
      expect(engine.legalMoves(stable).any((move) => move.isCapture), isFalse);

      final result = await strategy.chooseMove(request(engine, position));

      expect(engine.validateMove(position, result.move).isValid, isTrue);
      expect(result.metadata.completedDepth, 1);
      expect(result.metadata.quiescence.nodes, 3);
      expect(result.metadata.quiescence.maximumDepth, 2);
    },
  );

  test('does not extend quiet stable frontier positions', () async {
    final position = engine.createInitialState();
    final strategy = FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      usePrincipalVariationSearch: false,
    );

    final result = await strategy.chooseMove(request(engine, position));

    expect(result.metadata.quiescence.nodes, result.metadata.nodesExamined);
    expect(result.metadata.quiescence.maximumDepth, 0);
    expect(result.metadata.quiescence.cutoffs, 0);
  });

  test(
    'evaluates terminal frontier positions without extending them',
    () async {
      final position = state(<Piece>[
        piece('dark-man', PlayerSide.dark, 2, 1),
        piece('light-man', PlayerSide.light, 3, 2),
      ]);
      final strategy = FixedDepthAlphaBetaStrategy(rulesEngine: engine);

      final result = await strategy.chooseMove(request(engine, position));
      final completed = engine.applyMove(position, result.move);

      expect(completed.status, GameStatus.completed);
      expect(result.metadata.quiescence.nodes, 1);
      expect(result.metadata.quiescence.maximumDepth, 0);
    },
  );

  test('checks cancellation while extending captures', () async {
    final position = forcingSequencePosition();
    final token = _CancelAfterChecks(4);
    final strategy = FixedDepthAlphaBetaStrategy(rulesEngine: engine);

    await expectLater(
      strategy.chooseMove(request(engine, position, cancellationToken: token)),
      throwsA(isA<AiSearchCancelledException>()),
    );
    expect(token.checks, 4);
  });

  test('charges quiescence extensions to the node budget', () async {
    final position = forcingSequencePosition();
    final strategy = FixedDepthAlphaBetaStrategy(rulesEngine: engine);

    final result = await strategy.chooseMove(
      request(engine, position, maxNodes: 2),
    );

    expect(result.metadata.nodesExamined, 2);
    expect(result.metadata.completedDepth, 0);
    expect(result.metadata.stopReason, SearchStopReason.nodeLimit);
    expect(result.metadata.quiescence.nodes, 2);
    expect(result.metadata.quiescence.maximumDepth, 1);
  });

  test('checks the time budget between quiescence nodes', () async {
    final position = forcingSequencePosition();
    final delayedEngine = _DelayedQuiescenceRulesEngine(engine);
    final strategy = FixedDepthAlphaBetaStrategy(rulesEngine: delayedEngine);

    final result = await strategy.chooseMove(
      request(
        delayedEngine,
        position,
        maxDuration: const Duration(milliseconds: 5),
      ),
    );

    expect(result.metadata.completedDepth, 0);
    expect(result.metadata.stopReason, SearchStopReason.timeLimit);
    expect(result.metadata.quiescence.nodes, 1);
  });

  test('keeps quiescence deterministic and transposition-safe', () async {
    final position = forcingSequencePosition();
    final table = TranspositionTable();
    final strategy = FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      transpositionTable: table,
    );
    final searchRequest = request(engine, position);
    final normalKey = TranspositionKey.fromState(
      state: position,
      perspective: PlayerSide.dark,
      weights: EvaluationWeights(),
    );
    final quiescenceKey = TranspositionKey.fromState(
      state: position,
      perspective: PlayerSide.dark,
      weights: EvaluationWeights(),
      nodeType: TranspositionNodeType.quiescence,
    );

    final cold = await strategy.chooseMove(searchRequest);
    final warm = await strategy.chooseMove(searchRequest);
    final uncached = await FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      transpositionTable: TranspositionTable(maxEntries: 0),
    ).chooseMove(searchRequest);

    expect(normalKey, isNot(quiescenceKey));
    expect(warm.move.id, cold.move.id);
    expect(uncached.move.id, cold.move.id);
    expect(warm.metadata.transposition.hits, greaterThan(0));
    expect(warm.metadata.nodesExamined, lessThan(cold.metadata.nodesExamined));
  });

  test('caps forcing extensions at the configured depth', () async {
    final position = forcingSequencePosition();
    final strategy = FixedDepthAlphaBetaStrategy(
      rulesEngine: engine,
      maxQuiescenceDepth: 1,
    );

    final result = await strategy.chooseMove(request(engine, position));

    expect(result.metadata.completedDepth, 1);
    expect(result.metadata.quiescence.maximumDepth, 1);
    expect(result.metadata.quiescence.nodes, 2);
  });
}

final class _CancelAfterChecks implements AiCancellationToken {
  _CancelAfterChecks(this.cancelAt);

  final int cancelAt;
  int checks = 0;

  @override
  bool get isCancelled {
    checks += 1;
    return checks >= cancelAt;
  }
}

final class _DelayedQuiescenceRulesEngine implements RulesEngine {
  _DelayedQuiescenceRulesEngine(this.delegate);

  final RulesEngine delegate;

  @override
  RulesetDescriptor get descriptor => delegate.descriptor;

  @override
  GameState createInitialState() => delegate.createInitialState();

  @override
  List<Move> legalMoves(GameState state) {
    if (state.ply > 0) {
      sleep(const Duration(milliseconds: 20));
    }
    return delegate.legalMoves(state);
  }

  @override
  MoveValidation validateMove(GameState state, Move move) {
    return delegate.validateMove(state, move);
  }

  @override
  GameState applyMove(GameState state, Move move) {
    return delegate.applyMove(state, move);
  }
}
