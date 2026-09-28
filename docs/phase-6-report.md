# Phase 6 report

Started: 2026-09-28

Status: In progress - AI contracts and beginner strategy complete

## Documented outcome

Phase 6 delivers ten measurable AI difficulty profiles, iterative search in an
isolate, cancellation, explicit time/node budgets, tactical evidence,
legal-move fuzzing, and a measured device performance budget.

## Slice 1: contracts and beginner strategy

- Added a pure-Dart `checkers_ai` package that depends only on
  `checkers_engine`.
- Added validated node, depth, and duration budget contracts.
- Added cancellation tokens and a cancellation controller.
- Added immutable search requests, results, metadata, stop reasons, and typed
  search failures.
- Added a seeded beginner strategy with reproducible random selection.
- Required the supplied legal moves to exactly match the authoritative rules
  engine result before selection.
- Added CI formatting, analysis, and test gates for the package.

## Evidence

- Beginner results always belong to the authoritative legal-move list.
- A configured seed reproduces the same selection sequence.
- Request move collections are copied and exposed as unmodifiable.
- Mismatched legal moves, completed games, cancellation, and invalid budgets are
  rejected explicitly.

## Slice 2: weighted position evaluation

- Added configurable weights for men, kings, uncrowned advancement, center
  control, active-side mobility, and terminal outcomes.
- Added a measurable evaluation breakdown rather than exposing only an opaque
  total score.
- Made evaluation symmetric by player perspective.
- Required terminal scores to dominate the combined heuristic weights.
- Added tactical terminal, material, king-value, advancement, center-control,
  symmetry, and validation fixtures.

## Slice 3: fixed-depth alpha-beta

- Added deterministic maximizing/minimizing alpha-beta search.
- Expanded every node through the authoritative rules engine.
- Added terminal-first evaluation and stable move-order tie breaking.
- Enforced depth, node, duration, and cancellation checks during recursion.
- Returned a legal fallback with explicit metadata when a resource ceiling
  interrupts the requested depth.
- Added immediate-win, opening determinism, node-budget, depth-contract, and
  cancellation tests.

## Slice 4: iterative deepening

- Added depth-by-depth alpha-beta search through a requested maximum depth.
- Carried remaining node and duration ceilings across iterations.
- Retained the move from the last fully completed depth when a deeper iteration
  was interrupted.
- Preserved a legal fallback when depth one could not complete.
- Added full-depth, interrupted-depth, fallback, and cancellation tests.

## Slice 5: deterministic move ordering

- Added principal-move, longer-capture, promotion, and stable-ID priorities.
- Integrated ordering at root and recursive alpha-beta nodes.
- Kept input move collections immutable.
- Added capture, promotion, preferred-move, determinism, and immutability tests.

## Remaining work

- History-safe transposition table.
- Ten documented difficulty profiles.
- Endgame knowledge.
- Isolate worker and AI session actor integration.
- Flutter mode/level selection and thinking state.
- Legal-move fuzzing and measured low-end-device performance evidence.
