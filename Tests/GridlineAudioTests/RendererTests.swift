import XCTest
@testable import GridlineAudio
import GridlineCore

final class RendererTests: XCTestCase {
    private let sampleRate = 48_000.0

    private func makeRenderer(song: Song) -> Renderer {
        let samples = song.instruments.map { instrument -> SampleData? in
            if case .builtin(let sound) = instrument.source { return BuiltinSamples.make(sound, sampleRate: sampleRate) }
            return nil
        }
        return Renderer(sampleRate: sampleRate, snapshot: .init(song: song, samples: samples))
    }

    private func render(_ renderer: Renderer, frames: Int) -> (left: [Float], right: [Float]) {
        var left = [Float](repeating: 1, count: frames)
        var right = [Float](repeating: 1, count: frames)
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                renderer.render(frames: frames, left: l.baseAddress!, right: r.baseAddress!)
            }
        }
        return (left, right)
    }

    func testSilentWhenStopped() {
        let renderer = makeRenderer(song: .demo())
        let out = render(renderer, frames: 1024)
        XCTAssertTrue(out.left.allSatisfy { $0 == 0 })
        XCTAssertEqual(renderer.playhead, -1)
    }

    func testPlaysDemoPattern() {
        let renderer = makeRenderer(song: .demo())
        renderer.send(.play(fromStep: 0))
        let out = render(renderer, frames: 2048)
        XCTAssertGreaterThan(out.left.map(abs).max() ?? 0, 0.05)
        XCTAssertEqual(renderer.playhead, 0)
        XCTAssertTrue(out.left.allSatisfy { $0.isFinite && abs($0) <= 1 })
    }

    func testPlayheadAdvances() {
        let renderer = makeRenderer(song: .demo())
        renderer.send(.play(fromStep: 0))
        // 118 BPM → ca. 6102 Samples pro Step; nach 3 Steps muss Step 3 laufen.
        let perStep = Int(sampleRate * 60 / 118 / 4)
        var rendered = 0
        while rendered < perStep * 3 + 10 {
            _ = render(renderer, frames: 512)
            rendered += 512
        }
        XCTAssertEqual(renderer.playhead, 3)
    }

    func testAuditionWithoutTransport() {
        let renderer = makeRenderer(song: .demo())
        renderer.send(.audition(track: 0, note: 60, instrument: 3))
        let out = render(renderer, frames: 1024)
        XCTAssertGreaterThan(out.right.map(abs).max() ?? 0, 0.01)
        XCTAssertEqual(renderer.playhead, -1)
    }

    func testEmptyInstrumentIsIgnored() {
        var song = Song.demo()
        song.patterns[0] = Pattern()
        song.patterns[0][0, 0] = Step(note: .note(60), instrument: 10)
        let renderer = makeRenderer(song: song)
        renderer.send(.play(fromStep: 0))
        let out = render(renderer, frames: 1024)
        XCTAssertTrue(out.left.allSatisfy { $0 == 0 })
    }

    func testBuiltinSamplesAreUsable() {
        for sound in BuiltinSound.allCases {
            let sample = BuiltinSamples.make(sound, sampleRate: sampleRate)
            XCTAssertGreaterThan(sample.frameCount, 100, "\(sound)")
            XCTAssertTrue(sample.left.allSatisfy(\.isFinite), "\(sound)")
            XCTAssertGreaterThan(sample.left.map(abs).max() ?? 0, 0.05, "\(sound)")
        }
    }
}
