import Foundation

/// Plattformneutraler WAV-Leser und -Schreiber (RIFF/WAVE).
/// Lesen: PCM 8/16/24/32 Bit, Float 32/64 Bit, auch WAVE_FORMAT_EXTENSIBLE.
/// Schreiben: 16-Bit-PCM oder 32-Bit-Float, Stereo.
public enum WavFile {
    public enum Error: Swift.Error, Equatable {
        case notWave
        case missingChunk(String)
        case unsupportedFormat(tag: UInt16, bits: UInt16)
    }

    public enum Encoding: Sendable {
        case pcm16
        case float32
    }

    private static let formatPCM: UInt16 = 1
    private static let formatFloat: UInt16 = 3
    private static let formatExtensible: UInt16 = 0xFFFE

    // MARK: Lesen

    public static func decode(_ data: Data) throws -> SampleData {
        let bytes = [UInt8](data)
        guard bytes.count >= 12, ascii(bytes, 0, 4) == "RIFF", ascii(bytes, 8, 4) == "WAVE" else {
            throw Error.notWave
        }

        var format: (tag: UInt16, channels: Int, rate: Double, bits: UInt16)?
        var payload: Range<Int>?
        var offset = 12
        while offset + 8 <= bytes.count {
            let id = ascii(bytes, offset, 4)
            let size = Int(readUInt32(bytes, offset + 4))
            let body = offset + 8
            let end = min(body + size, bytes.count)
            switch id {
            case "fmt ":
                guard end - body >= 16 else { throw Error.missingChunk("fmt ") }
                var tag = readUInt16(bytes, body)
                let channels = Int(readUInt16(bytes, body + 2))
                let rate = Double(readUInt32(bytes, body + 4))
                let bits = readUInt16(bytes, body + 14)
                if tag == formatExtensible, end - body >= 26 {
                    tag = readUInt16(bytes, body + 24)   // erstes Feld der SubFormat-GUID
                }
                format = (tag, max(channels, 1), rate, bits)
            case "data":
                payload = body..<end
            default:
                break
            }
            offset = body + size + (size & 1)   // Chunks sind auf gerade Längen gepolstert
        }

        guard let format else { throw Error.missingChunk("fmt ") }
        guard let payload else { throw Error.missingChunk("data") }

        let bytesPerSample = Int(format.bits) / 8
        guard bytesPerSample > 0 else { throw Error.unsupportedFormat(tag: format.tag, bits: format.bits) }
        let reader: (Int) -> Float
        switch (format.tag, format.bits) {
        case (formatPCM, 8):  reader = { (Float(bytes[$0]) - 128) / 128 }
        case (formatPCM, 16): reader = { Float(Int16(bitPattern: readUInt16(bytes, $0))) / 32_768 }
        case (formatPCM, 24): reader = { i in
            let raw = Int32(bytes[i]) | Int32(bytes[i + 1]) << 8 | Int32(Int8(bitPattern: bytes[i + 2])) << 16
            return Float(raw) / 8_388_608
        }
        case (formatPCM, 32): reader = { Float(Int32(bitPattern: readUInt32(bytes, $0))) / 2_147_483_648 }
        case (formatFloat, 32): reader = { Float(bitPattern: readUInt32(bytes, $0)) }
        case (formatFloat, 64): reader = { i in
            let lo = UInt64(readUInt32(bytes, i)), hi = UInt64(readUInt32(bytes, i + 4))
            return Float(Double(bitPattern: lo | hi << 32))
        }
        default:
            throw Error.unsupportedFormat(tag: format.tag, bits: format.bits)
        }

        let frameSize = bytesPerSample * format.channels
        let frames = payload.count / frameSize
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        for f in 0..<frames {
            let base = payload.lowerBound + f * frameSize
            left[f] = reader(base)
            right[f] = format.channels > 1 ? reader(base + bytesPerSample) : left[f]
        }
        return SampleData(left: left, right: right, sampleRate: format.rate)
    }

    // MARK: Schreiben

    public static func encode(left: [Float], right: [Float], sampleRate: Double, encoding: Encoding = .pcm16) -> Data {
        precondition(left.count == right.count, "Kanäle müssen gleich lang sein")
        let channels: UInt16 = 2
        let bits: UInt16 = encoding == .pcm16 ? 16 : 32
        let blockAlign = channels * bits / 8
        let dataSize = UInt32(left.count) * UInt32(blockAlign)

        var out = [UInt8]()
        out.reserveCapacity(44 + Int(dataSize))
        out += Array("RIFF".utf8); append32(&out, 36 + dataSize); out += Array("WAVE".utf8)
        out += Array("fmt ".utf8); append32(&out, 16)
        append16(&out, encoding == .pcm16 ? formatPCM : formatFloat)
        append16(&out, channels)
        append32(&out, UInt32(sampleRate))
        append32(&out, UInt32(sampleRate) * UInt32(blockAlign))
        append16(&out, blockAlign)
        append16(&out, bits)
        out += Array("data".utf8); append32(&out, dataSize)

        for i in left.indices {
            for value in [left[i], right[i]] {
                switch encoding {
                case .pcm16:
                    let clamped = max(-1, min(1, value))
                    append16(&out, UInt16(bitPattern: Int16((clamped * 32_767).rounded())))
                case .float32:
                    append32(&out, value.bitPattern)
                }
            }
        }
        return Data(out)
    }

    // MARK: Helfer

    private static func ascii(_ b: [UInt8], _ at: Int, _ count: Int) -> String {
        guard at + count <= b.count else { return "" }
        return String(decoding: b[at..<at + count], as: UTF8.self)
    }

    private static func readUInt16(_ b: [UInt8], _ at: Int) -> UInt16 {
        UInt16(b[at]) | UInt16(b[at + 1]) << 8
    }

    private static func readUInt32(_ b: [UInt8], _ at: Int) -> UInt32 {
        UInt32(b[at]) | UInt32(b[at + 1]) << 8 | UInt32(b[at + 2]) << 16 | UInt32(b[at + 3]) << 24
    }

    private static func append16(_ out: inout [UInt8], _ v: UInt16) {
        out.append(UInt8(v & 0xFF)); out.append(UInt8(v >> 8))
    }

    private static func append32(_ out: inout [UInt8], _ v: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) { out.append(UInt8((v >> UInt32(shift)) & 0xFF)) }
    }
}
