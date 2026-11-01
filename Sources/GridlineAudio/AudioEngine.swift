#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// Verbindet den `Renderer` mit dem Audio-Ausgang des Macs.
public final class AudioEngine {
    private let engine: AVAudioEngine
    private let sourceNode: AVAudioSourceNode
    public let renderer: Renderer

    public init(snapshot: Renderer.Snapshot) {
        #if os(iOS)
        Self.configureAudioSession()
        #endif
        let engine = AVAudioEngine()
        self.engine = engine
        let hardwareRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = hardwareRate > 0 ? hardwareRate : 48_000
        let renderer = Renderer(sampleRate: sampleRate, snapshot: snapshot)
        self.renderer = renderer

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard buffers.count >= 2,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            renderer.render(frames: Int(frameCount), left: left, right: right)
            return noErr
        }
        self.sourceNode = sourceNode
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
    }

    public var sampleRate: Double { renderer.sampleRate }

    public func start() throws {
        engine.prepare()
        try engine.start()
    }

    public func stop() {
        engine.stop()
    }

    #if os(iOS)
    /// Wiedergabe auch im Stumm-Modus, kurze Puffer für niedrige Latenz.
    private static func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setPreferredIOBufferDuration(0.005)
        try? session.setActive(true)
    }
    #endif
}
#endif
