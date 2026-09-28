# Draft Game mobile client

The Flutter client renders a responsive, accessible American Checkers board on
Android, iOS, web, and desktop targets. Phase 4 supports local board interaction,
legal move and capture guidance, complete multi-jump selection, promotion,
light/dark themes, and keyboard operation.

The board currently owns a local rules-engine view-model. Phase 5 will introduce
the single-player game flow, persistence, clocks, undo policy, and resume
behavior; those features are not part of the Phase 4 client.

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
