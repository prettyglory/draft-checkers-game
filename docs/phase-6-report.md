# Phase 6 report

Started: 2026-09-28

Status: In progress - core iterative search refinements complete

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

## Slice 6: history-safe transposition table

- Added bounded exact, lower-bound, and upper-bound entries with searched depth,
  score, best move, and generation metadata.
- Keyed entries with the full canonical snapshot hash, evaluation perspective,
  and the complete evaluator configuration, including endgame activation and
  weights.
- Included piece identities, side to move, revision/ply, complete repetition
  history, ruleset counters, status, and outcome through `GameStateCodec`.
- Protected deeper entries from weaker replacement and preferred exact entries
  at equal depth.
- Added deterministic capacity eviction and explicit table clearing.
- Reused entries and preferred cached moves in fixed-depth and iterative search.
- Added request-local probes, hits, bound use, cutoffs, stores, replacements,
  rejected stores, evictions, occupancy, and capacity diagnostics.
- Verified history/counter separation, depth replacement, all bound types, warm
  reuse, deterministic cached/uncached selection, budgets, cancellation, and
  iterative correctness.

## Slice 7: bounded quiescence search

- Replaced static evaluation at the normal depth frontier with bounded
  alpha-beta quiescence search.
- Extended only authoritative capture moves, which are mandatory and include a
  complete multi-jump turn under American Checkers rules.
- Stopped immediately at terminal positions, quiet positions, or the configured
  eight-capture-turn extension ceiling.
- Charged every additional quiescence node to the existing node and duration
  budgets and checked cancellation at every recursive node boundary.
- Preserved deterministic tactical ordering and strict score tie handling.
- Namespaced normal and quiescence transposition keys and stored remaining
  quiescence depth so incompatible horizon values cannot be reused.
- Added quiescence node, cutoff, and maximum recursive-edge-depth diagnostics,
  including iterative-deepening aggregation.
- Verified horizon avoidance, alternating forced captures, quiet and terminal
  frontiers, cancellation, node/time ceilings, deterministic cached and
  uncached results, transposition reuse, and the explicit extension cap.

## Slice 8: aspiration-window search

- Added configurable aspiration windows to iterative depths after the first
  full-window iteration.
- Centered each narrow window on the previous fully completed exact score.
- Classified root results as exact, lower-bound fail-high, or upper-bound
  fail-low outcomes without publishing bounds as completed depth results.
- Doubled the half-width after each failure and fell back to the full score
  range after four configurable narrow attempts.
- Counted every attempt and re-search against the shared node and duration
  budgets and retained the last completed iteration when interrupted.
- Preserved cancellation checks, deterministic root ordering, quiescence,
  alpha-beta bounds, and history-safe transposition reuse across attempts.
- Added attempt, fail-low, fail-high, re-search, maximum-width, and full-window
  fallback diagnostics.
- Verified in-window completion, both failure directions, repeated widening,
  full-window equality, determinism, budget/cancellation interruption,
  transposition compatibility, quiescence compatibility, and iterative
  regression behavior.

## Slice 9: killer and history move ordering

- Added two deterministic killer-move slots per normal-search ply for quiet
  moves that cause alpha-beta cutoffs.
- Added side-aware quiet-move history scores with a squared remaining-depth
  bonus so deeper cutoffs receive greater ordering weight.
- Kept transposition preferences, captures, and promotions ahead of learned
  quiet-move priorities, with stable move IDs as the final tie breaker.
- Scoped heuristic state to one fixed-depth request while sharing it across all
  iterative depths and aspiration re-searches in the same request.
- Excluded captures and quiescence search from killer/history learning.
- Added killer/history hit and update counts plus reused quiet-cutoff diagnostics
  to search metadata, including iterative-attempt aggregation.
- Verified two-slot replacement, ply-local killers, cross-ply history reuse,
  tactical priority, independent-request reset, iterative and aspiration reuse,
  deterministic final moves, quiescence compatibility, budgets, and
  cancellation.

## Slice 10: Principal Variation Search

- Added configurable Principal Variation Search to fixed-depth and iterative
  normal-search nodes, enabled by default with a baseline alpha-beta mode for
  direct correctness comparison.
- Searched each node's first ordered move with the full alpha-beta window and
  later moves with a one-point null window.
- Re-searched a later move with the full current window only when its null-window
  result improved the bound without causing a cutoff.
- Preserved fail-soft alpha-beta cutoffs and classified every transposition entry
  against the actual window used by that search, so null-window failures remain
  lower or upper bounds until a genuinely exact full search replaces them.
- Kept quiescence on its existing full alpha-beta path while allowing PVS probes
  and re-searches to reuse its exact, history-safe transposition entries.
- Charged all probes and re-searches through the existing node, duration, and
  cancellation checks and retained the last completed iterative depth when a
  re-search was interrupted.
- Added first-move full-window, null-window, full re-search, and direct PVS
  cutoff diagnostics with iterative and aspiration-attempt aggregation.
- Verified move and exact-score equality with baseline alpha-beta, deterministic
  fail-high and fail-low behavior, narrow-bound and exact TT storage, aspiration,
  quiescence, killer/history ordering, legal fallback, budgets, cancellation,
  and interrupted iterative search.
- Did not add Late Move Reductions in this slice.

## Slice 11: conservative Late Move Reductions

- Added configurable Late Move Reductions to fixed-depth and iterative normal
  search, enabled by default with a disabled mode for baseline comparison.
- Applied a one-ply reduction only from the third ordered move at non-PV nodes
  with at least three plies remaining.
- Excluded captures, promotions, first moves, transposition-table best moves,
  killer moves, PV nodes, shallow nodes, and positions with forcing captures.
- Used the existing PVS null window for reduced probes when PVS is enabled and a
  normal alpha-beta window when it is disabled.
- Re-searched every reduced result that could improve the active alpha or beta
  bound at full depth and with the full current window before accepting it.
- Prevented nodes with accepted unverified reduced results from writing a
  full-depth transposition entry; reduced child searches remain keyed and stored
  only at their actual reduced depth.
- Charged reduced probes and full-depth verification searches through the
  existing node, duration, and cancellation checks.
- Added candidate, reduction, reduced-search, full-depth re-search, and reduced
  cutoff diagnostics with iterative and aspiration-attempt aggregation.
- Verified quiet-move reduction; capture, promotion, first-move, PV, shallow,
  TT-best, and killer protection; promising-move verification; baseline move and
  exact-score equality; determinism; PVS, aspiration, quiescence, and TT safety;
  and budget, cancellation, and legal-fallback behavior.
- Kept the initial policy fixed and conservative without adaptive reduction
  formulas.

## Slice 12: deterministic search benchmarking

- Added a standalone CSV benchmark executable under `packages/checkers_ai`
  rather than adding timing-sensitive assertions to the unit-test suite.
- Added deterministic opening, quiet middlegame, tactical capture, branching
  capture, king-heavy, and near-endgame fixtures.
- Added default-preserving controls for tactical move ordering and killer/history
  learning so individual search stages can be compared honestly.
- Compared baseline alpha-beta, tactical ordering, TT, quiescence, iterative full
  windows, aspiration, killer/history, PVS, LMR, and current defaults at depth
  five with fresh per-run state.
- Recorded moves, available exact scores, completion, nodes, quiescence work,
  descriptive timing/NPS, TT activity, aspiration retries, PVS activity,
  killer/history activity, and LMR activity.
- Required completed configurations to match the applicable static or quiescent
  correctness baseline and made mismatches fail the benchmark process.
- Confirmed all 60 snapshot runs completed and matched. Killer/history produced
  the largest aggregate node reduction; aspiration and PVS were modest; tactical
  ordering strongly helped branching captures; the cold fixed-depth TT had no
  hits; and conservative LMR increased depth-5 aggregate work.
- Documented methodology, full node-count results, interpretation, limitations,
  and the separate benchmark command in `docs/ai-search-benchmarks.md`.

## Slice 13: endgame-aware evaluation

- Kept the existing evaluator as the default and added optional immutable
  endgame weights with a default activation threshold of six total pieces.
- Preserved every existing material, advancement, center-control, mobility, and
  terminal calculation exactly when endgame mode is disabled or above its
  configured threshold.
- Added separately reported king activity, king centralization, promotion
  proximity, endgame mobility, trapped-piece, edge-safety, conversion-pressure,
  and draw-risk terms.
- Derived every feature from immutable piece coordinates, authoritative legal
  moves, ruleset counters, repetition history, and completed outcomes. The
  evaluator does not infer a draw or terminal result independently of the rules
  engine.
- Penalized individually trapped pieces only when they have neither an ordinary
  move nor a first legal capture step under American man/king directions.
- Increased conversion pressure with material-unit advantage and board scarcity;
  reduced that advantage near the authoritative no-progress/repetition limits;
  and normalized completed rules-engine draws to zero.
- Included the full endgame configuration in transposition keys so tables cannot
  reuse scores across evaluator modes or weight sets.
- Added ten tests covering central kings, promotion races, trapped pieces,
  mobility, material conversion, draw risk and completed draws, determinism,
  perspective symmetry, inactive middlegame behavior, validation, and
  evaluator-key separation.
- Added five ending fixtures and an endgame-aware `current-full` comparison to
  the deterministic harness. All 121 depth-5 rows completed and passed; repeated
  evaluator runs reproduced moves, exact scores, depths, and node counts.
- The endgame-aware evaluator changed the king-heavy choice from `43-54` to the
  more central `43-34`. Other compared moves remained stable. Across all eleven
  fixtures, current-full work changed from 7,409 to 7,398 nodes.

## Slice 14: Flutter difficulty and AI turn integration

- Added typed Beginner, Easy, Medium, Hard, and Expert presets to the pure-Dart
  AI package. Each preset declares its strategy kind, depth/node ceilings,
  transposition capacity, quiescence depth, search features, seed, and evaluator
  mode.
- Used deterministic depth/node budgets only: Beginner 1/1, Easy 2/500, Medium
  3/2,500, Hard 4/10,000, and Expert 5/25,000. Duration limits remain excluded
  until device measurements can establish defensible hardware-specific values.
- Kept seeded legal selection for Beginner; used limited iterative search for
  Easy; enabled quiescence, aspiration, PVS, and killer/history at Medium; enabled
  the full stack including conservative LMR at Hard; and added endgame-aware
  evaluation at Expert.
- Added a Flutter game configuration model for local two-player or human-vs-AI,
  human side, and selected difficulty. Local two-player remains the default.
- Added a killable isolate runner that constructs the selected strategy outside
  the UI isolate. Reset, mode/side/difficulty changes, disposal, and stale
  authoritative updates cancel or invalidate pending work.
- Extended `GameBoardViewModel` to launch one AI search per matching session
  revision, block human interaction on AI turns, reject stale results, and submit
  the selected move through the AI side's authoritative `SubmitMoveCommand`.
- Added ready, thinking, move-completed, and error presentation states plus
  responsive setup controls for mode, side, and difficulty.
- Preserved existing two-player selection, multiple capture, promotion, king,
  keyboard, semantics, phone/tablet, and light/dark behavior. Updated four visual
  baselines for the intentional Phase 6 setup controls.
- Added AI package tests for exact preset mapping and deterministic behavior, and
  Flutter tests for isolated execution/cancellation, turn ownership, legal
  authoritative moves, reset cancellation, difficulty changes, side choice,
  blocked input, disposal, and visible thinking state.

## Slice 15: Match setup flow

- Added a responsive pre-match screen as the Flutter app entry point. Human vs
  Human remains the default, while Human vs AI exposes side and all five existing
  difficulty presets before a session is created.
- Extended the typed `GameConfiguration` with a `GameRuleset` field. The setup
  ViewModel owns draft selections, validates mode/ruleset and AI-only fields, and
  emits a complete configuration without duplicating preset policy in widgets.
- Made `Start Game` push a board route that constructs a fresh authoritative
  `InProcessGameSession` and `GameBoardViewModel` from that configuration. The
  board shows a read-only match summary rather than mutating setup mid-match.
- Preserved local two-player commands and all board behavior. Restart continues
  through `StartNewGameCommand` and retains the current configuration.
- Verified the AI starts automatically when it owns opening Dark, board input is
  blocked during that search, and leaving the route disposes the ViewModel and
  cancels pending isolate work.
- Added setup state, widget, navigation, lifecycle, accessibility, and selection
  coverage plus phone/tablet light/dark setup goldens. Existing board regression
  and golden coverage remains active.

## Remaining work

- Legal-move fuzzing and measured low-end-device performance evidence.
- Device-informed budget tuning and possible expansion beyond the initial five
  presets.
