import Foundation

public struct Pattern: Hashable, Codable, Sendable {
    public static let maxLength = 128

    /// Aktive Länge in Steps (1...128). Daten jenseits der Länge bleiben erhalten.
    public private(set) var length: Int
    /// `tracks[track][step]`, jede Spur hat immer `maxLength` Steps.
    public private(set) var tracks: [[Step]]

    public init(trackCount: Int = Song.trackCount, length: Int = 16) {
        self.length = Self.clampLength(length)
        self.tracks = Array(repeating: Array(repeating: .empty, count: Self.maxLength), count: trackCount)
    }

    public var trackCount: Int { tracks.count }

    public mutating func setLength(_ newLength: Int) {
        length = Self.clampLength(newLength)
    }

    public subscript(track: Int, step: Int) -> Step {
        get {
            guard tracks.indices.contains(track), tracks[track].indices.contains(step) else { return .empty }
            return tracks[track][step]
        }
        set {
            guard tracks.indices.contains(track), tracks[track].indices.contains(step) else { return }
            tracks[track][step] = newValue
        }
    }

    private static func clampLength(_ value: Int) -> Int {
        min(max(value, 1), maxLength)
    }
}
