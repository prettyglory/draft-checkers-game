# Draft Game

Draft Game is a production-oriented, cross-platform checkers application. The
Flutter client targets Android and iOS first, while retaining Web and desktop
targets. A pure-Dart domain core keeps rules and session logic independent from
the UI and from any particular network transport.

## Current status

Phase 4 (playable board UI) is complete. The Flutter client presents the WCDF
American Checkers rules through a responsive, accessible local board with legal
selection targets, compulsory-capture guidance, complete multi-jump paths,
promotion and king presentation, light/dark themes, and keyboard operation.
Phone and tablet layouts are covered by widget, semantics, and golden tests.
Phase 5, the single-player game flow and persistence milestone, has not started.

## Repository layout

```text
apps/mobile/                 Flutter client
packages/checkers_engine/    Pure-Dart board, state, codecs, replay, and rules API
packages/game_session/       Shared session and transport contracts (Phase 1)
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
[Phase 4 report](docs/phase-4-report.md).
