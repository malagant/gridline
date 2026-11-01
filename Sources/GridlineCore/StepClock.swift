import Foundation

/// Sample-genaue Step-Uhr. Läuft im Audio-Thread, allokiert nicht.
public struct StepClock: Sendable {
    public var sampleRate: Double
    public var bpm: Double
    public var stepsPerBeat: Int

    /// Step, der als nächstes ausgelöst wird.
    public private(set) var nextStep: Int = 0
    /// Samples ab Pufferbeginn bis zum nächsten Step.
    public private(set) var samplesUntilNextStep: Double = 0

    public init(sampleRate: Double, bpm: Double, stepsPerBeat: Int = 4) {
        self.sampleRate = sampleRate
        self.bpm = bpm
        self.stepsPerBeat = stepsPerBeat
    }

    public var samplesPerStep: Double {
        sampleRate * 60.0 / max(bpm, 1) / Double(max(stepsPerBeat, 1))
    }

    /// Setzt auf Step `step` zurück, der im nächsten Puffer bei Frame 0 ausgelöst wird.
    public mutating func reset(to step: Int = 0) {
        nextStep = max(step, 0)
        samplesUntilNextStep = 0
    }

    /// Schiebt die Uhr um `frames` vor und meldet jeden Step mit seinem Frame-Offset im Puffer.
    public mutating func advance(frames: Int, stepCount: Int, _ onStep: (_ frameOffset: Int, _ step: Int) -> Void) {
        let count = max(stepCount, 1)
        if nextStep >= count { nextStep = 0 }
        var t = samplesUntilNextStep
        let end = Double(frames)
        let stepLength = samplesPerStep
        while t < end {
            onStep(max(Int(t), 0), nextStep)
            nextStep = (nextStep + 1) % count
            t += stepLength
        }
        samplesUntilNextStep = t - end
    }
}
