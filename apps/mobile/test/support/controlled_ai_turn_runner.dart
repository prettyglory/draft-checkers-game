import 'dart:async';

import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/game/application/ai_turn_runner.dart';

final class AiTurnRequestRecord {
  const AiTurnRequestRecord({
    required this.difficulty,
    required this.state,
    required this.legalMoves,
  });

  final AiDifficulty difficulty;
  final GameState state;
  final List<Move> legalMoves;
}

final class ControlledAiTurnRunner implements AiTurnRunner {
  final List<AiTurnRequestRecord> requests = <AiTurnRequestRecord>[];
  Completer<AiSearchResult>? _completer;
  int cancellationCount = 0;
  bool disposed = false;

  bool get hasPendingSearch => _completer != null;

  @override
  Future<AiSearchResult> chooseMove({
    required AiDifficulty difficulty,
    required GameState state,
    required List<Move> legalMoves,
  }) {
    requests.add(
      AiTurnRequestRecord(
        difficulty: difficulty,
        state: state,
        legalMoves: List<Move>.unmodifiable(legalMoves),
      ),
    );
    _completer = Completer<AiSearchResult>();
    return _completer!.future;
  }

  void completeWithMove([Move? move]) {
    final completer = _completer;
    if (completer == null) throw StateError('No AI search is pending.');
    final selected = move ?? requests.last.legalMoves.first;
    _completer = null;
    completer.complete(
      AiSearchResult(
        move: selected,
        metadata: AiSearchMetadata(
          strategyId: 'controlled-test-ai',
          nodesExamined: 1,
          completedDepth: 1,
          elapsed: Duration.zero,
          stopReason: SearchStopReason.completed,
        ),
      ),
    );
  }

  @override
  void cancel() {
    cancellationCount += 1;
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(const AiSearchCancelledException());
    }
  }

  @override
  void dispose() {
    disposed = true;
    cancel();
  }
}
