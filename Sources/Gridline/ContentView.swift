import GridlineCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            TransportBar()
            Divider()
            HStack(spacing: 0) {
                PatternGridView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                InstrumentPanel()
                    .frame(width: 240)
            }
            Divider()
            StatusBar()
        }
        .background(Theme.background)
    }
}

struct TransportBar: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 20) {
            Button(action: state.togglePlay) {
                Label(state.isPlaying ? "Stopp" : "Play", systemImage: state.isPlaying ? "stop.fill" : "play.fill")
                    .frame(width: 70)
            }
            .controlSize(.large)

            Stepper(value: $state.song.bpm, in: Song.bpmRange, step: 1) {
                Text("BPM \(Int(state.song.bpm))").font(Theme.monoBold)
            }

            Stepper(value: Binding(get: { state.currentPattern.length },
                                   set: { state.setPatternLength($0) }),
                    in: 1...Pattern.maxLength) {
                Text("Länge \(state.currentPattern.length)").font(Theme.monoBold)
            }

            Stepper(value: $state.octave, in: 0...8) {
                Text("Oktave \(state.octave)").font(Theme.monoBold)
            }

            Spacer()

            Text("GRIDLINE")
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.panel)
    }
}

struct StatusBar: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack {
            Text("Pfeile: bewegen  ·  ⇧↑/⇧↓: Oktave  ·  Y–M / Q–U: Noten  ·  A: Note aus  ·  ⌫: löschen  ·  Leertaste: Play/Stopp")
                .foregroundStyle(Theme.dim)
            Spacer()
            if let message = state.statusMessage {
                Text(message).foregroundStyle(Theme.text)
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.panel)
    }
}
