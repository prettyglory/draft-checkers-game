# Phase 2 report

Completed: 2026-09-28

## Outcome

Phase 2 delivers the deterministic, UI-independent state foundation required
by every ruleset and game mode. It does not claim that a playable checkers
ruleset exists yet; American Checkers movement and capture behavior remains the
Phase 3 milestone.

## Implemented

- Added an immutable, indexed `Board` with collision, bounds, identity, capture,
  promotion, and stale-origin checks.
- Made `GameState` retain one validated board and compute its position hash
  instead of trusting callers to provide one.
- Added atomic application of moves whose ruleset-specific legality has already
  been established by a `RulesEngine`.
- Strengthened move shape invariants for simple turns and multi-capture paths.
- Added canonical SHA-256 position hashes that intentionally ignore piece IDs
  and counters for repetition comparison.
- Added versioned canonical game-state JSON with tamper detection and a full
  snapshot hash for synchronization.
- Added canonical move JSON for persistence and transport payloads.
- Added deterministic replay through the rules engine, with explicit failures
  for illegal history and invalid revision/ply transitions.

## Quality gate

All checks passed on Flutter 3.47.5 / Dart 3.13.4:

| Check | Result |
| --- | --- |
| Engine formatting | 15 files checked, 0 changes |
| Engine static analysis | No issues |
| Engine unit tests | 26 passed |
| Session formatting | 6 files checked, 0 changes |
| Session static analysis | No issues |
| Session unit tests | 4 passed |
| Client formatting | 6 files checked, 0 changes |
| Flutter static analysis | No issues |
| Flutter widget tests | 1 passed |

The engine tests cover immutability, one-pass iterable safety, exhaustive board
destination properties, collisions, ownership, capture/promotion transitions,
canonical hashes, state and move round trips, schema rejection, tamper
rejection, malformed data, legal replay, illegal history, and replay transition
invariants.

## Next milestone

Phase 3 implements American Checkers from federation-derived fixtures: initial
placement, forward men, short kings, compulsory captures, complete optional
capture sequences, promotion that ends a capture turn, wins, and draw rules.
