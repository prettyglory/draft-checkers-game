import 'dart:math' as math;

import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/game/presentation/checkers_board.dart';
import 'package:draft_game/features/game/presentation/game_board_view_model.dart';
import 'package:flutter/material.dart';

class GameBoardScreen extends StatefulWidget {
  const GameBoardScreen({this.initialState, this.viewModel, super.key})
    : assert(initialState == null || viewModel == null);

  final GameState? initialState;
  final GameBoardViewModel? viewModel;

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  late final GameBoardViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel =
        widget.viewModel ??
        GameBoardViewModel(initialState: widget.initialState);
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
    return Scaffold(
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
                        )
                      : _PhoneGameLayout(
                          key: const Key('phone-game-layout'),
                          viewModel: _viewModel,
                          maxWidth: constraints.maxWidth,
                        );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WideGameLayout extends StatelessWidget {
  const _WideGameLayout({
    required this.viewModel,
    required this.constraints,
    super.key,
  });

  final GameBoardViewModel viewModel;
  final BoxConstraints constraints;

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
                child: CheckersBoard(viewModel: viewModel),
              ),
            ),
          ),
          const SizedBox(width: 28),
          SizedBox(
            width: 330,
            child: SingleChildScrollView(
              child: _GameInformation(viewModel: viewModel),
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
    super.key,
  });

  final GameBoardViewModel viewModel;
  final double maxWidth;

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
                child: CheckersBoard(viewModel: viewModel),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: _GameInformation(viewModel: viewModel, includeHeader: false),
        ),
      ],
    );
  }
}

class _GameInformation extends StatelessWidget {
  const _GameInformation({required this.viewModel, this.includeHeader = true});

  final GameBoardViewModel viewModel;
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
        Semantics(
          container: true,
          liveRegion: true,
          label: '${viewModel.statusTitle}. ${viewModel.statusDetail}',
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.25),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      viewModel.statusTitle,
                      key: const Key('game-status-title'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      viewModel.statusDetail,
                      key: const Key('game-status-detail'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
        Text(
          'How to play',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Select a ringed piece, then choose a marked landing. '
          'Numbered markers guide every step of a multiple capture.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          key: const Key('new-game-button'),
          onPressed: viewModel.reset,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('New game'),
        ),
      ],
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
                    'Phase 4 · Playable board',
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
          'American Checkers · Local board',
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
