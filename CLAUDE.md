# Gridline – Hinweise für Claude

- Sprache in UI, Doku und Commits: Deutsch. Code-Bezeichner Englisch.
- Eigenständige App. Keine Marken, Grafiken, Samples oder Firmware anderer Hersteller übernehmen; Klänge werden im Code erzeugt oder vom Nutzer geladen.
- Swift-Package mit drei Modulen: `GridlineCore` (pure, testbar), `GridlineAudio`, `Gridline` (SwiftUI). Ziel macOS 14+.
- Echtzeit-Regel: Alles, was von `Renderer.render` aus erreichbar ist, darf nicht blockieren und sollte nicht allokieren. Kein `lock()`, nur `tryLock()`; kein Print, kein Foundation-I/O.
- Lokale Sessions laufen oft auf Linux ohne Swift. Build und Tests laufen dann über die GitHub-Actions-CI (`macos-15`).
- `Pattern` kollidiert mit QuickDraw aus AppKit, daher heißt der Typ `GridPattern`.
