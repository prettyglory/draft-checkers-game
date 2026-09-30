import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/game/application/game_configuration.dart';
import 'package:draft_game/features/game/application/match_setup_view_model.dart';
import 'package:draft_game/features/game/presentation/game_board_screen.dart';
import 'package:flutter/material.dart';

typedef MatchBoardBuilder = Widget Function(GameConfiguration configuration);

class MatchSetupScreen extends StatefulWidget {
  const MatchSetupScreen({this.viewModel, this.boardBuilder, super.key});

  final MatchSetupViewModel? viewModel;
  final MatchBoardBuilder? boardBuilder;

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  late final MatchSetupViewModel _viewModel;
  late final bool _ownsViewModel;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ?? MatchSetupViewModel();
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
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
                  if (constraints.maxWidth >= 800) {
                    return _TabletSetupLayout(
                      viewModel: _viewModel,
                      starting: _starting,
                      onStartGame: _startGame,
                    );
                  }
                  return _PhoneSetupLayout(
                    viewModel: _viewModel,
                    starting: _starting,
                    onStartGame: _startGame,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _startGame() async {
    final configuration = _viewModel.configuration;
    if (configuration == null || _starting) return;
    setState(() => _starting = true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            widget.boardBuilder?.call(configuration) ??
            GameBoardScreen(configuration: configuration),
      ),
    );
    if (mounted) setState(() => _starting = false);
  }
}

class _PhoneSetupLayout extends StatelessWidget {
  const _PhoneSetupLayout({
    required this.viewModel,
    required this.starting,
    required this.onStartGame,
  });

  final MatchSetupViewModel viewModel;
  final bool starting;
  final VoidCallback onStartGame;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('phone-setup-layout'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: <Widget>[
        const _SetupIntroduction(),
        const SizedBox(height: 24),
        _SetupCard(
          viewModel: viewModel,
          starting: starting,
          onStartGame: onStartGame,
        ),
      ],
    );
  }
}

class _TabletSetupLayout extends StatelessWidget {
  const _TabletSetupLayout({
    required this.viewModel,
    required this.starting,
    required this.onStartGame,
  });

  final MatchSetupViewModel viewModel;
  final bool starting;
  final VoidCallback onStartGame;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        key: const Key('tablet-setup-layout'),
        padding: const EdgeInsets.all(40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const Expanded(child: _SetupIntroduction(expanded: true)),
              const SizedBox(width: 56),
              SizedBox(
                width: 440,
                child: _SetupCard(
                  viewModel: viewModel,
                  starting: starting,
                  onStartGame: onStartGame,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupIntroduction extends StatelessWidget {
  const _SetupIntroduction({this.expanded = false});

  final bool expanded;

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
            child: Text(
              'MATCH SETUP',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
        SizedBox(height: expanded ? 24 : 16),
        Semantics(
          header: true,
          child: Text(
            'Draft Game',
            style:
                (expanded
                        ? Theme.of(context).textTheme.displaySmall
                        : Theme.of(context).textTheme.headlineLarge)
                    ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Choose how you want to play, then begin a fresh American Checkers match.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (expanded) ...<Widget>[
          const SizedBox(height: 30),
          _FeatureLine(
            icon: Icons.verified_user_outlined,
            text: 'Every move is validated by the game session.',
          ),
          const SizedBox(height: 14),
          _FeatureLine(
            icon: Icons.memory_rounded,
            text: 'Computer turns run away from the interface.',
          ),
          const SizedBox(height: 14),
          _FeatureLine(
            icon: Icons.restart_alt_rounded,
            text: 'Restarting keeps these match settings.',
          ),
        ],
      ],
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.viewModel,
    required this.starting,
    required this.onStartGame,
  });

  final MatchSetupViewModel viewModel;
  final bool starting;
  final VoidCallback onStartGame;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Configure match',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            Text('Game mode', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<GameMode>(
              key: const Key('setup-mode-selector'),
              showSelectedIcon: false,
              segments: const <ButtonSegment<GameMode>>[
                ButtonSegment<GameMode>(
                  value: GameMode.localTwoPlayer,
                  icon: Icon(Icons.people_alt_rounded),
                  label: Text('Two players'),
                ),
                ButtonSegment<GameMode>(
                  value: GameMode.humanVsAi,
                  icon: Icon(Icons.memory_rounded),
                  label: Text('Computer'),
                ),
              ],
              selected: viewModel.mode == null
                  ? const <GameMode>{}
                  : <GameMode>{viewModel.mode!},
              emptySelectionAllowed: true,
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) viewModel.setMode(selection.single);
              },
            ),
            if (viewModel.mode == GameMode.humanVsAi) ...<Widget>[
              const SizedBox(height: 20),
              Text('Your side', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<PlayerSide>(
                key: const Key('setup-side-selector'),
                showSelectedIcon: false,
                segments: const <ButtonSegment<PlayerSide>>[
                  ButtonSegment<PlayerSide>(
                    value: PlayerSide.dark,
                    label: Text('Dark'),
                  ),
                  ButtonSegment<PlayerSide>(
                    value: PlayerSide.light,
                    label: Text('Light'),
                  ),
                ],
                selected: viewModel.humanSide == null
                    ? const <PlayerSide>{}
                    : <PlayerSide>{viewModel.humanSide!},
                emptySelectionAllowed: true,
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    viewModel.setHumanSide(selection.single);
                  }
                },
              ),
              const SizedBox(height: 20),
              Text('Difficulty', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                key: const Key('setup-difficulty-selector'),
                spacing: 8,
                runSpacing: 8,
                children: AiDifficulty.values
                    .map(
                      (difficulty) => ChoiceChip(
                        key: ValueKey<String>('difficulty-${difficulty.name}'),
                        label: Text(difficulty.preset.label),
                        selected: viewModel.difficulty == difficulty,
                        onSelected: (_) => viewModel.setDifficulty(difficulty),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 20),
            Semantics(
              label: 'Ruleset: ${viewModel.ruleset.label}',
              child: ListTile(
                key: const Key('setup-ruleset'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                tileColor: scheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const Icon(Icons.grid_view_rounded),
                title: Text(viewModel.ruleset.label),
                subtitle: const Text('8 × 8 · 12 pieces per side'),
              ),
            ),
            const SizedBox(height: 22),
            Semantics(
              button: true,
              enabled: viewModel.canStart && !starting,
              label: starting
                  ? 'Starting game'
                  : viewModel.canStart
                  ? 'Start game'
                  : 'Start game unavailable until setup is complete',
              child: ElevatedButton.icon(
                key: const Key('start-game-button'),
                onPressed: viewModel.canStart && !starting ? onStartGame : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Game'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
