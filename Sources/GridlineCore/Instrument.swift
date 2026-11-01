import Foundation

/// Eingebaute, im Code erzeugte Klänge. Keine fremden Samples.
public enum BuiltinSound: String, Hashable, Codable, CaseIterable, Sendable {
    case kick, snare, hat, pluck, bass
}

public enum SampleSource: Hashable, Codable, Sendable {
    case none
    case builtin(BuiltinSound)
    case file(path: String)
}

public struct Instrument: Hashable, Codable, Sendable {
    public static let slotCount = 16

    public var name: String
    public var source: SampleSource
    /// 0...1
    public var volume: Double
    /// Halbtöne, darf gebrochen sein (Feinstimmung).
    public var tune: Double
    /// Note, auf der das Sample unverändert klingt.
    public var rootNote: Int
    /// Sekunden
    public var attack: Double
    /// Sekunden
    public var release: Double
    public var loop: Bool

    public init(name: String, source: SampleSource = .none, volume: Double = 0.8, tune: Double = 0,
                rootNote: Int = 60, attack: Double = 0.002, release: Double = 0.05, loop: Bool = false) {
        self.name = name
        self.source = source
        self.volume = volume
        self.tune = tune
        self.rootNote = rootNote
        self.attack = attack
        self.release = release
        self.loop = loop
    }

    public static func emptySlot() -> Instrument {
        Instrument(name: "—")
    }
}
