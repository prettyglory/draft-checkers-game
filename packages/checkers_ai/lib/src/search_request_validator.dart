import 'package:checkers_engine/checkers_engine.dart';

import 'ai_search.dart';

void validateSearchRequest(RulesEngine rulesEngine, AiSearchRequest request) {
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

bool _sameMoves(List<Move> left, List<Move> right) {
  if (left.length != right.length) {
    return false;
  }
  final leftSignatures = left.map(_signature).toSet();
  final rightSignatures = right.map(_signature).toSet();
  return leftSignatures.length == left.length &&
      rightSignatures.length == right.length &&
      leftSignatures.containsAll(rightSignatures);
}

String _signature(Move move) {
  final path = move.path
      .map((position) => '${position.row},${position.column}')
      .join(';');
  return '${move.id}|${move.pieceId}|$path|${move.capturedPieceIds.join(';')}';
}
