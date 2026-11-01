# gridline_native

Flutter-FFI-Plugin, das den Rust-Kern (`crates/gridline-ffi`) baut und per `dart:ffi` anbindet.

- **Linux**: `linux/CMakeLists.txt` ruft `cargo build --release -p gridline-ffi` auf und bündelt `libgridline_ffi.so`.
- **macOS/iOS**: Eine CocoaPods-Script-Phase (`scripts/build_apple.sh`) baut die statische Bibliothek für die passenden Architekturen, das Plugin-Framework lädt sie per `-force_load`.

Voraussetzung ist eine Rust-Toolchain (`rustup`). Für iOS werden die Targets `aarch64-apple-ios` und `aarch64-apple-ios-sim` bei Bedarf automatisch installiert.
