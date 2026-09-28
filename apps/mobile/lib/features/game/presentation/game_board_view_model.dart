import 'dart:collection';

import 'package:checkers_engine/checkers_engine.dart';
import 'package:flutter/foundation.dart';

final class GameBoardViewModel extends ChangeNotifier {
  GameBoardViewModel({
    AmericanCheckersRulesEngine engine = const AmericanCheckersRulesEngine(),
    GameState? initialState,
  }) : _engine = engine,
       _state = initialState ?? engine.createInitialState() {
    _legalMoves = _engine.legalMoves(_state);
  }

  final AmericanCheckersRulesEngine _engine;
  GameState _state;
  late List<Move> _legalMoves;
  String? _selectedPieceId;
  List<BoardPosition> _selectedPath = const <BoardPosition>[];

  GameState get state => _state;
  String? get selectedPieceId => _selectedPieceId;
  List<BoardPosition> get selectedPath =>
      UnmodifiableListView<BoardPosition>(_selectedPath);

  List<Move> get legalMoves => _legalMoves;

  bool get captureRequired => legalMoves.any((move) => move.isCapture);

  Set<String> get selectablePieceIds =>
      Set<String>.unmodifiable(legalMoves.map((move) => move.pieceId));

  Set<BoardPosition> get targetPositions {
    if (_selectedPieceId == null || _selectedPath.isEmpty) {
      return const <BoardPosition>{};
    }
    return Set<BoardPosition>.unmodifiable(
      _candidateMoves.map((move) => move.path[_selectedPath.length]),
    );
  }

  bool get isPathInProgress => _selectedPath.length > 1;

  Piece? displayPieceAt(BoardPosition position) {
    if (!isPathInProgress) {
      return _state.board.pieceAt(position);
    }
    final selectedPiece = _state.board.pieceById(_selectedPieceId!);
    if (position == _selectedPath.last) {
      return selectedPiece?.copyWith(position: position);
    }
    if (position == _selectedPath.first) {
      return null;
    }
    return _state.board.pieceAt(position);
  }

  int? pathStepAt(BoardPosition position) {
    for (var index = _selectedPath.length - 1; index >= 0; index -= 1) {
      if (_selectedPath[index] == position) {
        return index;
      }
    }
    return null;
  }

  bool isFinalTarget(BoardPosition position) {
    return _candidateMoves.any(
      (move) =>
          move.path[_selectedPath.length] == position &&
          move.path.length == _selectedPath.length + 1,
    );
  }

  void tapSquare(BoardPosition position) {
    if (_state.status == GameStatus.completed) {
      return;
    }

    if (_selectedPieceId != null && targetPositions.contains(position)) {
      final nextPath = <BoardPosition>[..._selectedPath, position];
      final matching = legalMoves
          .where(
            (move) =>
                move.pieceId == _selectedPieceId &&
                _isPrefix(nextPath, move.path),
          )
          .toList();
      final completed = matching.where(
        (move) => move.path.length == nextPath.length,
      );
      if (completed.isNotEmpty) {
        _state = _engine.applyMove(_state, completed.first);
        _legalMoves = _engine.legalMoves(_state);
        _clearSelection(notify: false);
      } else {
        _selectedPath = List<BoardPosition>.unmodifiable(nextPath);
      }
      notifyListeners();
      return;
    }

    final piece = _state.board.pieceAt(position);
    if (piece != null && selectablePieceIds.contains(piece.id)) {
      if (_selectedPieceId == piece.id && _selectedPath.length == 1) {
        _clearSelection();
      } else {
        _selectedPieceId = piece.id;
        _selectedPath = List<BoardPosition>.unmodifiable(<BoardPosition>[
          piece.position,
        ]);
        notifyListeners();
      }
      return;
    }

    _clearSelection();
  }

  void reset() {
    _state = _engine.createInitialState();
    _legalMoves = _engine.legalMoves(_state);
    _clearSelection(notify: false);
    notifyListeners();
  }

  String get statusTitle {
    final outcome = _state.outcome;
    if (outcome?.type == GameOutcomeType.draw) {
      return 'Game drawn';
    }
    if (outcome?.winner case final winner?) {
      return '${_sideLabel(winner)} wins';
    }
    return '${_sideLabel(_state.activeSide)} to move';
  }

  String get statusDetail {
    if (_state.status == GameStatus.completed) {
      return switch (_state.outcome?.reason) {
        GameOutcomeReason.noPieces => 'The last opposing piece was captured.',
        GameOutcomeReason.noLegalMoves =>
          'The opposing side has no legal move.',
        GameOutcomeReason.repetition =>
          'The same position occurred three times.',
        GameOutcomeReason.moveLimit =>
          'Forty moves per side passed without progress.',
        _ => 'The game has ended.',
      };
    }
    if (_selectedPieceId != null) {
      return isPathInProgress
          ? 'Continue the capture path.'
          : 'Choose a highlighted landing square.';
    }
    if (captureRequired) {
      return 'A capture is required. Select a marked piece.';
    }
    return 'Select a marked piece to see its legal moves.';
  }

  List<Move> get _candidateMoves {
    return legalMoves
        .where(
          (move) =>
              move.pieceId == _selectedPieceId &&
              move.path.length > _selectedPath.length &&
              _isPrefix(_selectedPath, move.path),
        )
        .toList(growable: false);
  }

  void _clearSelection({bool notify = true}) {
    final changed = _selectedPieceId != null || _selectedPath.isNotEmpty;
    _selectedPieceId = null;
    _selectedPath = const <BoardPosition>[];
    if (changed && notify) {
      notifyListeners();
    }
  }

  static bool _isPrefix(
    List<BoardPosition> prefix,
    List<BoardPosition> complete,
  ) {
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

  static String _sideLabel(PlayerSide side) {
    return side == PlayerSide.dark ? 'Dark' : 'Light';
  }
}
