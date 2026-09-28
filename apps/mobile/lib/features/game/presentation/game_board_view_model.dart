import 'dart:async';
import 'dart:collection';

import 'package:checkers_engine/checkers_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:game_session/game_session.dart';

final class GameBoardViewModel extends ChangeNotifier {
  GameBoardViewModel({
    required GameSession session,
    required Map<PlayerSide, String> actorIdsBySide,
    this.closeSessionOnDispose = true,
  }) : _session = session,
       _actorIdsBySide = Map<PlayerSide, String>.unmodifiable(actorIdsBySide),
       _state = session.currentState,
       _legalMoves = session.legalMoves {
    if (actorIdsBySide.length != PlayerSide.values.length ||
        actorIdsBySide.values.any((actorId) => actorId.trim().isEmpty)) {
      throw ArgumentError('A non-empty actor id is required for each side.');
    }
    _updateSubscription = _session.updates.listen(_handleSessionUpdate);
    _startFuture = _startSession();
  }

  final GameSession _session;
  final Map<PlayerSide, String> _actorIdsBySide;
  final bool closeSessionOnDispose;
  late final StreamSubscription<SessionUpdate> _updateSubscription;
  late final Future<void> _startFuture;
  GameState _state;
  List<Move> _legalMoves;
  CommandReceipt? _lastCommandReceipt;
  Object? _sessionError;
  String? _selectedPieceId;
  List<BoardPosition> _selectedPath = const <BoardPosition>[];
  int _commandNumber = 0;
  bool _submitting = false;
  bool _disposed = false;

  GameState get state => _state;
  String? get selectedPieceId => _selectedPieceId;
  List<BoardPosition> get selectedPath =>
      UnmodifiableListView<BoardPosition>(_selectedPath);

  List<Move> get legalMoves => _legalMoves;
  CommandReceipt? get lastCommandReceipt => _lastCommandReceipt;
  Object? get sessionError => _sessionError;

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

  Future<void> tapSquare(BoardPosition position) async {
    await _startFuture;
    if (_sessionError != null) {
      return;
    }
    if (_state.status == GameStatus.completed || _submitting) {
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
        _submitting = true;
        final side = _state.activeSide;
        try {
          _lastCommandReceipt = await _session.submit(
            SubmitMoveCommand(
              commandId: _nextCommandId('move'),
              actorId: _actorIdsBySide[side]!,
              expectedRevision: _state.revision,
              move: completed.first,
            ),
          );
        } finally {
          _submitting = false;
          _synchronizeFromSession(clearSelection: true);
        }
      } else {
        _selectedPath = List<BoardPosition>.unmodifiable(nextPath);
        notifyListeners();
      }
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

  Future<void> reset() async {
    await _startFuture;
    if (_sessionError != null) {
      return;
    }
    if (_submitting) {
      return;
    }
    _submitting = true;
    try {
      _lastCommandReceipt = await _session.submit(
        StartNewGameCommand(
          commandId: _nextCommandId('new-game'),
          actorId: _actorIdsBySide[_state.activeSide]!,
          expectedRevision: _state.revision,
        ),
      );
    } finally {
      _submitting = false;
      _synchronizeFromSession(clearSelection: true);
    }
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
        GameOutcomeReason.resignation => 'The opposing player resigned.',
        GameOutcomeReason.drawAgreement => 'Both players agreed to a draw.',
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

  void _handleSessionUpdate(SessionUpdate update) {
    if (update is MoveCommitted ||
        update is StateReplaced ||
        update is DrawOfferResolved) {
      _synchronizeFromSession(clearSelection: true);
    }
  }

  Future<void> _startSession() async {
    try {
      await _session.start();
    } catch (error) {
      _sessionError = error;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  void _synchronizeFromSession({required bool clearSelection}) {
    final nextState = _session.currentState;
    final stateChanged = !identical(_state, nextState);
    final selectionChanged =
        clearSelection &&
        (_selectedPieceId != null || _selectedPath.isNotEmpty);
    _state = nextState;
    _legalMoves = _session.legalMoves;
    if (clearSelection) {
      _clearSelection(notify: false);
    }
    if (stateChanged || selectionChanged) {
      notifyListeners();
    }
  }

  String _nextCommandId(String kind) {
    _commandNumber += 1;
    return '${_session.id}-$kind-$_commandNumber';
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_updateSubscription.cancel());
    if (closeSessionOnDispose) {
      unawaited(_session.close());
    }
    super.dispose();
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
