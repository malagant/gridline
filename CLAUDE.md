# Gridline – Hinweise für Claude

- Sprache in UI, Doku und Commits: Deutsch. Code-Bezeichner Englisch.
- Eigenständige App. Keine Marken, Grafiken, Samples oder Firmware anderer Hersteller übernehmen; Klänge werden im Code erzeugt oder vom Nutzer geladen.
- Stack: Rust-Kern (`crates/`) + Flutter-Oberfläche. Ziele macOS, Linux, iOS, iPadOS.
- Echtzeit-Regel: Alles, was von `Renderer::render` erreichbar ist, darf nicht blockieren und nicht allokieren. Austausch nur über die `rtrb`-Ringe in `engine.rs`.
- Vor jedem Push: `cargo fmt --all --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`.
