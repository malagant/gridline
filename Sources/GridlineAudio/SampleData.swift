import AVFoundation
import Foundation

/// Unveränderliche, dekodierte Sample-Daten (Float32, nicht interleaved).
public final class SampleData: @unchecked Sendable {
    public let left: [Float]
    public let right: [Float]
    public let sampleRate: Double

    public var frameCount: Int { left.count }

    public init(left: [Float], right: [Float], sampleRate: Double) {
        precondition(left.count == right.count, "Kanäle müssen gleich lang sein")
        self.left = left
        self.right = right
        self.sampleRate = sampleRate
    }

    public convenience init(mono: [Float], sampleRate: Double) {
        self.init(left: mono, right: mono, sampleRate: sampleRate)
    }

    public enum LoadError: Error {
        case unreadable(URL)
    }

    /// Lädt WAV, AIFF, CAF usw. über AVAudioFile.
    public static func load(url: URL) throws -> SampleData {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        let capacity = AVAudioFrameCount(file.length)
        guard capacity > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw LoadError.unreadable(url)
        }
        try file.read(into: buffer)
        guard let channels = buffer.floatChannelData else { throw LoadError.unreadable(url) }
        let n = Int(buffer.frameLength)
        let left = Array(UnsafeBufferPointer(start: channels[0], count: n))
        let right = format.channelCount > 1 ? Array(UnsafeBufferPointer(start: channels[1], count: n)) : left
        return SampleData(left: left, right: right, sampleRate: format.sampleRate)
    }
}
