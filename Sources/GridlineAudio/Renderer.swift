import Foundation
import GridlineCore

/// Echtzeit-Renderer: Sequencer + Stimmen. `render` läuft im Audio-Thread,
/// alle anderen Methoden auf beliebigen Threads (typisch: Main).
///
/// Austausch zwischen den Threads läuft über einen kurzen Lock, den der Audio-Thread
/// nur per `tryLock` nimmt. Klappt das nicht, rendert er mit dem bisherigen Zustand weiter.
public final class Renderer: @unchecked Sendable {
    public struct Snapshot: Sendable {
        public var song: Song
        /// Ein Eintrag pro Instrument in `song.instruments`.
        public var samples: [SampleData?]
        public var patternIndex: Int

        public init(song: Song, samples: [SampleData?], patternIndex: Int = 0) {
            self.song = song
            self.samples = samples
            self.patternIndex = patternIndex
        }
    }

    public enum Command: Sendable {
        case play(fromStep: Int)
        case stop
        case audition(track: Int, note: Int, instrument: Int)
        case release(track: Int)
    }

    public let sampleRate: Double

    // Geteilter Zustand, nur unter `lock`.
    private let lock = UnfairLock()
    private var pendingSnapshot: Snapshot?
    private var pendingCommands: [Command] = []
    private var sharedPlayhead = -1

    // Gehört dem Audio-Thread.
    private var snapshot: Snapshot
    private var clock: StepClock
    private var voices: [Voice]
    private var lastInstrument: [Int]
    private var playing = false
    private var currentStep = -1
    private var events: [(offset: Int, step: Int)] = []
    private var commandScratch: [Command] = []

    public static let masterGain: Float = 0.7

    public init(sampleRate: Double, snapshot: Snapshot) {
        self.sampleRate = sampleRate
        self.snapshot = snapshot
        self.clock = StepClock(sampleRate: sampleRate, bpm: snapshot.song.bpm)
        self.voices = Array(repeating: Voice(), count: Song.trackCount)
        self.lastInstrument = Array(repeating: 0, count: Song.trackCount)
        events.reserveCapacity(256)
        commandScratch.reserveCapacity(64)
        pendingCommands.reserveCapacity(64)
    }

    // MARK: Steuerung (beliebiger Thread)

    public func update(_ snapshot: Snapshot) {
        lock.withLock { pendingSnapshot = snapshot }
    }

    public func send(_ command: Command) {
        lock.withLock { pendingCommands.append(command) }
    }

    /// Aktuell spielender Step, -1 wenn gestoppt.
    public var playhead: Int {
        lock.withLock { sharedPlayhead }
    }

    // MARK: Audio-Thread

    public func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        left.update(repeating: 0, count: frames)
        right.update(repeating: 0, count: frames)

        if lock.tryLock() {
            if let next = pendingSnapshot {
                snapshot = next
                pendingSnapshot = nil
            }
            swap(&commandScratch, &pendingCommands)
            lock.unlock()
        }
        for command in commandScratch { apply(command) }
        commandScratch.removeAll(keepingCapacity: true)

        clock.bpm = snapshot.song.bpm
        let patterns = snapshot.song.patterns
        let pattern = patterns.indices.contains(snapshot.patternIndex) ? patterns[snapshot.patternIndex] : patterns[0]

        var cursor = 0
        if playing {
            events.removeAll(keepingCapacity: true)
            clock.advance(frames: frames, stepCount: pattern.length) { offset, step in
                events.append((offset, step))
            }
            for event in events {
                renderVoices(from: cursor, to: event.offset, left: left, right: right)
                trigger(step: event.step, in: pattern)
                currentStep = event.step
                cursor = event.offset
            }
        }
        renderVoices(from: cursor, to: frames, left: left, right: right)

        let gain = Self.masterGain
        for i in 0..<frames {
            left[i] = tanhf(left[i] * gain)
            right[i] = tanhf(right[i] * gain)
        }

        if lock.tryLock() {
            sharedPlayhead = playing ? currentStep : -1
            lock.unlock()
        }
    }

    private func renderVoices(from start: Int, to end: Int, left: UnsafeMutablePointer<Float>,
                              right: UnsafeMutablePointer<Float>) {
        guard end > start else { return }
        for v in voices.indices where voices[v].isActive {
            voices[v].render(left: left + start, right: right + start, frames: end - start)
        }
    }

    private func apply(_ command: Command) {
        switch command {
        case .play(let step):
            playing = true
            currentStep = -1
            clock.reset(to: step)
        case .stop:
            playing = false
            currentStep = -1
            for v in voices.indices { voices[v].noteOff() }
        case .audition(let track, let note, let instrument):
            start(track: track, note: note, instrument: instrument, volume: nil)
        case .release(let track):
            if voices.indices.contains(track) { voices[track].noteOff() }
        }
    }

    private func trigger(step index: Int, in pattern: Pattern) {
        for track in 0..<min(voices.count, pattern.trackCount) {
            let step = pattern[track, index]
            switch step.note {
            case .empty:
                break
            case .off:
                voices[track].noteOff()
            case .note(let midi):
                let instrument = step.instrument ?? lastInstrument[track]
                start(track: track, note: Int(midi), instrument: instrument, volume: step.volume)
            }
        }
    }

    private func start(track: Int, note: Int, instrument index: Int, volume: Int?) {
        guard voices.indices.contains(track),
              snapshot.song.instruments.indices.contains(index),
              snapshot.samples.indices.contains(index),
              let sample = snapshot.samples[index] else { return }
        let instrument = snapshot.song.instruments[index]
        lastInstrument[track] = index
        let stepGain = volume.map { Double($0) / 100 } ?? 1
        voices[track].trigger(
            sample: sample,
            ratio: Pitch.ratio(note: note, root: instrument.rootNote, tune: instrument.tune),
            outputRate: sampleRate,
            gain: Float(instrument.volume * stepGain),
            attack: instrument.attack,
            release: instrument.release,
            loop: instrument.loop
        )
    }
}
