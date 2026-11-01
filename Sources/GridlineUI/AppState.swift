import Combine
import Foundation
import GridlineAudio
import GridlineCore
#if os(macOS)
import AppKit
#endif

@MainActor
public final class AppState: ObservableObject {
    @Published public var song: Song {
        didSet { pushSnapshot() }
    }
    @Published public var cursorTrack = 0
    @Published public var cursorStep = 0
    @Published public var octave = 4
    @Published public var selectedInstrument = 0
    @Published public private(set) var isPlaying = false
    @Published public private(set) var playhead = -1
    @Published public var statusMessage: String?

    let patternIndex = 0

    private var samples: [SampleData?]
    private var engine: AudioEngine?
    private var playheadTimer: Timer?
    #if os(macOS)
    private var keyMonitor: Any?
    #endif

    public init() {
        let song = Song.demo()
        self.song = song
        self.samples = song.instruments.map { Self.makeSample(for: $0.source) }

        let engine = AudioEngine(snapshot: Renderer.Snapshot(song: song, samples: samples, patternIndex: 0))
        do {
            try engine.start()
            self.engine = engine
        } catch {
            statusMessage = "Audio konnte nicht gestartet werden: \(error.localizedDescription)"
        }

        playheadTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPlayhead() }
        }
        #if os(macOS)
        installKeyMonitor()
        #endif
    }

    var currentPattern: GridPattern { song.patterns[patternIndex] }

    // MARK: Transport

    func togglePlay() {
        if isPlaying {
            engine?.renderer.send(.stop)
            isPlaying = false
        } else {
            engine?.renderer.send(.play(fromStep: 0))
            isPlaying = true
        }
    }

    func setPatternLength(_ length: Int) {
        song.patterns[patternIndex].setLength(length)
        cursorStep = min(cursorStep, currentPattern.length - 1)
    }

    // MARK: Editieren

    func moveCursor(track delta: Int) {
        cursorTrack = (cursorTrack + delta + Song.trackCount) % Song.trackCount
    }

    func moveCursor(step delta: Int) {
        let length = currentPattern.length
        cursorStep = ((cursorStep + delta) % length + length) % length
    }

    func shiftOctave(_ delta: Int) {
        octave = min(max(octave + delta, 0), 8)
    }

    /// Note relativ zur aktuellen Oktave (0 = C der Oktave).
    func enterNote(semitone: Int) {
        enterNote((octave + 1) * 12 + semitone)
    }

    func enterNote(_ midi: Int) {
        let note = min(max(midi, NoteName.playableRange.lowerBound), NoteName.playableRange.upperBound)
        var step = song.patterns[patternIndex][cursorTrack, cursorStep]
        step.note = .note(UInt8(note))
        step.instrument = selectedInstrument
        song.patterns[patternIndex][cursorTrack, cursorStep] = step
        engine?.renderer.send(.audition(track: cursorTrack, note: note, instrument: selectedInstrument))
        moveCursor(step: 1)
    }

    func enterNoteOff() {
        song.patterns[patternIndex][cursorTrack, cursorStep] = Step(note: .off)
        moveCursor(step: 1)
    }

    func clearStep() {
        song.patterns[patternIndex][cursorTrack, cursorStep] = .empty
        moveCursor(step: 1)
    }

    // MARK: Instrumente

    func importSample(from url: URL) {
        do {
            let stored = try SampleLibrary.importFile(url)
            let sample = try SampleData.load(url: stored)
            let index = selectedInstrument
            samples[index] = sample
            song.instruments[index].source = .file(path: stored.path)
            song.instruments[index].name = url.deletingPathExtension().lastPathComponent
            statusMessage = "Geladen: \(url.lastPathComponent)"
        } catch {
            statusMessage = "Sample konnte nicht geladen werden: \(error.localizedDescription)"
        }
    }

    // MARK: Intern

    private static func makeSample(for source: SampleSource) -> SampleData? {
        switch source {
        case .none: return nil
        case .builtin(let sound): return BuiltinSamples.make(sound)
        case .file(let path): return try? SampleData.load(url: URL(fileURLWithPath: path))
        }
    }

    private func pushSnapshot() {
        engine?.renderer.update(Renderer.Snapshot(song: song, samples: samples, patternIndex: patternIndex))
    }

    private func pollPlayhead() {
        let value = engine?.renderer.playhead ?? -1
        if value != playhead { playhead = value }
    }

    #if os(macOS)
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Texteingaben (z. B. Felder) nicht abfangen.
            if NSApp.keyWindow?.firstResponder is NSText { return event }
            let handled = MainActor.assumeIsolated { self?.handleKey(event) ?? false }
            return handled ? nil : event
        }
    }

    /// Belegung nach physischer Tastenposition, unabhängig vom Layout (QWERTZ/QWERTY).
    private static let pianoKeys: [UInt16: Int] = [
        // untere Reihe: Y/Z S X D C V G B H N J M
        6: 0, 1: 1, 7: 2, 2: 3, 8: 4, 9: 5, 5: 6, 11: 7, 4: 8, 45: 9, 38: 10, 46: 11,
        // obere Reihe: Q 2 W 3 E R 5 T 6 Z/Y 7 U  (eine Oktave höher)
        12: 12, 19: 13, 13: 14, 20: 15, 14: 16, 15: 17, 23: 18, 17: 19, 22: 20, 16: 21, 26: 22, 32: 23,
    ]

    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) { return false }
        let shift = flags.contains(.shift)

        switch event.keyCode {
        case 49: togglePlay()                                   // Leertaste
        case 126: if shift { shiftOctave(1) } else { moveCursor(step: -1) }
        case 125: if shift { shiftOctave(-1) } else { moveCursor(step: 1) }
        case 123: moveCursor(track: -1)
        case 124: moveCursor(track: 1)
        case 116: moveCursor(step: -16)                         // Bild hoch
        case 121: moveCursor(step: 16)                          // Bild runter
        case 51, 117: clearStep()                               // Löschen
        case 0: enterNoteOff()                                  // A
        default:
            guard let semitone = Self.pianoKeys[event.keyCode] else { return false }
            if !event.isARepeat { enterNote(semitone: semitone) }
        }
        return true
    }
    #endif
}
