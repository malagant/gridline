# Gridline – Hinweise für Claude

- Sprache in UI, Doku und Commits: Deutsch. Code-Bezeichner Englisch.
- Eigenständige App. Keine Marken, Grafiken, Samples oder Firmware anderer Hersteller übernehmen; Klänge werden im Code erzeugt oder vom Nutzer geladen.
- Swift-Package: `GridlineCore` (pure, testbar), `GridlineAudio`, `GridlineUI` (gemeinsame SwiftUI-Oberfläche), `Gridline` (macOS-Einstieg). iOS/iPadOS-App in `iOS/` per XcodeGen. Ziel macOS 14+ und iOS 17+.
- Plattformcode in `GridlineUI` mit `#if os(macOS)` / `#if os(iOS)` kapseln, kein AppKit/UIKit außerhalb davon.
- Echtzeit-Regel: Alles, was von `Renderer.render` aus erreichbar ist, darf nicht blockieren und sollte nicht allokieren. Kein `lock()`, nur `tryLock()`; kein Print, kein Foundation-I/O.
- Lokale Sessions laufen oft auf Linux ohne Swift. Build und Tests laufen dann über die GitHub-Actions-CI (`macos-15`).
- `Pattern` kollidiert mit QuickDraw aus AppKit, daher heißt der Typ `GridPattern`.
