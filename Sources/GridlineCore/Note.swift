import Foundation

/// Inhalt der Notenspalte eines Steps.
public enum StepNote: Hashable, Codable, Sendable {
    case empty
    case note(UInt8)
    case off
}

public enum NoteName {
    /// Spielbarer Notenbereich (C-0 bis B-8).
    public static let playableRange = 12...119

    private static let names = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"]

    /// Tracker-Schreibweise, MIDI 60 = "C-4".
    public static func string(for midi: Int) -> String {
        let clamped = min(max(midi, playableRange.lowerBound), playableRange.upperBound)
        return names[clamped % 12] + String(clamped / 12 - 1)
    }
}

public enum Pitch {
    /// Abspielverhältnis für eine Note relativ zum Grundton des Samples.
    public static func ratio(note: Int, root: Int = 60, tune: Double = 0) -> Double {
        pow(2.0, (Double(note - root) + tune) / 12.0)
    }
}
