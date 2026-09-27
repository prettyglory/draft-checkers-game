# Draft Game

Draft Game is a production-oriented, cross-platform checkers application. The
Flutter client targets Android and iOS first, while retaining Web and desktop
targets. A pure-Dart domain core keeps rules and session logic independent from
the UI and from any particular network transport.

## Current status

Phase 1 (architecture and project foundation) is in progress. Gameplay is not
advertised as implemented yet; the next milestone after this phase is the
tested core engine and American Checkers ruleset.

## Repository layout

```text
apps/mobile/                 Flutter client
packages/checkers_engine/    Pure-Dart game concepts and rules contracts (Phase 1)
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
[delivery roadmap](docs/roadmap.md), and [risk register](docs/risks.md).

