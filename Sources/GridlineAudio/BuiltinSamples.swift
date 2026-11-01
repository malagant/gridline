import Foundation
import GridlineCore

/// Erzeugt die eingebauten Klänge synthetisch. Alle tonalen Klänge sind auf C-4 (261,63 Hz) gestimmt.
public enum BuiltinSamples {
    public static func make(_ sound: BuiltinSound, sampleRate: Double = 48_000) -> SampleData {
        switch sound {
        case .kick: return kick(sampleRate)
        case .snare: return snare(sampleRate)
        case .hat: return hat(sampleRate)
        case .pluck: return pluck(sampleRate)
        case .bass: return bass(sampleRate)
        }
    }

    private static let c4 = 261.625565

    /// Deterministisches Rauschen, damit Klänge reproduzierbar sind.
    private struct Noise {
        var state: UInt32 = 0x1234_5678
        mutating func next() -> Float {
            state = state &* 1_664_525 &+ 1_013_904_223
            return Float(Int32(bitPattern: state)) / Float(Int32.max)
        }
    }

    private static func kick(_ sr: Double) -> SampleData {
        let n = Int(sr * 0.45)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sr
            let freq = 45 + 110 * exp(-t * 30)
            phase += 2 * .pi * freq / sr
            let amp = exp(-t * 7)
            let click = i < Int(sr * 0.003) ? 0.3 * (1 - Double(i) / (sr * 0.003)) : 0
            out[i] = Float(sin(phase) * amp + click)
        }
        return SampleData(mono: out, sampleRate: sr)
    }

    private static func snare(_ sr: Double) -> SampleData {
        let n = Int(sr * 0.25)
        var out = [Float](repeating: 0, count: n)
        var noise = Noise()
        for i in 0..<n {
            let t = Double(i) / sr
            let tone = sin(2 * .pi * 185 * t) * exp(-t * 25) * 0.5
            let hiss = Double(noise.next()) * exp(-t * 14) * 0.6
            out[i] = Float(tone + hiss)
        }
        return SampleData(mono: out, sampleRate: sr)
    }

    private static func hat(_ sr: Double) -> SampleData {
        let n = Int(sr * 0.08)
        var out = [Float](repeating: 0, count: n)
        var noise = Noise(state: 0xCAFE_F00D)
        var previous: Float = 0
        for i in 0..<n {
            let t = Double(i) / sr
            let x = noise.next()
            let highpassed = x - previous   // einfacher Differenzierer
            previous = x
            out[i] = highpassed * Float(exp(-t * 60)) * 0.5
        }
        return SampleData(mono: out, sampleRate: sr)
    }

    /// Karplus-Strong-Saite.
    private static func pluck(_ sr: Double) -> SampleData {
        let n = Int(sr * 1.2)
        let period = max(Int((sr / c4).rounded()), 2)
        var noise = Noise(state: 0xBEEF)
        var ring = (0..<period).map { _ in noise.next() * 0.5 }
        var out = [Float](repeating: 0, count: n)
        var index = 0
        for i in 0..<n {
            let next = (index + 1) % period
            let value = ring[index]
            ring[index] = 0.996 * 0.5 * (value + ring[next])
            out[i] = value
            index = next
        }
        return SampleData(mono: out, sampleRate: sr)
    }

    /// Gefilterte Sägezahnwelle.
    private static func bass(_ sr: Double) -> SampleData {
        let n = Int(sr * 0.8)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        var lowpass = 0.0
        for i in 0..<n {
            let t = Double(i) / sr
            phase += c4 / sr
            if phase >= 1 { phase -= 1 }
            let saw = 2 * phase - 1
            let cutoff = 0.02 + 0.25 * exp(-t * 9)
            lowpass += cutoff * (saw - lowpass)
            out[i] = Float(lowpass * exp(-t * 2.5) * 0.9)
        }
        return SampleData(mono: out, sampleRate: sr)
    }
}
