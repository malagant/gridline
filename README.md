# Gridline

Gridline ist ein Pattern-Sequencer im Tracker-Stil für macOS, Linux, iPhone und iPad: Spuren laufen senkrecht, jede Zeile ist ein Step, gespielt werden Sample-Instrumente. Die Arbeitsweise ist von Hardware-Trackern inspiriert. Gridline ist ein eigenständiges Projekt mit eigenem Design und eigenen Klängen und steht in keiner Verbindung zu Herstellern solcher Geräte.

## Aufbau

| Teil | Inhalt |
| --- | --- |
| `crates/gridline-core` | Rust: Datenmodell, sample-genaue Step-Uhr, lock-freier Echtzeit-Renderer, eingebaute Klänge, WAV-Leser/-Schreiber, Projektformat |
| Flutter-App (folgt) | Oberfläche für alle Plattformen, Audio-Ausgabe über cpal |

## Kern bauen und testen

```bash
cargo test --workspace
cargo run --release -p gridline-core --example render_demo -- demo.wav 4   # Demo-Pattern als WAV
```

## Echtzeit-Regeln

`Renderer::render` läuft im Audio-Thread. Alles, was von dort erreichbar ist, darf weder blockieren noch allokieren. Befehle und neue Snapshots kommen über einen lock-freien Ring (`rtrb`), ersetzte Snapshots gehen über einen zweiten Ring zurück und werden auf dem UI-Thread freigegeben.

## Lizenz

MIT, siehe [LICENSE](LICENSE).
