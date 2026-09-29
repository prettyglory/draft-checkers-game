import 'package:checkers_engine/checkers_engine.dart';

import 'position_evaluator.dart';

enum TranspositionBound { exact, lower, upper }

enum TranspositionNodeType { normal, quiescence }

final class TranspositionKey {
  TranspositionKey._(this.value);

  factory TranspositionKey.fromState({
    required GameState state,
    required PlayerSide perspective,
    EvaluationWeights? weights,
    String? evaluatorKey,
    TranspositionNodeType nodeType = TranspositionNodeType.normal,
  }) {
    final snapshot = const GameStateCodec().snapshotHash(state);
    if (weights == null && evaluatorKey == null) {
      throw ArgumentError('Evaluator weights or a cache key are required.');
    }
    final evaluation =
        evaluatorKey ??
        'evaluation-v2|${weights!.man}|${weights.king}|${weights.advancement}|'
            '${weights.centerControl}|${weights.mobility}|${weights.terminal}|'
            'endgame-off';
    return TranspositionKey._(
      'tt-v3|${nodeType.name}|$snapshot|${perspective.name}|$evaluation',
    );
  }

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranspositionKey && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

final class TranspositionEntry {
  const TranspositionEntry({
    required this.depth,
    required this.score,
    required this.bound,
    required this.generation,
    this.bestMoveId,
  });

  final int depth;
  final int score;
  final TranspositionBound bound;
  final String? bestMoveId;
  final int generation;
}

final class TranspositionDiagnostics {
  const TranspositionDiagnostics({
    this.probes = 0,
    this.hits = 0,
    this.exactHits = 0,
    this.boundHits = 0,
    this.cutoffs = 0,
    this.stores = 0,
    this.replacements = 0,
    this.rejectedStores = 0,
    this.evictions = 0,
    this.occupancy = 0,
    this.capacity = 0,
  });

  final int probes;
  final int hits;
  final int exactHits;
  final int boundHits;
  final int cutoffs;
  final int stores;
  final int replacements;
  final int rejectedStores;
  final int evictions;
  final int occupancy;
  final int capacity;

  TranspositionDiagnostics difference(TranspositionDiagnostics earlier) {
    return TranspositionDiagnostics(
      probes: probes - earlier.probes,
      hits: hits - earlier.hits,
      exactHits: exactHits - earlier.exactHits,
      boundHits: boundHits - earlier.boundHits,
      cutoffs: cutoffs - earlier.cutoffs,
      stores: stores - earlier.stores,
      replacements: replacements - earlier.replacements,
      rejectedStores: rejectedStores - earlier.rejectedStores,
      evictions: evictions - earlier.evictions,
      occupancy: occupancy,
      capacity: capacity,
    );
  }

  TranspositionDiagnostics plus(TranspositionDiagnostics other) {
    return TranspositionDiagnostics(
      probes: probes + other.probes,
      hits: hits + other.hits,
      exactHits: exactHits + other.exactHits,
      boundHits: boundHits + other.boundHits,
      cutoffs: cutoffs + other.cutoffs,
      stores: stores + other.stores,
      replacements: replacements + other.replacements,
      rejectedStores: rejectedStores + other.rejectedStores,
      evictions: evictions + other.evictions,
      occupancy: other.occupancy,
      capacity: other.capacity,
    );
  }
}

final class TranspositionTable {
  TranspositionTable({this.maxEntries = 10000}) {
    if (maxEntries < 0) {
      throw ArgumentError.value(
        maxEntries,
        'maxEntries',
        'Cannot be negative.',
      );
    }
  }

  final int maxEntries;
  final Map<TranspositionKey, TranspositionEntry> _entries =
      <TranspositionKey, TranspositionEntry>{};
  int _generation = 0;
  int _probes = 0;
  int _hits = 0;
  int _exactHits = 0;
  int _boundHits = 0;
  int _cutoffs = 0;
  int _stores = 0;
  int _replacements = 0;
  int _rejectedStores = 0;
  int _evictions = 0;

  int nextGeneration() => ++_generation;

  TranspositionEntry? probe(TranspositionKey key) {
    if (maxEntries == 0) {
      return null;
    }
    _probes += 1;
    final entry = _entries[key];
    if (entry != null) {
      _hits += 1;
    }
    return entry;
  }

  void recordUse(TranspositionEntry entry, {required bool cutoff}) {
    if (entry.bound == TranspositionBound.exact) {
      _exactHits += 1;
    } else {
      _boundHits += 1;
    }
    if (cutoff) {
      _cutoffs += 1;
    }
  }

  void store(TranspositionKey key, TranspositionEntry entry) {
    if (maxEntries == 0) {
      return;
    }
    final existing = _entries[key];
    if (existing != null) {
      if (!_shouldReplace(existing, entry)) {
        _rejectedStores += 1;
        return;
      }
      _entries[key] = entry;
      _replacements += 1;
      _stores += 1;
      return;
    }
    if (_entries.length >= maxEntries) {
      _entries.remove(_evictionKey());
      _evictions += 1;
    }
    _entries[key] = entry;
    _stores += 1;
  }

  void clear() {
    _entries.clear();
  }

  TranspositionDiagnostics get diagnostics => TranspositionDiagnostics(
    probes: _probes,
    hits: _hits,
    exactHits: _exactHits,
    boundHits: _boundHits,
    cutoffs: _cutoffs,
    stores: _stores,
    replacements: _replacements,
    rejectedStores: _rejectedStores,
    evictions: _evictions,
    occupancy: _entries.length,
    capacity: maxEntries,
  );

  static bool _shouldReplace(
    TranspositionEntry existing,
    TranspositionEntry candidate,
  ) {
    if (candidate.depth != existing.depth) {
      return candidate.depth > existing.depth;
    }
    if (candidate.bound != existing.bound) {
      return candidate.bound == TranspositionBound.exact;
    }
    return candidate.generation >= existing.generation;
  }

  TranspositionKey _evictionKey() {
    return _entries.keys.reduce((left, right) {
      final leftEntry = _entries[left]!;
      final rightEntry = _entries[right]!;
      final comparison = _compareEviction(left, leftEntry, right, rightEntry);
      return comparison <= 0 ? left : right;
    });
  }

  static int _compareEviction(
    TranspositionKey leftKey,
    TranspositionEntry left,
    TranspositionKey rightKey,
    TranspositionEntry right,
  ) {
    final generation = left.generation.compareTo(right.generation);
    if (generation != 0) return generation;
    final depth = left.depth.compareTo(right.depth);
    if (depth != 0) return depth;
    final quality = _quality(left.bound).compareTo(_quality(right.bound));
    if (quality != 0) return quality;
    return leftKey.value.compareTo(rightKey.value);
  }

  static int _quality(TranspositionBound bound) =>
      bound == TranspositionBound.exact ? 1 : 0;
}
