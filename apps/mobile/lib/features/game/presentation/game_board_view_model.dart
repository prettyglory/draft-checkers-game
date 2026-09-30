import 'dart:async';
import 'dart:collection';

import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/game/application/ai_turn_runner.dart';
import 'package:draft_game/features/game/application/game_configuration.dart';
import 'package:flutter/foundation.dart';
import 'package:game_session/game_session.dart';

enum AiTurnStatus { ready, thinking, moveCompleted, error }

final class GameBoardViewModel extends ChangeNotifier {
  GameBoardViewModel({
    required GameSession session,
    required Map<PlayerSide, String> actorIdsBySide,
    GameConfiguration? configuration,
    AiTurnRunner? aiTurnRunner,
    this.closeSessionOnDispose = true,
    this.closeAiTurnRunnerOnDispose = true,
  }) : _session = session,
       _actorIdsBySide = Map<PlayerSide, String>.unmodifiable(actorIdsBySide),
       _configuration = configuration ?? const GameConfiguration(),
       _aiTurnRunner = aiTurnRunner ?? IsolateAiTurnRunner(),
       _state = session.currentState,
       _legalMoves = session.legalMoves,
       _pendingDrawOffer = session.pendingDrawOffer {
    if (actorIdsBySide.length != PlayerSide.values.length ||
        actorIdsBySide.values.any((actorId) => actorId.trim().isEmpty)) {
      throw ArgumentError('A non-empty actor id is required for each side.');
    }
    _updateSubscription = _session.updates.listen(_handleSessionUpdate);
    _startFuture = _startSession();
  }

  final GameSession _session;
  final Map<PlayerSide, String> _actorIdsBySide;
  final AiTurnRunner _aiTurnRunner;
  final bool closeSessionOnDispose;
  final bool closeAiTurnRunnerOnDispose;
  late final StreamSubscription<SessionUpdate> _updateSubscription;
  late final Future<void> _startFuture;
  GameState _state;
  List<Move> _legalMoves;
  DrawOffer? _pendingDrawOffer;
  CommandReceipt? _lastCommandReceipt;
  Object? _sessionError;
  Object? _aiError;
  GameConfiguration _configuration;
  AiTurnStatus _aiTurnStatus = AiTurnStatus.ready;
  int? _activeAiRevision;
  int _aiGeneration = 0;
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
  Object? get aiError => _aiError;
  DrawOffer? get pendingDrawOffer => _pendingDrawOffer;
  GameConfiguration get configuration => _configuration;
  AiTurnStatus get aiTurnStatus => _aiTurnStatus;
  bool get isAiThinking => _aiTurnStatus == AiTurnStatus.thinking;
  bool get isAiGame => _configuration.mode == GameMode.humanVsAi;
  bool get canReset => !_submitting && _sessionError == null;
  bool get canSubmitMatchAction =>
      !_submitting &&
      _sessionError == null &&
      _state.status == GameStatus.active;
  bool get canOfferDraw =>
      canSubmitMatchAction && _pendingDrawOffer == null && !isAiThinking;
  bool get canHumanInteract =>
      !_submitting &&
      !isAiThinking &&
      _pendingDrawOffer == null &&
      (_configuration.mode == GameMode.localTwoPlayer ||
          _state.activeSide == _configuration.humanSide);

  bool get captureRequired => legalMoves.any((move) => move.isCapture);

  Set<String> get selectablePieceIds => canHumanInteract
      ? Set<String>.unmodifiable(legalMoves.map((move) => move.pieceId))
      : const <String>{};

  Set<BoardPosition> get targetPositions {
    if (!canHumanInteract ||
        _selectedPieceId == null ||
        _selectedPath.isEmpty) {
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
    if (_state.status == GameStatus.completed || !canHumanInteract) {
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
          if (!_disposed) _synchronizeFromSession(clearSelection: true);
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

  Future<void> reset() => restart();

  Future<void> restart() async {
    await _startFuture;
    await _submitMatchAction(
      side: _state.activeSide,
      cancelAi: true,
      allowCompleted: true,
      createCommand: (commandId, actorId, revision) => StartNewGameCommand(
        commandId: commandId,
        actorId: actorId,
        expectedRevision: revision,
      ),
    );
  }

  Future<CommandReceipt?> resign(PlayerSide side) async {
    await _startFuture;
    return _submitMatchAction(
      side: side,
      cancelAi: true,
      createCommand: (commandId, actorId, revision) => ResignCommand(
        commandId: commandId,
        actorId: actorId,
        expectedRevision: revision,
      ),
    );
  }

  Future<CommandReceipt?> offerDraw(PlayerSide side) async {
    await _startFuture;
    if (_pendingDrawOffer != null || isAiThinking) return null;
    final receipt = await _submitMatchAction(
      side: side,
      createCommand: (commandId, actorId, revision) => OfferDrawCommand(
        commandId: commandId,
        actorId: actorId,
        expectedRevision: revision,
      ),
    );
    if (receipt?.accepted ?? false) {
      final aiSide = _configuration.aiSide;
      if (aiSide != null && _pendingDrawOffer?.side != aiSide) {
        await _respondToDraw(side: aiSide, accepted: false, allowAiActor: true);
      }
    }
    return receipt;
  }

  Future<CommandReceipt?> respondToDraw({
    required PlayerSide side,
    required bool accepted,
  }) {
    return _respondToDraw(side: side, accepted: accepted);
  }

  Future<CommandReceipt?> _respondToDraw({
    required PlayerSide side,
    required bool accepted,
    bool allowAiActor = false,
  }) async {
    await _startFuture;
    final offer = _pendingDrawOffer;
    if (offer == null ||
        offer.side == side ||
        (isAiGame && side != _configuration.humanSide && !allowAiActor)) {
      return null;
    }
    return _submitMatchAction(
      side: side,
      cancelAi: accepted,
      createCommand: (commandId, actorId, revision) => RespondToDrawCommand(
        commandId: commandId,
        actorId: actorId,
        expectedRevision: revision,
        offerCommandId: offer.commandId,
        accepted: accepted,
      ),
    );
  }

  Future<void> setGameMode(GameMode mode) async {
    await _replaceConfiguration(_configuration.copyWith(mode: mode));
  }

  Future<void> setHumanSide(PlayerSide side) async {
    await _replaceConfiguration(_configuration.copyWith(humanSide: side));
  }

  Future<void> setDifficulty(AiDifficulty difficulty) async {
    await _replaceConfiguration(
      _configuration.copyWith(difficulty: difficulty),
    );
  }

  String get statusTitle {
    final outcome = _state.outcome;
    if (outcome?.type == GameOutcomeType.draw) {
      return 'Game drawn';
    }
    if (outcome?.winner case final winner?) {
      return '${_sideLabel(winner)} wins';
    }
    if (isAiGame) {
      if (_aiTurnStatus == AiTurnStatus.thinking) {
        return 'Computer is thinking';
      }
      if (_aiTurnStatus == AiTurnStatus.error) {
        return 'Computer move failed';
      }
      if (_state.activeSide == _configuration.humanSide) {
        return 'Your turn';
      }
      return 'Computer ready';
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
        GameOutcomeReason.resignation => _resignationDetail,
        GameOutcomeReason.drawAgreement => 'Both players agreed to a draw.',
        _ => 'The game has ended.',
      };
    }
    if (isAiGame && _aiTurnStatus == AiTurnStatus.thinking) {
      return '${_configuration.difficulty.preset.label} is choosing a move.';
    }
    if (isAiGame && _aiTurnStatus == AiTurnStatus.error) {
      return 'The computer could not complete its turn. Start a new game.';
    }
    if (_selectedPieceId != null) {
      return isPathInProgress
          ? 'Continue the capture path.'
          : 'Choose a highlighted landing square.';
    }
    if (captureRequired) {
      return 'A capture is required. Select a marked piece.';
    }
    if (isAiGame && _aiTurnStatus == AiTurnStatus.moveCompleted) {
      return 'Computer move completed. Select a marked piece.';
    }
    return 'Select a marked piece to see its legal moves.';
  }

  String get aiStateLabel => switch (_aiTurnStatus) {
    AiTurnStatus.ready => 'Ready',
    AiTurnStatus.thinking => 'Thinking',
    AiTurnStatus.moveCompleted => 'Move completed',
    AiTurnStatus.error => 'Error',
  };

  String get _resignationDetail {
    final winner = _state.outcome?.winner;
    if (winner == null) return 'The match ended by resignation.';
    final resignedSide = _opposite(winner);
    if (!isAiGame) return '${_sideLabel(resignedSide)} resigned.';
    return resignedSide == _configuration.humanSide
        ? 'You resigned.'
        : 'The computer resigned.';
  }

  String get matchResultLabel {
    final outcome = _state.outcome;
    if (outcome == null) return '';
    if (outcome.type == GameOutcomeType.draw) return 'Draw';
    final winner = outcome.winner!;
    if (!isAiGame) return '${_sideLabel(winner)} wins';
    return winner == _configuration.humanSide ? 'You win' : 'Computer wins';
  }

  String get sideResultLabel {
    final outcome = _state.outcome;
    if (outcome == null) return '';
    if (outcome.type == GameOutcomeType.draw) {
      return isAiGame ? 'You and the computer drew.' : 'Dark and Light drew.';
    }
    final winner = outcome.winner!;
    if (!isAiGame) {
      return '${_sideLabel(winner)} won · ${_sideLabel(_opposite(winner))} lost';
    }
    final humanWon = winner == _configuration.humanSide;
    return humanWon
        ? 'Your ${_sideLabel(winner)} side won.'
        : 'Your ${_sideLabel(_configuration.humanSide)} side lost.';
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
    if (_disposed) return;
    if (update is MoveCommitted ||
        update is StateReplaced ||
        update is DrawOffered ||
        update is DrawOfferResolved) {
      _synchronizeFromSession(clearSelection: true);
    }
  }

  Future<void> _startSession() async {
    try {
      await _session.start();
      _synchronizeFromSession(clearSelection: true);
      _scheduleAiTurn();
    } catch (error) {
      _sessionError = error;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  void _synchronizeFromSession({required bool clearSelection}) {
    if (_disposed) return;
    final nextState = _session.currentState;
    final nextDrawOffer = _session.pendingDrawOffer;
    final stateChanged = !identical(_state, nextState);
    final drawOfferChanged = !identical(_pendingDrawOffer, nextDrawOffer);
    if ((stateChanged || drawOfferChanged) &&
        isAiThinking &&
        !_submitting &&
        (nextState.status == GameStatus.completed ||
            nextState.revision != _activeAiRevision ||
            nextDrawOffer != null)) {
      _cancelAiTurn(notify: false);
    }
    final selectionChanged =
        clearSelection &&
        (_selectedPieceId != null || _selectedPath.isNotEmpty);
    _state = nextState;
    _legalMoves = _session.legalMoves;
    _pendingDrawOffer = nextDrawOffer;
    if (clearSelection) {
      _clearSelection(notify: false);
    }
    if (stateChanged || drawOfferChanged || selectionChanged) {
      notifyListeners();
    }
    _scheduleAiTurn();
  }

  Future<void> _replaceConfiguration(GameConfiguration next) async {
    await _startFuture;
    if (_disposed ||
        _submitting ||
        (next.mode == _configuration.mode &&
            next.humanSide == _configuration.humanSide &&
            next.difficulty == _configuration.difficulty)) {
      return;
    }
    _cancelAiTurn(notify: false);
    _configuration = next;
    _aiError = null;
    _aiTurnStatus = AiTurnStatus.ready;
    notifyListeners();
    await reset();
  }

  void _scheduleAiTurn() {
    final aiSide = _configuration.aiSide;
    if (_disposed ||
        aiSide == null ||
        _state.status == GameStatus.completed ||
        _pendingDrawOffer != null ||
        _state.activeSide != aiSide ||
        _submitting ||
        _aiTurnStatus == AiTurnStatus.error ||
        _activeAiRevision == _state.revision) {
      return;
    }
    _activeAiRevision = _state.revision;
    _aiGeneration += 1;
    final generation = _aiGeneration;
    final state = _state;
    final legalMoves = List<Move>.unmodifiable(_legalMoves);
    _aiError = null;
    _aiTurnStatus = AiTurnStatus.thinking;
    _clearSelection(notify: false);
    notifyListeners();
    unawaited(_runAiTurn(generation, state, legalMoves));
  }

  Future<void> _runAiTurn(
    int generation,
    GameState searchedState,
    List<Move> searchedMoves,
  ) async {
    try {
      final result = await _aiTurnRunner.chooseMove(
        difficulty: _configuration.difficulty,
        state: searchedState,
        legalMoves: searchedMoves,
      );
      if (!_isCurrentAiTurn(generation, searchedState)) return;
      final currentMove = _legalMoves
          .where((move) => move.id == result.move.id)
          .firstOrNull;
      if (currentMove == null) {
        throw StateError('AI returned a move that is no longer legal.');
      }
      _submitting = true;
      final receipt = await _session.submit(
        SubmitMoveCommand(
          commandId: _nextCommandId('ai-move'),
          actorId: _actorIdsBySide[searchedState.activeSide]!,
          expectedRevision: searchedState.revision,
          move: currentMove,
        ),
      );
      if (!receipt.accepted) {
        throw StateError('AI move was rejected: ${receipt.rejection}.');
      }
      _lastCommandReceipt = receipt;
      if (generation == _aiGeneration && !_disposed) {
        _aiTurnStatus = AiTurnStatus.moveCompleted;
      }
    } on AiSearchCancelledException {
      return;
    } catch (error) {
      if (generation != _aiGeneration || _disposed) return;
      _aiError = error;
      _aiTurnStatus = AiTurnStatus.error;
    } finally {
      if (generation == _aiGeneration && !_disposed) {
        _submitting = false;
        _activeAiRevision = null;
        _synchronizeFromSession(clearSelection: true);
        notifyListeners();
      }
    }
  }

  bool _isCurrentAiTurn(int generation, GameState searchedState) {
    return !_disposed &&
        generation == _aiGeneration &&
        _configuration.aiSide == searchedState.activeSide &&
        _pendingDrawOffer == null &&
        _state.status == GameStatus.active &&
        _state.revision == searchedState.revision &&
        _state.activeSide == searchedState.activeSide;
  }

  void _cancelAiTurn({required bool notify}) {
    _aiGeneration += 1;
    _activeAiRevision = null;
    _aiTurnRunner.cancel();
    final changed = _aiTurnStatus != AiTurnStatus.ready || _aiError != null;
    _aiTurnStatus = AiTurnStatus.ready;
    _aiError = null;
    if (changed && notify && !_disposed) notifyListeners();
  }

  Future<CommandReceipt?> _submitMatchAction({
    required PlayerSide side,
    required GameCommand Function(
      String commandId,
      String actorId,
      int revision,
    )
    createCommand,
    bool cancelAi = false,
    bool allowCompleted = false,
  }) async {
    if (_disposed ||
        _sessionError != null ||
        _submitting ||
        (!allowCompleted && _state.status == GameStatus.completed)) {
      return null;
    }
    if (cancelAi) _cancelAiTurn(notify: false);
    _submitting = true;
    notifyListeners();
    try {
      final commandId = _nextCommandId('match-action');
      final receipt = await _session.submit(
        createCommand(commandId, _actorIdsBySide[side]!, _state.revision),
      );
      _lastCommandReceipt = receipt;
      return receipt;
    } finally {
      _submitting = false;
      if (!_disposed) {
        _synchronizeFromSession(clearSelection: true);
        notifyListeners();
      }
    }
  }

  String _nextCommandId(String kind) {
    _commandNumber += 1;
    return '${_session.id}-$kind-$_commandNumber';
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelAiTurn(notify: false);
    if (closeAiTurnRunnerOnDispose) {
      _aiTurnRunner.dispose();
    }
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

  static PlayerSide _opposite(PlayerSide side) {
    return side == PlayerSide.dark ? PlayerSide.light : PlayerSide.dark;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
