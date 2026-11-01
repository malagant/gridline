# Gridline

Gridline ist ein Pattern-Sequencer im Tracker-Stil für macOS: Spuren laufen senkrecht, jede Zeile ist ein Step, gespielt werden Sample-Instrumente. Die Arbeitsweise ist von Hardware-Trackern inspiriert. Gridline ist ein eigenständiges Projekt mit eigenem Design und eigenen Klängen und steht in keiner Verbindung zu Herstellern solcher Geräte.

## Stand (0.1)

- 8 Spuren, Pattern mit 1 bis 128 Steps, Spalten Note, Instrument, Lautstärke, Effekt
- Sample-genaue Step-Uhr im Audio-Thread (AVAudioEngine, eigener Render-Callback)
- 16 Instrument-Slots, 5 eingebaute, synthetisch erzeugte Klänge, eigene Samples (WAV/AIFF/CAF) ladbar
- Pro Instrument Lautstärke, Stimmung, Attack, Release, Loop
- Komplette Tastaturbedienung, Belegung nach physischer Tastenposition (QWERTZ und QWERTY)

## Tastatur

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

## Bauen

Voraussetzung: macOS 14 oder neuer, Xcode 16 (Swift 5.10+).

```bash
swift run Gridline            # direkt starten
swift test                    # Tests
./scripts/make-app.sh         # build/Gridline.app und build/Gridline.zip
```

Jeder CI-Lauf legt außerdem `Gridline.zip` als Artefakt ab. Die App ist nur ad-hoc signiert. Beim ersten Start daher per Rechtsklick → Öffnen starten oder `xattr -dr com.apple.quarantine Gridline.app` ausführen.

## Aufbau

| Modul | Inhalt |
| --- | --- |
| `GridlineCore` | Datenmodell (Song, Pattern, Step, Instrument), Step-Uhr, Projektformat. Nur Foundation. |
| `GridlineAudio` | Sample-Daten, eingebaute Klänge, Stimmen, Echtzeit-Renderer, AVAudioEngine-Anbindung |
| `Gridline` | SwiftUI-App |

## Roadmap

1. Step-Effekte im Renderer (Retrigger, Arpeggio, Slide, Microtiming, Zufall)
2. Song-Ansicht mit Pattern-Kette, mehrere Patterns
3. Speichern und Laden (`.gridline`, Format existiert bereits in `ProjectFile`)
4. WAV-Export
5. Master-Effekte (Delay, Reverb), Sample-Editor mit Start/Ende/Slices
6. MIDI-In und -Out, Performance-Modus

## Lizenz

MIT, siehe [LICENSE](LICENSE).
