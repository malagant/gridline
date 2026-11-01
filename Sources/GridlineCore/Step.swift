import Foundation

public enum EffectKind: String, Hashable, Codable, CaseIterable, Sendable {
    case retrigger = "R"
    case arpeggio = "A"
    case slide = "S"
    case volumeSlide = "V"
    case microtime = "M"
    case chance = "C"
}

public struct StepEffect: Hashable, Codable, Sendable {
    public var kind: EffectKind
    /// 0...99
    public var value: Int

    public init(kind: EffectKind, value: Int) {
        self.kind = kind
        self.value = min(max(value, 0), 99)
    }
}

/// Eine Zelle im Pattern: Note, Instrument, Lautstärke und zwei Effektspalten.
public struct Step: Hashable, Codable, Sendable {
    public var note: StepNote
    /// Index in `Song.instruments` (0-basiert). `nil` = letztes Instrument der Spur.
    public var instrument: Int?
    /// 0...100, `nil` = Instrumentlautstärke.
    public var volume: Int?
    public var fx1: StepEffect?
    public var fx2: StepEffect?

    public init(note: StepNote = .empty, instrument: Int? = nil, volume: Int? = nil,
                fx1: StepEffect? = nil, fx2: StepEffect? = nil) {
        self.note = note
        self.instrument = instrument
        self.volume = volume.map { min(max($0, 0), 100) }
        self.fx1 = fx1
        self.fx2 = fx2
    }

    public var isEmpty: Bool {
        note == .empty && instrument == nil && volume == nil && fx1 == nil && fx2 == nil
    }

    public static let empty = Step()
}

/// Textdarstellung der Spalten für das Pattern-Grid.
public enum StepFormatter {
    public static func note(_ step: Step) -> String {
        switch step.note {
        case .empty: return "---"
        case .off: return "OFF"
        case .note(let midi): return NoteName.string(for: Int(midi))
        }
    }

    /// 1-basiert, wie es Musiker lesen.
    public static func instrument(_ step: Step) -> String {
        step.instrument.map { String(format: "%02d", $0 + 1) } ?? "--"
    }

    public static func volume(_ step: Step) -> String {
        guard let v = step.volume else { return "--" }
        return v >= 100 ? "FF" : String(format: "%02d", v)
    }

    public static func effect(_ fx: StepEffect?) -> String {
        guard let fx else { return "---" }
        return fx.kind.rawValue + String(format: "%02d", fx.value)
    }
}
