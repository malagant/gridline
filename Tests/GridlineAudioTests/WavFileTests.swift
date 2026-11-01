import XCTest
@testable import GridlineAudio

final class WavFileTests: XCTestCase {
    private let left: [Float] = [0, 0.5, -0.5, 1, -1, 0.25]
    private let right: [Float] = [0.1, -0.1, 0.2, -0.2, 0.3, -0.3]

    func testRoundTripPCM16() throws {
        let data = WavFile.encode(left: left, right: right, sampleRate: 44_100, encoding: .pcm16)
        XCTAssertEqual(data.count, 44 + left.count * 4)
        let sample = try WavFile.decode(data)
        XCTAssertEqual(sample.sampleRate, 44_100)
        XCTAssertEqual(sample.frameCount, left.count)
        for i in left.indices {
            XCTAssertEqual(sample.left[i], left[i], accuracy: 1.0 / 16_000)
            XCTAssertEqual(sample.right[i], right[i], accuracy: 1.0 / 16_000)
        }
    }

    func testRoundTripFloat32IsExact() throws {
        let data = WavFile.encode(left: left, right: right, sampleRate: 48_000, encoding: .float32)
        let sample = try WavFile.decode(data)
        XCTAssertEqual(sample.left, left)
        XCTAssertEqual(sample.right, right)
    }

    func testMono8BitAndUnknownChunk() throws {
        // Handgebautes Mono-8-Bit-WAV mit einem zusätzlichen LIST-Chunk ungerader Länge.
        var bytes: [UInt8] = Array("RIFF".utf8) + [0, 0, 0, 0] + Array("WAVE".utf8)
        bytes += Array("LIST".utf8) + [3, 0, 0, 0] + [1, 2, 3, 0]          // gepolstert
        bytes += Array("fmt ".utf8) + [16, 0, 0, 0, 1, 0, 1, 0]
        bytes += [0x40, 0x1F, 0, 0, 0x40, 0x1F, 0, 0, 1, 0, 8, 0]          // 8000 Hz, 8 Bit
        bytes += Array("data".utf8) + [3, 0, 0, 0] + [128, 255, 0]
        let sample = try WavFile.decode(Data(bytes))
        XCTAssertEqual(sample.sampleRate, 8000)
        XCTAssertEqual(sample.frameCount, 3)
        XCTAssertEqual(sample.left[0], 0)
        XCTAssertEqual(sample.left[1], 127.0 / 128, accuracy: 1e-6)
        XCTAssertEqual(sample.left[2], -1)
        XCTAssertEqual(sample.right, sample.left)
    }

    func testRejectsNonWave() {
        XCTAssertThrowsError(try WavFile.decode(Data("hello world, no wave".utf8))) { error in
            XCTAssertEqual(error as? WavFile.Error, .notWave)
        }
    }
}
