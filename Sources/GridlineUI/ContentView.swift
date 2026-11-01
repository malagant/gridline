import GridlineCore
import SwiftUI

/// Hauptansicht für alle Plattformen.
/// macOS: Grid + Instrumente, Bedienung per Tastatur.
/// iPad: Grid + Instrumente nebeneinander, Bildschirm-Klaviatur unten.
/// iPhone: Grid mit Klaviatur, Instrumente als Sheet.
public struct ContentView: View {
    @EnvironmentObject private var state: AppState
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showInstruments = false
    #endif

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            TransportBar(onShowInstruments: showInstrumentsAction)
            Divider()
            HStack(spacing: 0) {
                PatternGridView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if showsSidePanel {
                    Divider()
                    InstrumentPanel()
                        .frame(width: 250)
                }
            }
            #if os(iOS)
            Divider()
            TouchKeyboard()
            #endif
            Divider()
            StatusBar()
        }
        .background(Theme.background)
        #if os(iOS)
        .sheet(isPresented: $showInstruments) {
            NavigationStack {
                InstrumentPanel()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig") { showInstruments = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .environmentObject(state)
        }
        #endif
    }

    private var showsSidePanel: Bool {
        #if os(iOS)
        return sizeClass == .regular
        #else
        return true
        #endif
    }

    private var showInstrumentsAction: (() -> Void)? {
        #if os(iOS)
        if sizeClass != .regular { return { showInstruments = true } }
        #endif
        return nil
    }
}

struct TransportBar: View {
    @EnvironmentObject private var state: AppState
    /// Gesetzt, wenn Instrumente nicht dauerhaft sichtbar sind (iPhone).
    var onShowInstruments: (() -> Void)?

    var body: some View {
        HStack(spacing: 16) {
            Button(action: state.togglePlay) {
                Label(state.isPlaying ? "Stopp" : "Play", systemImage: state.isPlaying ? "stop.fill" : "play.fill")
                    .frame(minWidth: 70)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .foregroundStyle(Theme.background)
            .controlSize(.large)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    Stepper(value: $state.song.bpm, in: Song.bpmRange, step: 1) {
                        Text("BPM \(Int(state.song.bpm))").font(Theme.monoBold)
                    }
                    .fixedSize()

                    Stepper(value: Binding(get: { state.currentPattern.length },
                                           set: { state.setPatternLength($0) }),
                            in: 1...GridPattern.maxLength) {
                        Text("Länge \(state.currentPattern.length)").font(Theme.monoBold)
                    }
                    .fixedSize()

                    Stepper(value: $state.octave, in: 0...8) {
                        Text("Oktave \(state.octave)").font(Theme.monoBold)
                    }
                    .fixedSize()
                }
            }

            if let onShowInstruments {
                Button(action: onShowInstruments) {
                    Image(systemName: "pianokeys")
                }
                .controlSize(.large)
                .accessibilityLabel("Instrumente")
            } else {
                Text("GRIDLINE")
                    .font(.system(size: 15, weight: .heavy, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(Theme.accent)
            }
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
            #if os(macOS)
            Text("Pfeile: bewegen  ·  ⇧↑/⇧↓: Oktave  ·  Y–M / Q–U: Noten  ·  A: Note aus  ·  ⌫: löschen  ·  Leertaste: Play/Stopp")
                .foregroundStyle(Theme.dim)
            #endif
            Spacer()
            if let message = state.statusMessage {
                Text(message).foregroundStyle(Theme.text).lineLimit(1)
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.panel)
    }
}
