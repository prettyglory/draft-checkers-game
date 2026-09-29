import 'dart:io';

import 'package:checkers_ai/checkers_ai.dart';
import 'package:checkers_engine/checkers_engine.dart';

const _engine = AmericanCheckersRulesEngine();

Future<void> main(List<String> arguments) async {
  final depth = _parseDepth(arguments);
  final maxNodes = _parseMaxNodes(arguments);
  final results = <_BenchmarkResult>[];

  for (final fixture in _fixtures()) {
    final fixtureResults = <_BenchmarkResult>[];
    for (final configuration in _configurations()) {
      fixtureResults.add(
        await _runBenchmark(
          fixture,
          configuration,
          depth: depth,
          maxNodes: maxNodes,
        ),
      );
    }
    _checkCorrectness(fixtureResults);
    results.addAll(fixtureResults);
  }

  stdout.writeln(_BenchmarkResult.csvHeader);
  for (final result in results) {
    stdout.writeln(result.toCsv());
  }
  if (results.any((result) => result.completed && !result.matchesReference)) {
    stderr.writeln('One or more completed searches failed correctness checks.');
    exitCode = 1;
  }
}

int _parseDepth(List<String> arguments) {
  return _parsePositiveOption(arguments, '--depth=') ?? 5;
}

int? _parseMaxNodes(List<String> arguments) {
  return _parsePositiveOption(arguments, '--max-nodes=');
}

int? _parsePositiveOption(List<String> arguments, String prefix) {
  final argument = arguments
      .where((value) => value.startsWith(prefix))
      .firstOrNull;
  if (argument == null) return null;
  final value = int.tryParse(argument.substring(prefix.length));
  if (value == null || value <= 0) {
    throw ArgumentError.value(
      argument,
      prefix.substring(2, prefix.length - 1),
      'Must be a positive integer.',
    );
  }
  return value;
}

Future<_BenchmarkResult> _runBenchmark(
  _BenchmarkFixture fixture,
  _BenchmarkConfiguration configuration, {
  required int depth,
  required int? maxNodes,
}) async {
  final legalMoves = _engine.legalMoves(fixture.state);
  if (legalMoves.isEmpty) {
    throw StateError('Benchmark fixture ${fixture.name} has no legal moves.');
  }
  final request = AiSearchRequest(
    state: fixture.state,
    legalMoves: legalMoves,
    budget: SearchBudget(maxDepth: depth, maxNodes: maxNodes),
  );
  final table = TranspositionTable(
    maxEntries: configuration.useTranspositionTable ? 10000 : 0,
  );
  final moveOrdering = MoveOrdering(
    useTacticalOrdering: configuration.useMoveOrdering,
  );
  final evaluator = PositionEvaluator(
    rulesEngine: _engine,
    endgameWeights: configuration.useEndgameEvaluation
        ? EndgameEvaluationWeights()
        : null,
  );
  late final AiSearchResult result;
  int? exactScore;
  var fixedVerificationMatches = true;

  if (configuration.useIterativeDeepening) {
    result = await IterativeDeepeningStrategy(
      rulesEngine: _engine,
      evaluator: evaluator,
      moveOrdering: moveOrdering,
      transpositionTable: table,
      maxQuiescenceDepth: configuration.useQuiescence ? 8 : 0,
      aspirationWindow: configuration.useAspirationWindows
          ? AspirationWindowConfig()
          : AspirationWindowConfig.disabled(),
      usePrincipalVariationSearch: configuration.usePrincipalVariationSearch,
      useKillerHistoryHeuristics: configuration.useKillerHistoryHeuristics,
      lateMoveReductions: configuration.useLateMoveReductions
          ? LateMoveReductionConfig()
          : LateMoveReductionConfig.disabled(),
    ).chooseMove(request);
    final verification =
        await FixedDepthAlphaBetaStrategy(
          rulesEngine: _engine,
          evaluator: evaluator,
          moveOrdering: moveOrdering,
          transpositionTable: TranspositionTable(
            maxEntries: configuration.useTranspositionTable ? 10000 : 0,
          ),
          maxQuiescenceDepth: configuration.useQuiescence ? 8 : 0,
          usePrincipalVariationSearch:
              configuration.usePrincipalVariationSearch,
          useKillerHistoryHeuristics: configuration.useKillerHistoryHeuristics,
          lateMoveReductions: configuration.useLateMoveReductions
              ? LateMoveReductionConfig()
              : LateMoveReductionConfig.disabled(),
        ).searchWithWindow(
          request,
          alpha: FixedDepthAlphaBetaStrategy.minimumScore,
          beta: FixedDepthAlphaBetaStrategy.maximumScore,
        );
    final verificationCompleted =
        verification.bound == TranspositionBound.exact &&
        verification.result.metadata.completedDepth == depth;
    fixedVerificationMatches =
        verificationCompleted && verification.result.move.id == result.move.id;
    if (verificationCompleted) {
      exactScore = verification.score;
    }
  } else {
    final outcome =
        await FixedDepthAlphaBetaStrategy(
          rulesEngine: _engine,
          evaluator: evaluator,
          moveOrdering: moveOrdering,
          transpositionTable: table,
          maxQuiescenceDepth: configuration.useQuiescence ? 8 : 0,
          usePrincipalVariationSearch:
              configuration.usePrincipalVariationSearch,
          useKillerHistoryHeuristics: configuration.useKillerHistoryHeuristics,
          lateMoveReductions: configuration.useLateMoveReductions
              ? LateMoveReductionConfig()
              : LateMoveReductionConfig.disabled(),
        ).searchWithWindow(
          request,
          alpha: FixedDepthAlphaBetaStrategy.minimumScore,
          beta: FixedDepthAlphaBetaStrategy.maximumScore,
        );
    result = outcome.result;
    if (outcome.bound == TranspositionBound.exact &&
        result.metadata.completedDepth == depth) {
      exactScore = outcome.score;
    }
  }

  return _BenchmarkResult(
    fixture: fixture.name,
    configuration: configuration.name,
    evaluator: configuration.useEndgameEvaluation
        ? 'endgame-aware'
        : 'existing',
    moveId: result.move.id,
    exactScore: exactScore,
    requestedDepth: depth,
    metadata: result.metadata,
    fixedVerificationMatches: fixedVerificationMatches,
  );
}

void _checkCorrectness(List<_BenchmarkResult> results) {
  final staticBaseline = results.firstWhere(
    (result) => result.configuration == 'baseline-alpha-beta',
  );
  final quiescenceBaseline = results.firstWhere(
    (result) => result.configuration == 'quiescence',
  );
  for (final result in results) {
    if (!result.completed) continue;
    if (result.evaluator == 'endgame-aware') {
      result.matchesReference = result.fixedVerificationMatches;
      continue;
    }
    final reference = switch (result.configuration) {
      'baseline-alpha-beta' ||
      'move-ordering' ||
      'transposition-table' => staticBaseline,
      _ => quiescenceBaseline,
    };
    result.matchesReference =
        result.fixedVerificationMatches && result.moveId == reference.moveId;
    if (result.exactScore != null && reference.exactScore != null) {
      result.matchesReference =
          result.matchesReference && result.exactScore == reference.exactScore;
    }
  }
}

List<_BenchmarkConfiguration> _configurations() {
  return const <_BenchmarkConfiguration>[
    _BenchmarkConfiguration(name: 'baseline-alpha-beta'),
    _BenchmarkConfiguration(name: 'move-ordering', useMoveOrdering: true),
    _BenchmarkConfiguration(
      name: 'transposition-table',
      useMoveOrdering: true,
      useTranspositionTable: true,
    ),
    _BenchmarkConfiguration(
      name: 'quiescence',
      useMoveOrdering: true,
      useTranspositionTable: true,
      useQuiescence: true,
    ),
    _BenchmarkConfiguration(
      name: 'iterative-full-window',
      useIterativeDeepening: true,
      useMoveOrdering: true,
      useTranspositionTable: true,
      useQuiescence: true,
    ),
    _BenchmarkConfiguration(
      name: 'aspiration-windows',
      useIterativeDeepening: true,
      useMoveOrdering: true,
      useTranspositionTable: true,
      useQuiescence: true,
      useAspirationWindows: true,
    ),
    _BenchmarkConfiguration(
      name: 'killer-history',
      useIterativeDeepening: true,
      useMoveOrdering: true,
      useTranspositionTable: true,
      useQuiescence: true,
      useAspirationWindows: true,
      useKillerHistoryHeuristics: true,
    ),
    _BenchmarkConfiguration(
      name: 'pvs',
      useIterativeDeepening: true,
      useMoveOrdering: true,
      useTranspositionTable: true,
      useQuiescence: true,
      useAspirationWindows: true,
      useKillerHistoryHeuristics: true,
      usePrincipalVariationSearch: true,
    ),
    _BenchmarkConfiguration(
      name: 'lmr',
      useIterativeDeepening: true,
      useMoveOrdering: true,
      useTranspositionTable: true,
      useQuiescence: true,
      useAspirationWindows: true,
      useKillerHistoryHeuristics: true,
      usePrincipalVariationSearch: true,
      useLateMoveReductions: true,
    ),
    _BenchmarkConfiguration(
      name: 'current-full',
      useIterativeDeepening: true,
      useMoveOrdering: true,
      useTranspositionTable: true,
      useQuiescence: true,
      useAspirationWindows: true,
      useKillerHistoryHeuristics: true,
      usePrincipalVariationSearch: true,
      useLateMoveReductions: true,
    ),
    _BenchmarkConfiguration(
      name: 'current-full-endgame',
      useIterativeDeepening: true,
      useMoveOrdering: true,
      useTranspositionTable: true,
      useQuiescence: true,
      useAspirationWindows: true,
      useKillerHistoryHeuristics: true,
      usePrincipalVariationSearch: true,
      useLateMoveReductions: true,
      useEndgameEvaluation: true,
    ),
  ];
}

List<_BenchmarkFixture> _fixtures() {
  return <_BenchmarkFixture>[
    _BenchmarkFixture('opening', _engine.createInitialState()),
    _BenchmarkFixture(
      'quiet-middlegame',
      _state(<Piece>[
        _piece('dark-a', PlayerSide.dark, 2, 1),
        _piece('dark-b', PlayerSide.dark, 2, 5),
        _piece('dark-c', PlayerSide.dark, 4, 7),
        _piece('light-a', PlayerSide.light, 5, 0),
        _piece('light-b', PlayerSide.light, 5, 4),
        _piece('light-c', PlayerSide.light, 7, 6),
      ]),
    ),
    _BenchmarkFixture(
      'tactical-capture',
      _state(<Piece>[
        _piece('dark-jumper', PlayerSide.dark, 2, 1),
        _piece('dark-support', PlayerSide.dark, 2, 5),
        _piece('light-target', PlayerSide.light, 3, 2),
        _piece('light-backup', PlayerSide.light, 5, 6),
      ]),
    ),
    _BenchmarkFixture(
      'branching-capture',
      _state(<Piece>[
        _piece('dark-jumper', PlayerSide.dark, 2, 3),
        _piece('light-left', PlayerSide.light, 3, 2),
        _piece('light-right', PlayerSide.light, 3, 4),
        _piece('light-follow-up', PlayerSide.light, 5, 6),
      ]),
    ),
    _BenchmarkFixture(
      'king-heavy',
      _state(<Piece>[
        _piece('dark-a', PlayerSide.dark, 2, 1, rank: PieceRank.king),
        _piece('dark-b', PlayerSide.dark, 4, 3, rank: PieceRank.king),
        _piece('light-a', PlayerSide.light, 5, 6, rank: PieceRank.king),
        _piece('light-b', PlayerSide.light, 1, 6, rank: PieceRank.king),
      ]),
    ),
    _BenchmarkFixture(
      'near-endgame',
      _state(<Piece>[
        _piece('dark-king', PlayerSide.dark, 2, 1, rank: PieceRank.king),
        _piece('light-man', PlayerSide.light, 5, 4),
      ]),
    ),
    _BenchmarkFixture(
      'king-vs-king',
      _state(<Piece>[
        _piece('dark-king', PlayerSide.dark, 2, 1, rank: PieceRank.king),
        _piece('light-king', PlayerSide.light, 5, 6, rank: PieceRank.king),
      ]),
    ),
    _BenchmarkFixture(
      'king-plus-man-vs-king',
      _state(<Piece>[
        _piece('dark-king', PlayerSide.dark, 2, 1, rank: PieceRank.king),
        _piece('dark-man', PlayerSide.dark, 4, 3),
        _piece('light-king', PlayerSide.light, 6, 5, rank: PieceRank.king),
      ]),
    ),
    _BenchmarkFixture(
      'multiple-kings',
      _state(<Piece>[
        _piece('dark-a', PlayerSide.dark, 1, 2, rank: PieceRank.king),
        _piece('dark-b', PlayerSide.dark, 3, 4, rank: PieceRank.king),
        _piece('light-a', PlayerSide.light, 4, 7, rank: PieceRank.king),
        _piece('light-b', PlayerSide.light, 6, 1, rank: PieceRank.king),
      ]),
    ),
    _BenchmarkFixture(
      'promotion-race',
      _state(<Piece>[
        _piece('dark-man', PlayerSide.dark, 5, 0),
        _piece('light-man', PlayerSide.light, 2, 7),
      ]),
    ),
    _BenchmarkFixture(
      'low-material-tactical-ending',
      _state(<Piece>[
        _piece('dark-king', PlayerSide.dark, 2, 3, rank: PieceRank.king),
        _piece('light-man', PlayerSide.light, 3, 2),
        _piece('light-king', PlayerSide.light, 3, 4, rank: PieceRank.king),
      ]),
    ),
  ];
}

GameState _state(Iterable<Piece> pieces) {
  return GameState(
    rulesetId: AmericanCheckersRulesEngine.rulesetId,
    boardSize: 8,
    pieces: pieces,
    activeSide: PlayerSide.dark,
    ply: 0,
    revision: 0,
  );
}

Piece _piece(
  String id,
  PlayerSide side,
  int row,
  int column, {
  PieceRank rank = PieceRank.man,
}) {
  return Piece(
    id: id,
    side: side,
    rank: rank,
    position: BoardPosition(row: row, column: column),
  );
}

final class _BenchmarkFixture {
  const _BenchmarkFixture(this.name, this.state);

  final String name;
  final GameState state;
}

final class _BenchmarkConfiguration {
  const _BenchmarkConfiguration({
    required this.name,
    this.useIterativeDeepening = false,
    this.useMoveOrdering = false,
    this.useTranspositionTable = false,
    this.useQuiescence = false,
    this.useAspirationWindows = false,
    this.useKillerHistoryHeuristics = false,
    this.usePrincipalVariationSearch = false,
    this.useLateMoveReductions = false,
    this.useEndgameEvaluation = false,
  });

  final String name;
  final bool useIterativeDeepening;
  final bool useMoveOrdering;
  final bool useTranspositionTable;
  final bool useQuiescence;
  final bool useAspirationWindows;
  final bool useKillerHistoryHeuristics;
  final bool usePrincipalVariationSearch;
  final bool useLateMoveReductions;
  final bool useEndgameEvaluation;
}

final class _BenchmarkResult {
  _BenchmarkResult({
    required this.fixture,
    required this.configuration,
    required this.evaluator,
    required this.moveId,
    required this.exactScore,
    required this.requestedDepth,
    required this.metadata,
    required this.fixedVerificationMatches,
  });

  static const csvHeader =
      'fixture,configuration,evaluator,status,move,exact_score,completed_depth,nodes,'
      'quiescence_nodes,elapsed_us,nodes_per_second,tt_probes,tt_hits,'
      'tt_cutoffs,pvs_narrow,pvs_researches,aspiration_retries,killer_hits,'
      'history_hits,lmr_reductions,lmr_researches,correct';

  final String fixture;
  final String configuration;
  final String evaluator;
  final String moveId;
  final int? exactScore;
  final int requestedDepth;
  final AiSearchMetadata metadata;
  final bool fixedVerificationMatches;
  bool matchesReference = false;

  bool get completed => metadata.completedDepth == requestedDepth;

  int get nodesPerSecond {
    final microseconds = metadata.elapsed.inMicroseconds;
    if (microseconds == 0) return 0;
    return metadata.nodesExamined *
        Duration.microsecondsPerSecond ~/
        microseconds;
  }

  String toCsv() {
    return <Object?>[
      fixture,
      configuration,
      evaluator,
      completed ? 'complete' : 'incomplete-${metadata.stopReason.name}',
      moveId,
      exactScore ?? '',
      metadata.completedDepth,
      metadata.nodesExamined,
      metadata.quiescence.nodes,
      metadata.elapsed.inMicroseconds,
      nodesPerSecond,
      metadata.transposition.probes,
      metadata.transposition.hits,
      metadata.transposition.cutoffs,
      metadata.principalVariationSearch.narrowWindowSearches,
      metadata.principalVariationSearch.fullWindowResearches,
      metadata.aspiration.reSearches,
      metadata.moveOrdering.killerHits,
      metadata.moveOrdering.historyHits,
      metadata.lateMoveReductions.reductionsApplied,
      metadata.lateMoveReductions.fullDepthResearches,
      matchesReference,
    ].join(',');
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
