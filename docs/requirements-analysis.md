# Requirements analysis

## Product shape

The brief describes four products sharing one deterministic game core:

1. An offline game: AI, campaign, tutorial, same-device play, saves, settings,
   achievements, audio, and accessibility.
2. A nearby multiplayer game: LAN discovery and direct sessions, plus Bluetooth
   where each operating system permits it.
3. A competitive online service: accounts, rooms, matchmaking, authoritative
   matches, rankings, friends, history, leaderboards, and reconnects.
4. A content platform: five rulesets, progression tracks, story chapters,
   challenges, themes, localization-ready text, and future rulesets.

The largest correctness risk is not the number of screens. It is keeping rule
resolution, clocks, reconnection, AI, and all transports consistent. The
architecture therefore starts with a platform-neutral state machine and stable
protocol before visual feature work.

## Quality attributes

| Attribute | Design consequence |
| --- | --- |
| Correctness | Pure rules packages, immutable states, golden positions, per-ruleset conformance tests |
| Determinism | Commands reduce to ordered events; clocks use server/host timestamps; state snapshots are hashed |
| Security | Online clients submit intent only; the server validates moves, clocks, results, and rating changes |
| Offline-first | Local saves and content never depend on a live account; sync uses idempotent operations |
| Performance | AI runs in an isolate; board rendering minimizes rebuilds; search has time and node budgets |
| Extensibility | Rulesets implement a contract; sessions do not know whether bytes travel over WebSocket, LAN, or Bluetooth |
| Accessibility | Semantics, contrast, reduced motion, scalable text, and non-colour move indicators are acceptance criteria |
| Observability | Correlation IDs, structured events, latency/error metrics, and privacy-safe crash reporting are designed in |

## Scope discipline

The delivery follows the requested phases. A screen, button, transport, or
ruleset is only described as complete after it has working behavior and tests.
Phase 1 contains architecture, research, contracts, repository structure, CI,
and a truthful bootstrap screen. It intentionally contains no mock matchmaking,
fake profile data, or non-functional mode buttons.

## Recommended stack

| Area | Choice | Reason |
| --- | --- | --- |
| Client | Flutter 3.47 / Dart 3.13 | One high-performance UI codebase across mobile, web, and desktop, with native escape hatches |
| Client architecture | Feature-first MVVM with repositories/services | Clear UI/domain/data boundaries and testable presentation logic |
| State/DI | Riverpod when feature state begins | Compile-safe dependency wiring, scoped overrides, and good async state support |
| Navigation | `go_router` when multi-screen work begins | Declarative deep links and restoration-friendly routing |
| Local data | SQLite-backed repository plus secure key storage | Transactional saves/offline queue; tokens stay out of ordinary preferences |
| Backend | Serverpod 4 / Dart | Shares the pure-Dart engine, generates typed clients, supports authenticated streams, PostgreSQL, and Redis fan-out |
| Primary data | PostgreSQL | Transactional match/rating/account data and strong constraints |
| Ephemeral data | Redis | Matchmaking queues, presence, rate limits, and multi-instance pub/sub |
| Realtime | Authenticated Serverpod streams over WebSocket | Typed bidirectional match events and server-controlled lifecycle |
| CI | GitHub Actions | Repeatable formatting, analysis, unit/widget tests, and later platform builds |

Flutter officially supports Android, iOS, web, Windows, macOS, and Linux from a
shared framework. The client layering follows Flutter's current guidance around
views/view-models, repositories, and services:

- [Flutter supported platforms](https://docs.flutter.dev/reference/supported-platforms)
- [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide)
- [Serverpod streaming](https://docs.serverpod.dev/concepts/endpoints-and-apis/streaming)
- [Serverpod project structure](https://docs.serverpod.dev/concepts/server-fundamentals/your-serverpod-project)

