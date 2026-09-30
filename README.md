# Draft Game

Draft Game is a production-oriented, cross-platform checkers application. The
Flutter client targets Android and iOS first, while retaining Web and desktop
targets. A pure-Dart domain core keeps rules and session logic independent from
the UI and from any particular network transport.

## Current status

Phase 5 is in progress. Its first slice adds an authoritative in-process
`GameSession` between the playable board and rules engine. The session validates
actors and revisions, applies legal commands, deduplicates command IDs, emits
ordered updates, and handles resignation and draw agreements. The completed
Phase 4 board behavior remains covered on phone and tablet. Persistence, clocks,
undo, and process resume remain for later Phase 5 slices.

Phase 6 has started with a separate pure-Dart AI package. It now provides
measurable search budgets and metadata, cancellation contracts, a seeded legal
beginner strategy, weighted evaluation, fixed-depth alpha-beta, iterative
deepening, deterministic tactical move ordering, and a history-safe
transposition table. Bounded capture-only quiescence search prevents evaluation
in the middle of forcing exchanges, while configurable aspiration windows focus
later iterative searches around the previous exact score. Request-local killer
moves and depth-weighted history scores now prioritize quiet moves that have
already caused cutoffs. Principal Variation Search gives the first ordered move
a full window, probes later moves with null windows, and fully re-searches only
promising improvements. Conservative one-ply Late Move Reductions shorten only
safe non-PV quiet branches and verify any promising result at full depth. An
optional endgame evaluator activates at six or fewer pieces and adds explicit
king activity/centralization, promotion, mobility, trapping, edge safety,
conversion, and draw-risk terms without changing middlegame scores.

The Flutter client now opens on a responsive match setup screen for local
two-player or human-versus-computer games. Setup produces one typed match
configuration containing the mode, American Checkers ruleset, human side, and
one of five deterministic presets: Beginner, Easy, Medium, Hard, or Expert.
Starting creates a fresh authoritative session and navigates to the board. AI
search runs in a killable isolate, user input is disabled on the computer turn,
and the selected move is submitted through the same authoritative `GameSession`
command path as human play. Restart keeps the match configuration, while leaving
the board disposes the match and cancels pending AI work. Device profiling and
possible profile expansion remain.

Deterministic search-work benchmarks can be run separately with
`dart run benchmark/search_benchmark.dart --depth=5` from `packages/checkers_ai`.
The [benchmark report](docs/ai-search-benchmarks.md) documents fixtures,
methodology, node counts, and interpretation without imposing fragile timing
thresholds on CI.

## Repository layout

```text
apps/mobile/                 Flutter client
packages/checkers_engine/    Pure-Dart board, state, codecs, replay, and rules API
packages/game_session/       Session contracts and local authoritative reducer
packages/checkers_ai/         Budgeted AI contracts and strategies
docs/                        Architecture, rules research, roadmap, and risks
```

The authoritative Serverpod backend is deliberately scheduled for its online
multiplayer phase. Its boundaries and data model are defined now so offline and
nearby play do not grow incompatible protocols.

## Prerequisites

- Flutter 3.47.5 (stable) with Dart 3.13.4
- Platform tooling for the target you want to run
- Xcode on macOS for iOS and macOS builds

## Verify the project

```powershell
flutter pub get --directory apps/mobile
flutter analyze apps/mobile
flutter test apps/mobile

dart pub get --directory packages/checkers_engine
dart analyze packages/checkers_engine
dart test packages/checkers_engine

dart pub get --directory packages/game_session
dart analyze packages/game_session
dart test packages/game_session
```

See [the architecture](docs/architecture.md), [ruleset research](docs/rulesets.md),
[delivery roadmap](docs/roadmap.md), [risk register](docs/risks.md), and
[Phase 1 report](docs/phase-1-report.md). The completed engine milestone is
recorded in the [Phase 2 report](docs/phase-2-report.md), and the first playable
ruleset is documented in the [Phase 3 report](docs/phase-3-report.md). The
responsive playable board milestone is recorded in the
[Phase 4 report](docs/phase-4-report.md). The authoritative local-session slice
is documented in the [Phase 5 report](docs/phase-5-report.md).
Phase 6 progress is tracked in the [Phase 6 report](docs/phase-6-report.md).
