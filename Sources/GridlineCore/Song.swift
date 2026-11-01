import Foundation

public struct Song: Hashable, Codable, Sendable {
    public static let trackCount = 8
    public static let bpmRange: ClosedRange<Double> = 40...300

    public var name: String
    public var bpm: Double {
        didSet { bpm = min(max(bpm, Self.bpmRange.lowerBound), Self.bpmRange.upperBound) }
    }
    public var patterns: [Pattern]
    public var instruments: [Instrument]

    public init(name: String = "Neuer Song", bpm: Double = 120,
                patterns: [Pattern] = [Pattern()],
                instruments: [Instrument] = (0..<Instrument.slotCount).map { _ in .emptySlot() }) {
        self.name = name
        self.bpm = min(max(bpm, Self.bpmRange.lowerBound), Self.bpmRange.upperBound)
        self.patterns = patterns.isEmpty ? [Pattern()] : patterns
        self.instruments = instruments
    }

    /// Kleiner Startsong mit eingebauten Klängen, damit nach dem Start sofort etwas zu hören ist.
    public static func demo() -> Song {
        var instruments: [Instrument] = [
            Instrument(name: "Kick", source: .builtin(.kick), volume: 0.9),
            Instrument(name: "Snare", source: .builtin(.snare), volume: 0.7),
            Instrument(name: "Hat", source: .builtin(.hat), volume: 0.5),
            Instrument(name: "Pluck", source: .builtin(.pluck), volume: 0.6, release: 0.2),
            Instrument(name: "Bass", source: .builtin(.bass), volume: 0.7, release: 0.08),
        ]
        while instruments.count < Instrument.slotCount { instruments.append(.emptySlot()) }

        var p = Pattern(length: 16)
        for s in stride(from: 0, to: 16, by: 4) { p[0, s] = Step(note: .note(60), instrument: 0) }
        for s in [4, 12] { p[1, s] = Step(note: .note(60), instrument: 1) }
        for s in stride(from: 2, to: 16, by: 4) { p[2, s] = Step(note: .note(60), instrument: 2, volume: 60) }
        for (s, n) in [(0, 72), (3, 75), (6, 79), (10, 77), (13, 74)] {
            p[3, s] = Step(note: .note(UInt8(n)), instrument: 3)
        }
        for (s, n) in [(0, 36), (6, 36), (8, 39), (14, 34)] { p[4, s] = Step(note: .note(UInt8(n)), instrument: 4) }
        p[4, 11] = Step(note: .off)

        return Song(name: "Demo", bpm: 118, patterns: [p], instruments: instruments)
    }
}
