import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/game/application/ai_turn_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = AmericanCheckersRulesEngine();

  test('isolated AI returns a legal deterministic preset move', () async {
    final runner = IsolateAiTurnRunner();
    addTearDown(runner.dispose);
    final state = engine.createInitialState();
    final legalMoves = engine.legalMoves(state);

    final result = await runner.chooseMove(
      difficulty: AiDifficulty.beginner,
      state: state,
      legalMoves: legalMoves,
    );

    expect(legalMoves.map((move) => move.id), contains(result.move.id));
    expect(result.metadata.strategyId, BeginnerStrategy.strategyId);
  });

  test('isolated AI work can be cancelled externally', () async {
    final runner = IsolateAiTurnRunner();
    addTearDown(runner.dispose);
    final state = engine.createInitialState();

    final search = runner.chooseMove(
      difficulty: AiDifficulty.expert,
      state: state,
      legalMoves: engine.legalMoves(state),
    );
    final expectation = expectLater(
      search,
      throwsA(isA<AiSearchCancelledException>()),
    );
    runner.cancel();

    await expectation;
  });
}
