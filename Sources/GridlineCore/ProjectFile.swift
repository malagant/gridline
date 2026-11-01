import Foundation

/// Projektformat: JSON mit Versionsfeld. Samples liegen als Dateipfade daneben.
public enum ProjectFile {
    public static let formatVersion = 1
    public static let fileExtension = "gridline"

    public enum Error: Swift.Error, Equatable {
        case unsupportedVersion(Int)
    }

    private struct Document: Codable {
        var formatVersion: Int
        var song: Song
    }

    public static func encode(_ song: Song) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Document(formatVersion: formatVersion, song: song))
    }

    public static func decode(_ data: Data) throws -> Song {
        let doc = try JSONDecoder().decode(Document.self, from: data)
        guard doc.formatVersion <= formatVersion else { throw Error.unsupportedVersion(doc.formatVersion) }
        return doc.song
    }
}
