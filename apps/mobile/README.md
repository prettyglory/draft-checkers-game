# Draft Game mobile client

The Flutter client renders a responsive, accessible American Checkers board on
Android, iOS, web, and desktop targets. Phase 4 supports local board interaction,
legal move and capture guidance, complete multi-jump selection, promotion,
light/dark themes, and keyboard operation.

The board submits commands through an authoritative in-process `GameSession`.
The session owns game state, legal moves, actor/revision validation, command
deduplication, ordered updates, resignation, and draw agreements. Remaining
Phase 5 work includes persistence, clocks, undo policy, and resume behavior.

## Run

From the repository root:

```powershell
flutter pub get --directory apps/mobile
flutter run --directory apps/mobile
```

## Verify

```powershell
flutter analyze apps/mobile
flutter test apps/mobile
```

Golden baselines cover light and dark phone/tablet layouts under
`test/goldens/`.
