# Phase 5 report

Started: 2026-09-28

Status: In progress - authoritative in-process session slice complete

## Outcome

The first Phase 5 slice places an authoritative local `GameSession` between the
Flutter board view-model and deterministic rules engine. The view-model no
longer imports, constructs, or calls `AmericanCheckersRulesEngine` directly.

This slice establishes the single-player game-flow boundary but does not yet add
persistence, clocks, undo, process resume, AI, networking, or backend services.

## Session behavior

- Owns the authoritative `GameState` and exposes engine-derived legal moves.
- Maps one local actor to each side and enforces the active actor for moves.
- Rejects unknown actors, stale revisions, illegal moves, completed-game
  commands, unavailable sessions, and invalid draw workflows.
- Deduplicates accepted and rejected command IDs. Exact retries return the
  original result without another state transition or update; payload collisions
  are rejected.
- Emits a single monotonically sequenced update for every accepted connection,
  move, resignation, draw, and new-game action.
- Supports lifecycle start, reconnect, and close behavior without introducing a
  transport dependency.
- Supports resignation by either side, including outside that side's turn.
- Supports draw offers, opponent-only accept/decline responses, and agreed-draw
  completion. Responses identify the exact offer they resolve.
- Preserves board position history and gameplay ply for administrative results.
- Routes the existing new-game control through an authoritative command while
  keeping revisions monotonic across games in the same session.

## Presentation integration

- `GameBoardViewModel` depends on `GameSession` plus local actor-seat IDs.
- Move selection remains presentation-local until a complete engine-approved
  path is submitted as a command.
- Session updates replace view-model state and clear stale selection paths.
- External terminal session updates are reflected by the existing status UI.
- All Phase 4 responsive, semantics, keyboard, interaction, and golden behavior
  remains unchanged.

## Test coverage

The session suite covers:

- Valid and illegal moves.
- Unknown/wrong-side actors and stale revisions.
- Accepted/rejected duplicate IDs and conflicting ID reuse.
- Ordered updates and lifecycle transitions.
- Resignation state, winner, revision, ply, and history integrity.
- Draw offer, decline, acceptance, ownership, and pending-offer policy.
- Authoritative new-game reset.

The Flutter suite adds ViewModel/session integration coverage and reruns all
Phase 4 board regressions.

## Quality gate

All requested checks passed on Flutter 3.47.5 / Dart 3.13.4:

| Check | Result |
| --- | --- |
| Engine unit tests | 41 passed |
| Session unit tests | 18 passed |
| Flutter static analysis | No issues |
| Flutter tests | 21 passed, including 4 golden tests |

## Remaining Phase 5 work

- Persist active game snapshots and command/session metadata.
- Restore an interrupted game after process restart.
- Define and implement clock and backgrounding policy.
- Define undo policy and authoritative undo commands.
- Add an end-to-end offline game and process-restart acceptance test.
