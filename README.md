# Gridline

Gridline ist ein Pattern-Sequencer im Tracker-Stil für macOS, Linux, iPhone und iPad: Spuren laufen senkrecht, jede Zeile ist ein Step, gespielt werden Sample-Instrumente. Die Arbeitsweise ist von Hardware-Trackern inspiriert. Gridline ist ein eigenständiges Projekt mit eigenem Design und eigenen Klängen und steht in keiner Verbindung zu Herstellern solcher Geräte.

## Aufbau

| Teil | Inhalt |
| --- | --- |
| `crates/gridline-core` | Rust: Datenmodell, sample-genaue Step-Uhr, lock-freier Echtzeit-Renderer, eingebaute Klänge, WAV-Leser/-Schreiber, Projektformat |
| `crates/gridline-ffi` | Rust: Audio-Ausgabe über cpal, App-Sitzung (Speichern/Laden, WAV-Export), C-Schnittstelle |
| `packages/gridline_native` | Flutter-FFI-Plugin: baut den Rust-Kern pro Plattform und bindet ihn per `dart:ffi` an |
| `app` | Flutter-App für macOS, Linux, iPhone und iPad |

## Bedienung

| Taste | Funktion |
| --- | --- |
| Pfeiltasten | Cursor bewegen |
| Bild ↑ / Bild ↓ | 16 Steps springen |
| ⇧↑ / ⇧↓ | Oktave wechseln |
| Y S X D C V G B H N J M | Noten (untere Reihe, QWERTZ) |
| Q 2 W 3 E R 5 T 6 Z 7 U | Noten eine Oktave höher |
| A | Note aus |
| ⌫ | Step löschen |
| Leertaste | Play / Stopp |

Auf iPhone und iPad gibt es eine Bildschirm-Klaviatur mit Cursor- und Editiertasten. Zellen wählt man per Antippen.

## App bauen

```bash
cd app
flutter run -d linux        # bzw. -d macos oder iOS-Gerät/Simulator
flutter build linux --release
```

Voraussetzungen: Flutter (stable) und Rust (`rustup`). Linux zusätzlich `clang cmake ninja-build pkg-config libgtk-3-dev libasound2-dev`. Jeder CI-Lauf legt das Linux-Bundle und die macOS-App als Artefakte ab.

## Nix-Entwicklungsumgebung

`flake.nix` stellt eine Dev-Shell mit Rust (stable, inkl. clippy, rustfmt, rust-analyzer), Flutter, den Linux-Systempaketen aus der CI und einem Starship-Prompt bereit:

```bash
nix develop          # bzw. mit direnv: direnv allow (nutzt .envrc)
```

Der Prompt kommt aus `starship.toml` und zeigt Verzeichnis, Git-Status, die Rust-Version der Shell, Dart-Version im `app/`-Ordner und Kommandodauer. Unter direnv bleibt die eigene Shell (zsh, fish …); ein dort eingerichtetes Starship liest über `STARSHIP_CONFIG` dieselbe Konfiguration.

Auf macOS kommen Xcode und das SDK vom System, die Shell bringt die Rust-Ziele für macOS und iOS sowie CocoaPods mit. Ist zusätzlich `rustup` installiert, nimmt `packages/gridline_native/scripts/build_apple.sh` dessen `cargo` aus `~/.cargo/bin`.

## Kern bauen und testen

```bash
cargo test --workspace
cargo run --release -p gridline-core --example render_demo -- demo.wav 4   # Demo-Pattern als WAV
```

## Echtzeit-Regeln

`Renderer::render` läuft im Audio-Thread. Alles, was von dort erreichbar ist, darf weder blockieren noch allokieren. Befehle und neue Snapshots kommen über einen lock-freien Ring (`rtrb`), ersetzte Snapshots gehen über einen zweiten Ring zurück und werden auf dem UI-Thread freigegeben.

## Lizenz

MIT, siehe [LICENSE](LICENSE).
