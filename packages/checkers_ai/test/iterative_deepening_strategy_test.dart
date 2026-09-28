import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();

  AiSearchRequest openingRequest({
    required int maxDepth,
    int? maxNodes,
    AiCancellationToken cancellationToken = const NoCancellationToken(),
  }) {
    final state = engine.createInitialState();
    return AiSearchRequest(
      state: state,
      legalMoves: engine.legalMoves(state),
      budget: SearchBudget(maxDepth: maxDepth, maxNodes: maxNodes),
      cancellationToken: cancellationToken,
    );
  }

  test('completes each depth through the requested ceiling', () async {
    final strategy = IterativeDeepeningStrategy(rulesEngine: engine);

    final result = await strategy.chooseMove(openingRequest(maxDepth: 3));

    expect(result.metadata.strategyId, IterativeDeepeningStrategy.strategyId);
    expect(result.metadata.completedDepth, 3);
    expect(result.metadata.stopReason, SearchStopReason.depthLimit);
    expect(result.metadata.nodesExamined, greaterThan(0));
    expect(
      engine.validateMove(engine.createInitialState(), result.move).isValid,
      isTrue,
    );
  });

  test(
    'retains the last completed result when a deeper search is cut off',
    () async {
      final strategy = IterativeDeepeningStrategy(rulesEngine: engine);
      final position = engine.createInitialState();
      final depthOne = await strategy.chooseMove(openingRequest(maxDepth: 1));

      final limited = await strategy.chooseMove(
        openingRequest(maxDepth: 4, maxNodes: 8),
      );

      expect(limited.metadata.completedDepth, 1);
      expect(limited.metadata.nodesExamined, 8);
      expect(limited.metadata.stopReason, SearchStopReason.nodeLimit);
      expect(limited.move.id, depthOne.move.id);
      expect(engine.validateMove(position, limited.move).isValid, isTrue);
    },
  );

  test('returns a legal fallback if depth one cannot complete', () async {
    final strategy = IterativeDeepeningStrategy(rulesEngine: engine);
    final position = engine.createInitialState();

    final result = await strategy.chooseMove(
      openingRequest(maxDepth: 3, maxNodes: 1),
    );

    expect(result.metadata.completedDepth, 0);
    expect(result.metadata.nodesExamined, 1);
    expect(result.metadata.stopReason, SearchStopReason.nodeLimit);
    expect(engine.validateMove(position, result.move).isValid, isTrue);
  });

  test('honors cancellation before iterative search', () async {
    final controller = AiCancellationController()..cancel();
    final strategy = IterativeDeepeningStrategy(rulesEngine: engine);

    await expectLater(
      strategy.chooseMove(
        openingRequest(maxDepth: 3, cancellationToken: controller.token),
      ),
      throwsA(isA<AiSearchCancelledException>()),
    );
  });
}
