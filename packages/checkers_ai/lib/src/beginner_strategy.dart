import 'dart:math';

import 'package:checkers_engine/checkers_engine.dart';

import 'ai_search.dart';
import 'cancellation.dart';

final class BeginnerStrategy implements AiStrategy {
  BeginnerStrategy({required this.rulesEngine, int seed = 0})
    : _random = Random(seed);

  static const strategyId = 'beginner-random';

  final RulesEngine rulesEngine;
  final Random _random;

  @override
  String get id => strategyId;

  @override
  Future<AiSearchResult> chooseMove(AiSearchRequest request) async {
    final stopwatch = Stopwatch()..start();
    _throwIfCancelled(request);
    _validateRequest(request);

    final selected =
        request.legalMoves[_random.nextInt(request.legalMoves.length)];
    _throwIfCancelled(request);
    stopwatch.stop();

    return AiSearchResult(
      move: selected,
      metadata: AiSearchMetadata(
        strategyId: id,
        nodesExamined: 1,
        completedDepth: 0,
        elapsed: stopwatch.elapsed,
        stopReason: SearchStopReason.completed,
      ),
    );
  }

  void _validateRequest(AiSearchRequest request) {
    if (request.state.rulesetId != rulesEngine.descriptor.id ||
        request.state.boardSize != rulesEngine.descriptor.boardSize) {
      throw const AiSearchException(AiSearchFailure.incompatibleRuleset);
    }
    if (request.state.status == GameStatus.completed) {
      throw const AiSearchException(AiSearchFailure.completedGame);
    }

    final authoritative = rulesEngine.legalMoves(request.state);
    if (authoritative.isEmpty || request.legalMoves.isEmpty) {
      throw const AiSearchException(AiSearchFailure.noLegalMoves);
    }
    if (!_sameMoves(authoritative, request.legalMoves)) {
      throw const AiSearchException(AiSearchFailure.legalMovesMismatch);
    }
  }

  static bool _sameMoves(List<Move> left, List<Move> right) {
    if (left.length != right.length) {
      return false;
    }
    final leftSignatures = left.map(_signature).toSet();
    final rightSignatures = right.map(_signature).toSet();
    return leftSignatures.length == left.length &&
        rightSignatures.length == right.length &&
        leftSignatures.containsAll(rightSignatures);
  }

  static String _signature(Move move) {
    final path = move.path
        .map((position) => '${position.row},${position.column}')
        .join(';');
    return '${move.id}|${move.pieceId}|$path|${move.capturedPieceIds.join(';')}';
  }

  static void _throwIfCancelled(AiSearchRequest request) {
    if (request.cancellationToken.isCancelled) {
      throw const AiSearchCancelledException();
    }
  }
}
