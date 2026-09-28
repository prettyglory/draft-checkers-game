# Phase 3 report

Completed: 2026-09-28

## Outcome

Phase 3 delivers a complete board-rules implementation for American Checkers /
English Draughts. It is derived from the
[WCDF Rules of Draughts](https://wcdf.net/rules/rules_of_checkers_english.pdf)
and runs entirely inside the deterministic engine package.

This milestone implements legal board play. Resignation, timeout, forfeiture,
and draw agreement are authoritative session commands rather than moves and
remain scheduled with game-session flow.

## WCDF coverage

| WCDF rule | Implemented behavior |
| --- | --- |
| 1.8-1.13 | 12 pieces per side on playable squares; dark/Red moves first |
| 1.15-1.18 | Forward men, short kings, forward man captures, bidirectional king captures |
| 1.19 | Complete multiple jumps; delayed captured-piece removal; promotion ends the turn |
| 1.20 | Captures compulsory; any complete sequence may be selected without maximum-capture priority |
| 1.30 | Win when the opponent has no pieces or no legal move |
| 1.32.1 | Draw on the third occurrence of the same board and active side |
| 1.32.2 | Draw after 40 moves per player without capture or uncrowned-man advance |

## Implemented

- Added `AmericanCheckersRulesEngine` with deterministic move IDs and ordering.
- Added complete recursive multi-capture generation without removing captured
  pieces before the sequence ends.
- Added explicit rejection reasons for wrong turns, stale origins, compulsory
  captures, incomplete captures, illegal movement, and completed games.
- Added immutable position history and namespaced ruleset counters to
  `GameState`.
- Advanced canonical state serialization to schema version 2 while retaining a
  tested schema-v1 migration path.
- Added WCDF position fixtures plus a generated-play transition invariant test.

## Quality gate

All checks passed on Flutter 3.47.5 / Dart 3.13.4:

| Check | Result |
| --- | --- |
| Engine formatting | 17 files checked, 0 changes |
| Engine static analysis | No issues |
| Engine unit tests | 41 passed, including 14 American-rules tests |
| Session formatting | 6 files checked, 0 changes |
| Session static analysis | No issues |
| Session unit tests | 4 passed |
| Client formatting | 6 files checked, 0 changes |
| Flutter static analysis | No issues |
| Flutter widget tests | 1 passed |

## Next milestone

Phase 4 builds the responsive, accessible checkers board with selection,
mandatory-capture guidance, complete-path highlights, motion primitives, and
phone/tablet widget, golden, and semantics coverage.
