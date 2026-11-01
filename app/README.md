# Gridline-App (Flutter)

Oberfläche für macOS, Linux, iPhone und iPad. Der Rust-Kern wird über das Plugin `../packages/gridline_native` automatisch mitgebaut.

```bash
flutter run -d linux     # oder -d macos, oder ein iOS-Gerät/Simulator
flutter build linux --release
```

Voraussetzungen: Flutter (stable), Rust (`rustup`). Linux zusätzlich: `clang cmake ninja-build pkg-config libgtk-3-dev libasound2-dev`.
