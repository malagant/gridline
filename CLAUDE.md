# Gridline – Hinweise für Claude

- Sprache in UI, Doku und Commits: Deutsch. Code-Bezeichner Englisch.
- Eigenständige App. Keine Marken, Grafiken, Samples oder Firmware anderer Hersteller übernehmen; Klänge werden im Code erzeugt oder vom Nutzer geladen.
- Stack: Rust-Kern (`crates/gridline-core`, `crates/gridline-ffi`) + Flutter-App (`app/`) über das FFI-Plugin `packages/gridline_native`. Ziele macOS, Linux, iOS, iPadOS.
- Die C-Schnittstelle (`gl_*` in `crates/gridline-ffi/src/lib.rs`) und die Dart-Bindings (`packages/gridline_native/lib/gridline_native.dart`) immer gemeinsam ändern.
- Flutter-Prüfung: `cd app && flutter analyze`. Linux-Build lokal: `flutter build linux --release`.
- Echtzeit-Regel: Alles, was von `Renderer::render` erreichbar ist, darf nicht blockieren und nicht allokieren. Austausch nur über die `rtrb`-Ringe in `engine.rs`.
- Vor jedem Push: `cargo fmt --all --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`.
