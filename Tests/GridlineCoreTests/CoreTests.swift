import XCTest
@testable import GridlineCore

final class NoteTests: XCTestCase {
    func testTrackerNoteNames() {
        XCTAssertEqual(NoteName.string(for: 60), "C-4")
        XCTAssertEqual(NoteName.string(for: 61), "C#4")
        XCTAssertEqual(NoteName.string(for: 69), "A-4")
        XCTAssertEqual(NoteName.string(for: 12), "C-0")
        XCTAssertEqual(NoteName.string(for: 119), "B-8")
    }

    func testPitchRatio() {
        XCTAssertEqual(Pitch.ratio(note: 60), 1, accuracy: 1e-12)
        XCTAssertEqual(Pitch.ratio(note: 72), 2, accuracy: 1e-12)
        XCTAssertEqual(Pitch.ratio(note: 48), 0.5, accuracy: 1e-12)
        XCTAssertEqual(Pitch.ratio(note: 60, tune: 12), 2, accuracy: 1e-12)
        XCTAssertEqual(Pitch.ratio(note: 57, root: 57), 1, accuracy: 1e-12)
    }
}

final class StepTests: XCTestCase {
    func testFormatting() {
        let empty = Step.empty
        XCTAssertEqual(StepFormatter.note(empty), "---")
        XCTAssertEqual(StepFormatter.instrument(empty), "--")
        XCTAssertEqual(StepFormatter.volume(empty), "--")
        XCTAssertEqual(StepFormatter.effect(nil), "---")

        let step = Step(note: .note(62), instrument: 0, volume: 100, fx1: StepEffect(kind: .retrigger, value: 3))
        XCTAssertEqual(StepFormatter.note(step), "D-4")
        XCTAssertEqual(StepFormatter.instrument(step), "01")
        XCTAssertEqual(StepFormatter.volume(step), "FF")
        XCTAssertEqual(StepFormatter.effect(step.fx1), "R03")
        XCTAssertEqual(StepFormatter.note(Step(note: .off)), "OFF")
    }

    func testValueClamping() {
        XCTAssertEqual(Step(volume: 250).volume, 100)
        XCTAssertEqual(StepEffect(kind: .chance, value: -4).value, 0)
    }
}

final class PatternTests: XCTestCase {
    func testLengthIsClampedAndDataSurvives() {
        var p = GridPattern(length: 16)
        p[0, 20] = Step(note: .note(60))
        p.setLength(500)
        XCTAssertEqual(p.length, GridPattern.maxLength)
        p.setLength(0)
        XCTAssertEqual(p.length, 1)
        p.setLength(32)
        XCTAssertEqual(p[0, 20].note, .note(60))
    }

    func testOutOfRangeAccessIsSafe() {
        var p = GridPattern()
        p[99, 0] = Step(note: .note(60))
        XCTAssertEqual(p[99, 0], .empty)
        XCTAssertEqual(p[0, 999], .empty)
    }
}

final class StepClockTests: XCTestCase {
    /// 120 BPM, 16tel, 48 kHz → 6000 Samples pro Step.
    func testStepSpacing() {
        var clock = StepClock(sampleRate: 48_000, bpm: 120)
        XCTAssertEqual(clock.samplesPerStep, 6000, accuracy: 1e-9)

        var hits: [(Int, Int)] = []
        clock.advance(frames: 13_000, stepCount: 16) { hits.append(($0, $1)) }
        XCTAssertEqual(hits.map(\.0), [0, 6000, 12_000])
        XCTAssertEqual(hits.map(\.1), [0, 1, 2])
    }

    func testAcrossBufferBoundaries() {
        var clock = StepClock(sampleRate: 48_000, bpm: 120)
        var absolute: [Int] = []
        var bufferStart = 0
        for _ in 0..<50 {
            clock.advance(frames: 512, stepCount: 16) { offset, _ in absolute.append(bufferStart + offset) }
            bufferStart += 512
        }
        XCTAssertEqual(absolute, stride(from: 0, to: 50 * 512, by: 6000).map { $0 })
    }

    func testWrapsAtPatternLength() {
        var clock = StepClock(sampleRate: 1000, bpm: 60, stepsPerBeat: 1) // 1000 Samples/Step
        var steps: [Int] = []
        clock.advance(frames: 5000, stepCount: 3) { steps.append($1) }
        XCTAssertEqual(steps, [0, 1, 2, 0, 1])
    }

    func testResetStartsAtGivenStep() {
        var clock = StepClock(sampleRate: 1000, bpm: 60, stepsPerBeat: 1)
        clock.advance(frames: 2500, stepCount: 8) { _, _ in }
        clock.reset(to: 5)
        var first: (Int, Int)?
        clock.advance(frames: 10, stepCount: 8) { if first == nil { first = ($0, $1) } }
        XCTAssertEqual(first?.0, 0)
        XCTAssertEqual(first?.1, 5)
    }
}

final class ProjectFileTests: XCTestCase {
    func testRoundTrip() throws {
        var song = Song.demo()
        song.patterns[0][7, 9] = Step(note: .off, fx2: StepEffect(kind: .microtime, value: 12))
        song.instruments[6].source = .file(path: "/tmp/test.wav")
        let data = try ProjectFile.encode(song)
        XCTAssertEqual(try ProjectFile.decode(data), song)
    }

    func testRejectsNewerVersion() throws {
        let current = String(decoding: try ProjectFile.encode(.demo()), as: UTF8.self)
        let future = current.replacingOccurrences(of: "\"formatVersion\" : 1", with: "\"formatVersion\" : 99")
        XCTAssertNotEqual(current, future)
        XCTAssertThrowsError(try ProjectFile.decode(Data(future.utf8))) { error in
            XCTAssertEqual(error as? ProjectFile.Error, .unsupportedVersion(99))
        }
    }

    func testBpmIsClamped() {
        var song = Song()
        song.bpm = 1000
        XCTAssertEqual(song.bpm, Song.bpmRange.upperBound)
    }
}
