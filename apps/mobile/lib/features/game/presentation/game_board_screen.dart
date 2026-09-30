import 'dart:async';
import 'dart:math' as math;

import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/game/application/ai_turn_runner.dart';
import 'package:draft_game/features/game/application/game_configuration.dart';
import 'package:draft_game/features/game/presentation/checkers_board.dart';
import 'package:draft_game/features/game/presentation/game_board_view_model.dart';
import 'package:draft_game/features/settings/domain/player_settings.dart';
import 'package:flutter/material.dart';
import 'package:game_session/game_session.dart';

const _darkActorId = 'local-dark';
const _lightActorId = 'local-light';

typedef AiTurnRunnerFactory = AiTurnRunner Function();

GameBoardViewModel _createLocalViewModel(
  String sessionId,
  GameState? initialState,
  GameConfiguration configuration,
  AiTurnRunnerFactory? aiTurnRunnerFactory,
) {
  final engine = configuration.ruleset.createEngine();
  final session = InProcessGameSession(
    id: sessionId,
    rulesEngine: engine,
    initialState: initialState ?? engine.createInitialState(),
    actorSides: const <String, PlayerSide>{
      _darkActorId: PlayerSide.dark,
      _lightActorId: PlayerSide.light,
    },
  );
  return GameBoardViewModel(
    session: session,
    actorIdsBySide: const <PlayerSide, String>{
      PlayerSide.dark: _darkActorId,
      PlayerSide.light: _lightActorId,
    },
    configuration: configuration,
    aiTurnRunner: aiTurnRunnerFactory?.call(),
  );
}

class GameBoardScreen extends StatefulWidget {
  const GameBoardScreen({
    this.initialState,
    this.viewModel,
    this.configuration = const GameConfiguration(),
    this.preferences = PlayerSettings.defaults,
    this.aiTurnRunnerFactory,
    super.key,
  }) : assert(initialState == null || viewModel == null),
       assert(aiTurnRunnerFactory == null || viewModel == null);

  final GameState? initialState;
  final GameBoardViewModel? viewModel;
  final GameConfiguration configuration;
  final PlayerSettings preferences;
  final AiTurnRunnerFactory? aiTurnRunnerFactory;

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  late GameBoardViewModel _viewModel;
  late final bool _ownsViewModel;
  int _matchNumber = 1;
  bool _rematching = false;
  bool _dialogOpen = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ?? _createOwnedViewModel(widget.initialState);
  }

  @override
  void dispose() {
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_confirmBackToSetup());
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainer,
              ],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _viewModel,
              builder: (context, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final wide =
                        constraints.maxWidth >= 820 &&
                        constraints.maxHeight >= 620;
                    return wide
                        ? _WideGameLayout(
                            key: const Key('wide-game-layout'),
                            viewModel: _viewModel,
                            constraints: constraints,
                            onRestart: _confirmRestart,
                            onRematch: _ownsViewModel ? _rematch : null,
                            onBackToSetup: _confirmBackToSetup,
                            onResign: _confirmResignation,
                            rotateBoard: _rotateBoard,
                            largerLabels: widget.preferences.largerText,
                          )
                        : _PhoneGameLayout(
                            key: const Key('phone-game-layout'),
                            viewModel: _viewModel,
                            maxWidth: constraints.maxWidth,
                            onRestart: _confirmRestart,
                            onRematch: _ownsViewModel ? _rematch : null,
                            onBackToSetup: _confirmBackToSetup,
                            onResign: _confirmResignation,
                            rotateBoard: _rotateBoard,
                            largerLabels: widget.preferences.largerText,
                          );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  GameBoardViewModel _createOwnedViewModel(GameState? initialState) {
    return _createLocalViewModel(
      'local-game-$_matchNumber',
      initialState,
      widget.configuration,
      widget.aiTurnRunnerFactory,
    );
  }

  Future<void> _confirmRestart() async {
    if (_dialogOpen || !mounted) return;
    if (!widget.preferences.confirmBeforeRestart) {
      await _viewModel.restart();
      return;
    }
    _dialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart current match?'),
        content: const Text(
          'The current position and result will be cleared. Your match settings will stay the same.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-restart-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (confirmed ?? false) await _viewModel.restart();
  }

  Future<void> _confirmResignation() async {
    if (_dialogOpen || !mounted || !viewModelActive) return;
    if (!widget.preferences.confirmBeforeResign) {
      final side = _viewModel.isAiGame
          ? _viewModel.configuration.humanSide
          : _viewModel.state.activeSide;
      await _viewModel.resign(side);
      return;
    }
    _dialogOpen = true;
    final side = await showDialog<PlayerSide>(
      context: context,
      builder: (context) {
        final configuration = _viewModel.configuration;
        if (configuration.mode == GameMode.humanVsAi) {
          final humanSide = configuration.humanSide;
          return AlertDialog(
            title: const Text('Resign match?'),
            content: Text(
              '${_sideLabel(humanSide)} will resign and the computer will win.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('confirm-resign-button'),
                onPressed: () => Navigator.of(context).pop(humanSide),
                child: const Text('Resign'),
              ),
            ],
          );
        }
        return AlertDialog(
          title: const Text('Which side resigns?'),
          content: const Text('The other side will immediately win the match.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('resign-dark-button'),
              onPressed: () => Navigator.of(context).pop(PlayerSide.dark),
              child: const Text('Dark resigns'),
            ),
            FilledButton(
              key: const Key('resign-light-button'),
              onPressed: () => Navigator.of(context).pop(PlayerSide.light),
              child: const Text('Light resigns'),
            ),
          ],
        );
      },
    );
    _dialogOpen = false;
    if (side != null) await _viewModel.resign(side);
  }

  Future<void> _confirmBackToSetup() async {
    if (_dialogOpen || !mounted) return;
    var leave = true;
    if (viewModelActive) {
      _dialogOpen = true;
      leave =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Leave active match?'),
              content: const Text(
                'This match will end and cannot be resumed. Your setup selections will remain available.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Stay'),
                ),
                FilledButton(
                  key: const Key('confirm-leave-button'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Leave match'),
                ),
              ],
            ),
          ) ??
          false;
      _dialogOpen = false;
    }
    if (leave && mounted) {
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final popped = await Navigator.of(context).maybePop();
      if (!popped && mounted) setState(() => _allowPop = false);
    }
  }

  Future<void> _rematch() async {
    if (_rematching || !_ownsViewModel) return;
    _rematching = true;
    final previous = _viewModel;
    _matchNumber += 1;
    _viewModel = _createOwnedViewModel(null);
    previous.dispose();
    if (mounted) setState(() {});
    await Future<void>.delayed(Duration.zero);
    _rematching = false;
  }

  bool get viewModelActive =>
      _viewModel.state.status == GameStatus.active &&
      _viewModel.canSubmitMatchAction;

  bool get _rotateBoard {
    return switch (widget.preferences.boardOrientation) {
      BoardOrientationPreference.automatic =>
        _viewModel.isAiGame &&
            _viewModel.configuration.humanSide == PlayerSide.dark,
      BoardOrientationPreference.darkAtBottom => true,
      BoardOrientationPreference.lightAtBottom => false,
    };
  }
}

String _sideLabel(PlayerSide side) {
  return side == PlayerSide.dark ? 'Dark' : 'Light';
}

class _WideGameLayout extends StatelessWidget {
  const _WideGameLayout({
    required this.viewModel,
    required this.constraints,
    required this.onRestart,
    required this.onRematch,
    required this.onBackToSetup,
    required this.onResign,
    required this.rotateBoard,
    required this.largerLabels,
    super.key,
  });

  final GameBoardViewModel viewModel;
  final BoxConstraints constraints;
  final VoidCallback onRestart;
  final VoidCallback? onRematch;
  final VoidCallback onBackToSetup;
  final VoidCallback onResign;
  final bool rotateBoard;
  final bool largerLabels;

  @override
  Widget build(BuildContext context) {
    final boardDimension = math.max(
      384.0,
      math.min(
        680.0,
        math.min(constraints.maxHeight - 48, constraints.maxWidth - 406),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Center(
              child: SizedBox.square(
                dimension: boardDimension,
                child: CheckersBoard(
                  viewModel: viewModel,
                  rotateBoard: rotateBoard,
                  largerLabels: largerLabels,
                ),
              ),
            ),
          ),
          const SizedBox(width: 28),
          SizedBox(
            width: 330,
            child: SingleChildScrollView(
              child: _GameInformation(
                viewModel: viewModel,
                onRestart: onRestart,
                onRematch: onRematch,
                onBackToSetup: onBackToSetup,
                onResign: onResign,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneGameLayout extends StatelessWidget {
  const _PhoneGameLayout({
    required this.viewModel,
    required this.maxWidth,
    required this.onRestart,
    required this.onRematch,
    required this.onBackToSetup,
    required this.onResign,
    required this.rotateBoard,
    required this.largerLabels,
    super.key,
  });

  final GameBoardViewModel viewModel;
  final double maxWidth;
  final VoidCallback onRestart;
  final VoidCallback? onRematch;
  final VoidCallback onBackToSetup;
  final VoidCallback onResign;
  final bool rotateBoard;
  final bool largerLabels;

  @override
  Widget build(BuildContext context) {
    final boardDimension = math.max(384.0, math.min(620.0, maxWidth));

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: _GameHeader(compact: true),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(maxWidth, boardDimension),
            height: boardDimension,
            child: Center(
              child: SizedBox.square(
                dimension: boardDimension,
                child: CheckersBoard(
                  viewModel: viewModel,
                  rotateBoard: rotateBoard,
                  largerLabels: largerLabels,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: _GameInformation(
            viewModel: viewModel,
            includeHeader: false,
            onRestart: onRestart,
            onRematch: onRematch,
            onBackToSetup: onBackToSetup,
            onResign: onResign,
          ),
        ),
      ],
    );
  }
}

class _GameInformation extends StatelessWidget {
  const _GameInformation({
    required this.viewModel,
    required this.onRestart,
    required this.onRematch,
    required this.onBackToSetup,
    required this.onResign,
    this.includeHeader = true,
  });

  final GameBoardViewModel viewModel;
  final VoidCallback onRestart;
  final VoidCallback? onRematch;
  final VoidCallback onBackToSetup;
  final VoidCallback onResign;
  final bool includeHeader;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;
    final lightCount = state.board.piecesFor(PlayerSide.light).length;
    final darkCount = state.board.piecesFor(PlayerSide.dark).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (includeHeader) ...<Widget>[
          const _GameHeader(),
          const SizedBox(height: 28),
        ],
        if (state.status == GameStatus.completed)
          _GameOverCard(
            viewModel: viewModel,
            onRematch: onRematch,
            onBackToSetup: onBackToSetup,
          )
        else
          _StatusCard(viewModel: viewModel),
        if (viewModel.captureRequired &&
            state.status == GameStatus.active) ...<Widget>[
          const SizedBox(height: 12),
          Semantics(
            label: 'Capture required',
            child: Container(
              key: const Key('capture-required-banner'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.priority_high_rounded,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Capture required',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: _PieceCount(label: 'Dark', count: darkCount, dark: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PieceCount(
                label: 'Light',
                count: lightCount,
                dark: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _MatchSummary(configuration: viewModel.configuration),
        if (state.status == GameStatus.active) ...<Widget>[
          const SizedBox(height: 18),
          _MatchActions(
            viewModel: viewModel,
            onRestart: onRestart,
            onBackToSetup: onBackToSetup,
            onResign: onResign,
          ),
        ],
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.viewModel});

  final GameBoardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '${viewModel.statusTitle}. ${viewModel.statusDetail}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  viewModel.statusTitle,
                  key: const Key('game-status-title'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  viewModel.statusDetail,
                  key: const Key('game-status-detail'),
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameOverCard extends StatelessWidget {
  const _GameOverCard({
    required this.viewModel,
    required this.onRematch,
    required this.onBackToSetup,
  });

  final GameBoardViewModel viewModel;
  final VoidCallback? onRematch;
  final VoidCallback onBackToSetup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final configuration = viewModel.configuration;
    final details = <String>[
      viewModel.sideResultLabel,
      viewModel.statusDetail,
      '${viewModel.state.ply} plies played',
      if (configuration.mode == GameMode.humanVsAi)
        '${configuration.difficulty.preset.label} computer',
    ];
    return Semantics(
      key: const Key('game-over-card'),
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(
                viewModel.state.outcome?.type == GameOutcomeType.draw
                    ? Icons.handshake_rounded
                    : Icons.emoji_events_rounded,
                color: scheme.primary,
                size: 34,
              ),
              const SizedBox(height: 10),
              Text(
                viewModel.matchResultLabel,
                key: const Key('game-over-result'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              for (final detail in details) ...<Widget>[
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('rematch-button'),
                onPressed: onRematch,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Rematch'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('game-over-setup-button'),
                onPressed: onBackToSetup,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchActions extends StatelessWidget {
  const _MatchActions({
    required this.viewModel,
    required this.onRestart,
    required this.onBackToSetup,
    required this.onResign,
  });

  final GameBoardViewModel viewModel;
  final VoidCallback onRestart;
  final VoidCallback onBackToSetup;
  final VoidCallback onResign;

  @override
  Widget build(BuildContext context) {
    final offer = viewModel.pendingDrawOffer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Match actions',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (offer != null)
          _DrawOfferCard(viewModel: viewModel, offer: offer)
        else
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('offer-draw-button'),
                  onPressed: viewModel.canOfferDraw
                      ? () => viewModel.offerDraw(
                          viewModel.isAiGame
                              ? viewModel.configuration.humanSide
                              : viewModel.state.activeSide,
                        )
                      : null,
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('Offer draw'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('resign-button'),
                  onPressed: viewModel.canSubmitMatchAction ? onResign : null,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Resign'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('restart-match-button'),
          onPressed: viewModel.canReset ? onRestart : null,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Restart current match'),
        ),
        TextButton.icon(
          key: const Key('leave-match-button'),
          onPressed: onBackToSetup,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to match setup'),
        ),
      ],
    );
  }
}

class _DrawOfferCard extends StatelessWidget {
  const _DrawOfferCard({required this.viewModel, required this.offer});

  final GameBoardViewModel viewModel;
  final DrawOffer offer;

  @override
  Widget build(BuildContext context) {
    final responseSide = offer.side == PlayerSide.dark
        ? PlayerSide.light
        : PlayerSide.dark;
    final canHumanRespond =
        !viewModel.isAiGame ||
        responseSide == viewModel.configuration.humanSide;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('draw-offer-card'),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${_sideLabel(offer.side)} offered a draw',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (!canHumanRespond)
              Text(
                'The computer is responding.',
                style: TextStyle(color: scheme.onTertiaryContainer),
              )
            else
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('decline-draw-button'),
                      onPressed: viewModel.canSubmitMatchAction
                          ? () => viewModel.respondToDraw(
                              side: responseSide,
                              accepted: false,
                            )
                          : null,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('accept-draw-button'),
                      onPressed: viewModel.canSubmitMatchAction
                          ? () => viewModel.respondToDraw(
                              side: responseSide,
                              accepted: true,
                            )
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MatchSummary extends StatelessWidget {
  const _MatchSummary({required this.configuration});

  final GameConfiguration configuration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Current match',
              key: const Key('current-match-summary'),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Icon(
                  configuration.mode == GameMode.localTwoPlayer
                      ? Icons.people_alt_rounded
                      : Icons.memory_rounded,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    configuration.mode == GameMode.localTwoPlayer
                        ? 'Human vs Human'
                        : 'Human vs AI · ${configuration.difficulty.preset.label}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            if (configuration.mode == GameMode.humanVsAi) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'You play ${configuration.humanSide == PlayerSide.dark ? 'Dark' : 'Light'} · AI: ${configuration.aiSide == PlayerSide.dark ? 'Dark' : 'Light'}',
                key: const Key('match-side-summary'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.grid_view_rounded,
                  size: 17,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Phase 6 · Computer play',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: compact ? 12 : 16),
        Semantics(
          header: true,
          child: Text(
            'Draft Game',
            style:
                (compact
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.displaySmall)
                    ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'American Checkers · Local and computer play',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _PieceCount extends StatelessWidget {
  const _PieceCount({
    required this.label,
    required this.count,
    required this.dark,
  });

  final String label;
  final int count;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label has $count pieces',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark
                      ? const Color(0xFF17221F)
                      : const Color(0xFFF9F2E6),
                  border: Border.all(
                    color: dark
                        ? const Color(0xFFEBCB77)
                        : const Color(0xFF284E43),
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
