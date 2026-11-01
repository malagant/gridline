import SwiftUI

/// Bildschirm-Klaviatur und Editier-Tasten für Touch-Bedienung (iPhone, iPad).
struct TouchKeyboard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                KeyButton(systemImage: "minus", label: "Oktave runter") { state.shiftOctave(-1) }
                Text("OKT \(state.octave)").font(Theme.monoBold).foregroundStyle(Theme.text).frame(width: 64)
                KeyButton(systemImage: "plus", label: "Oktave hoch") { state.shiftOctave(1) }
                Spacer(minLength: 8)
                KeyButton(systemImage: "chevron.left", label: "Spur links") { state.moveCursor(track: -1) }
                KeyButton(systemImage: "chevron.up", label: "Step hoch") { state.moveCursor(step: -1) }
                KeyButton(systemImage: "chevron.down", label: "Step runter") { state.moveCursor(step: 1) }
                KeyButton(systemImage: "chevron.right", label: "Spur rechts") { state.moveCursor(track: 1) }
                Spacer(minLength: 8)
                KeyButton(title: "OFF", label: "Note aus") { state.enterNoteOff() }
                KeyButton(systemImage: "delete.left", label: "Step löschen") { state.clearStep() }
            }
            PianoKeys { semitone in state.enterNote(semitone: semitone) }
                .frame(height: 110)
        }
        .padding(10)
        .background(Theme.panel)
    }
}

private struct KeyButton: View {
    var title: String?
    var systemImage: String?
    let label: String
    let action: () -> Void

    init(title: String? = nil, systemImage: String? = nil, label: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage { Image(systemName: systemImage) } else { Text(title ?? "").font(Theme.monoBold) }
            }
            .frame(minWidth: 36, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(label)
    }
}

/// Eine Oktave plus oberes C. Löst beim Berühren aus, nicht erst beim Loslassen.
private struct PianoKeys: View {
    let onNote: (Int) -> Void

    private static let whiteSemitones = [0, 2, 4, 5, 7, 9, 11, 12]
    /// (Index der weißen Taste links davon, Halbton)
    private static let blackKeys = [(0, 1), (1, 3), (3, 6), (4, 8), (5, 10)]
    private static let names = ["C", "D", "E", "F", "G", "A", "H", "C"]

    var body: some View {
        GeometryReader { geo in
            let whiteWidth = geo.size.width / CGFloat(Self.whiteSemitones.count)
            let blackWidth = whiteWidth * 0.6
            ZStack(alignment: .topLeading) {
                HStack(spacing: 2) {
                    ForEach(Self.whiteSemitones.indices, id: \.self) { i in
                        PianoKey(isBlack: false, caption: Self.names[i]) { onNote(Self.whiteSemitones[i]) }
                    }
                }
                ForEach(Self.blackKeys.indices, id: \.self) { i in
                    let key = Self.blackKeys[i]
                    PianoKey(isBlack: true, caption: nil) { onNote(key.1) }
                        .frame(width: blackWidth, height: geo.size.height * 0.6)
                        .offset(x: CGFloat(key.0 + 1) * whiteWidth - blackWidth / 2)
                }
            }
        }
    }
}

private struct PianoKey: View {
    let isBlack: Bool
    let caption: String?
    let onPress: () -> Void
    @State private var isPressed = false

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(fill)
            .overlay(alignment: .bottom) {
                if let caption {
                    Text(caption).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.dim).padding(.bottom, 6)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onPress()
                        }
                    }
                    .onEnded { _ in isPressed = false }
            )
    }

    private var fill: Color {
        if isPressed { return Theme.accent }
        return isBlack ? Color(white: 0.12) : Color(white: 0.82)
    }
}
