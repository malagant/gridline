import Foundation

/// Importierte Samples werden in den App-Container kopiert, damit sie auch auf iOS
/// nach einem Neustart noch lesbar sind.
enum SampleLibrary {
    static func directory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("Gridline/Samples", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func importFile(_ source: URL) throws -> URL {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let dir = try directory()
        var target = dir.appendingPathComponent(source.lastPathComponent)
        if FileManager.default.fileExists(atPath: target.path) {
            target = dir.appendingPathComponent("\(UUID().uuidString.prefix(8))-\(source.lastPathComponent)")
        }
        try FileManager.default.copyItem(at: source, to: target)
        return target
    }
}
