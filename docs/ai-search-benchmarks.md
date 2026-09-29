# AI search benchmarks

## Purpose

The benchmark measures deterministic search work across the Phase 6 search
stack. It is evidence about node efficiency, not a wall-clock performance gate.
Timing and nodes per second are emitted for local profiling, but CI should not
assert either because scheduler load, runtime warm-up, and hardware vary.

## Running

From `packages/checkers_ai`:

```powershell
dart run benchmark/search_benchmark.dart --depth=5
```

The depth defaults to five and can be changed with `--depth=<positive integer>`.
An optional `--max-nodes=<positive integer>` applies the same deterministic node
ceiling to each run and demonstrates explicitly labeled incomplete results.
The executable prints CSV so runs can be archived or analyzed separately from
normal unit tests. A nonzero exit code indicates that a completed optimized run
selected a different move, or produced a different available exact score, from
its applicable baseline.

## Fixtures

All positions are fixed `GameState` values under authoritative American
Checkers rules, with Dark to move:

| Fixture | Intent |
| --- | --- |
| Opening | Standard 24-man initial position and broad quiet branching |
| Quiet middlegame | Six separated men with no immediate mandatory capture |
| Tactical capture | A forced immediate jump with additional material |
| Branching capture | Competing one-jump and multi-jump capture branches |
| King-heavy | Four kings with broad forward/backward mobility |
| Near-endgame | One king against one man |

## Configurations

The configurations are deterministic and start with fresh transposition and
heuristic state for every fixture:

| Name | Enabled additions |
| --- | --- |
| `baseline-alpha-beta` | Fixed depth, stable-ID ordering, no TT, static frontier |
| `move-ordering` | Capture-length and promotion ordering |
| `transposition-table` | Bounded history-safe TT |
| `quiescence` | Eight-turn capture-only quiescence |
| `iterative-full-window` | Iterative deepening without aspiration |
| `aspiration-windows` | Aspiration around the prior exact score |
| `killer-history` | Request-local killer/history quiet ordering |
| `pvs` | Principal Variation Search |
| `lmr` | Conservative one-ply Late Move Reductions |
| `current-full` | Current defaults; intentionally duplicates `lmr` as a drift check |

The first four rows are cumulative fixed-depth configurations. Later rows are
cumulative iterative configurations. `iterative-full-window` is included as the
necessary control for evaluating aspiration and later iterative optimizations.
Quiescence changes frontier semantics, so its score is compared to quiescent
configurations rather than to the static-frontier baseline.

## Metrics

Each CSV row records fixture/configuration, completion status, selected move,
exact score from an exact fixed-depth run, completed depth, total and quiescence
nodes, elapsed microseconds, descriptive nodes per second, TT
probes/hits/cutoffs, PVS probes/re-searches, aspiration retries, killer/history
hits, and LMR reductions/re-searches. Incomplete budget-limited results are
explicitly labeled and excluded from completed-result correctness checks.
Iterative configurations run a separate fixed-depth verification with matching
search features; its work is not included in the reported iterative metrics.

## Depth-5 snapshot

Captured on 2026-09-29. Values are total nodes; timing is intentionally omitted
from the summary because repeated identical configurations showed normal local
timing variation while node counts remained identical.

| Configuration | Opening | Quiet | Tactical | Branching | Kings | Endgame | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Baseline alpha-beta | 2,059 | 393 | 24 | 59 | 1,752 | 127 | 4,414 |
| Move ordering | 2,059 | 385 | 24 | 24 | 1,752 | 127 | 4,371 |
| Transposition table | 2,059 | 385 | 24 | 24 | 1,752 | 127 | 4,371 |
| Quiescence | 3,757 | 385 | 24 | 24 | 1,827 | 127 | 6,144 |
| Iterative full window | 4,300 | 577 | 56 | 54 | 2,007 | 202 | 7,196 |
| Aspiration windows | 4,293 | 576 | 64 | 54 | 1,826 | 194 | 7,007 |
| Killer/history | 2,235 | 590 | 62 | 54 | 1,332 | 190 | 4,463 |
| PVS | 2,057 | 665 | 62 | 55 | 1,377 | 207 | 4,423 |
| LMR | 2,201 | 660 | 62 | 55 | 1,636 | 214 | 4,828 |
| Current full | 2,201 | 660 | 62 | 55 | 1,636 | 214 | 4,828 |

All 60 searches completed depth five and passed their applicable move/score
correctness check.

## Interpretation

- Tactical move ordering had its clearest effect on the branching-capture
  fixture, reducing 59 nodes to 24. It had little effect when legal move order
  was already favorable or captures were forced.
- The cold fixed-depth TT configurations had no transposition hits and therefore
  no node reduction in these shallow fixtures. Iterative configurations did
  reuse entries across depths, with the full configuration recording hits in
  every fixture.
- Quiescence intentionally increased work in unstable positions and changed the
  exact opening/quiet/king scores. It also changed the selected king-heavy move,
  demonstrating why static and quiescent scores are separate correctness groups.
- Aspiration reduced the iterative aggregate from 7,196 to 7,007 nodes (2.6%).
  The tactical fixture required four retries and increased from 56 to 64 nodes,
  showing that narrow windows can lose when scores move sharply.
- Killer/history ordering was the strongest aggregate improvement in this run,
  reducing the aspiration configuration from 7,007 to 4,463 nodes (36.3%),
  mainly in the opening and king-heavy fixtures.
- PVS reduced the aggregate slightly from 4,463 to 4,423 nodes (0.9%). It helped
  the opening but added work in several smaller positions, where null-window
  overhead has less opportunity to pay back.
- Conservative LMR performed 21 reductions in the opening, 14 in the quiet
  middlegame, 44 in the king-heavy fixture, and two near the endgame. At depth
  five its verification and changed TT/search paths increased aggregate work
  from 4,423 to 4,828 nodes (9.2%). It produced no reductions in either forcing
  capture fixture. This snapshot does not support making the policy more
  aggressive; deeper profiling is required before tuning it.
- `lmr` and `current-full` produced identical node and diagnostic counts. Their
  elapsed times differed, illustrating why node work is the primary comparison.

## Limitations

- Six fixtures are representative, not a complete game corpus.
- Depth five emphasizes shallow overhead and may understate benefits that appear
  only at deeper searches.
- The TT starts cold for every fixture. Fixed-depth positions with few
  transpositions cannot demonstrate cache savings.
- Iterative rows include the cost of all completed shallower depths and are not
  directly comparable to fixed-depth rows.
- Timing is single-process local evidence without warm-up control, pinning, or
  device power-state control. Use repeated profiled runs for timing decisions.
- No device performance budget is claimed by this benchmark.
