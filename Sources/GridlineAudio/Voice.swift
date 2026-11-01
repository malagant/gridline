import Foundation

/// Eine Sample-Stimme. Jede Spur ist monophon und besitzt genau eine Stimme.
struct Voice {
    enum Stage { case idle, attack, sustain, release }

    private(set) var stage: Stage = .idle
    private var sample: SampleData?
    private var position: Double = 0
    private var increment: Double = 1
    private var gain: Float = 0
    private var envelope: Float = 0
    private var attackStep: Float = 1
    private var releaseStep: Float = 1
    private var loop = false

    var isActive: Bool { stage != .idle }

    mutating func trigger(sample: SampleData, ratio: Double, outputRate: Double, gain: Float,
                          attack: Double, release: Double, loop: Bool) {
        self.sample = sample
        self.position = 0
        self.increment = ratio * sample.sampleRate / outputRate
        self.gain = gain
        self.envelope = 0
        self.attackStep = Float(1.0 / max(attack * outputRate, 1))
        self.releaseStep = Float(1.0 / max(release * outputRate, 1))
        self.loop = loop
        self.stage = .attack
    }

    mutating func noteOff() {
        if stage != .idle { stage = .release }
    }

    mutating func kill() {
        stage = .idle
        sample = nil
    }

    /// Mischt `frames` Frames additiv in die Ausgabepuffer.
    mutating func render(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        guard stage != .idle, let sample else { return }
        let count = sample.frameCount
        guard count > 1 else { kill(); return }

        sample.left.withUnsafeBufferPointer { l in
            sample.right.withUnsafeBufferPointer { r in
                for i in 0..<frames {
                    switch stage {
                    case .attack:
                        envelope += attackStep
                        if envelope >= 1 { envelope = 1; stage = .sustain }
                    case .release:
                        envelope -= releaseStep
                        if envelope <= 0 { envelope = 0; stage = .idle; return }
                    case .sustain, .idle:
                        break
                    }

                    var index = Int(position)
                    if index >= count - 1 {
                        if loop {
                            position -= Double(count - 1)
                            index = Int(position)
                        } else {
                            stage = .idle
                            return
                        }
                    }
                    let frac = Float(position - Double(index))
                    let a = gain * envelope
                    left[i] += (l[index] + (l[index + 1] - l[index]) * frac) * a
                    right[i] += (r[index] + (r[index + 1] - r[index]) * frac) * a
                    position += increment
                }
            }
        }
        if stage == .idle { self.sample = nil }
    }
}
