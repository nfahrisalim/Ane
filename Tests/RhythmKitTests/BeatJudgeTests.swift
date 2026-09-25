import Testing
import Foundation
@testable import RhythmKit

@Suite("BeatJudge")
struct BeatJudgeTests {

    private let beat = 10.0
    private let windows = JudgeWindows.standard

    /// Feeds frames at 60 Hz across the whole window and returns what resolved.
    private func run(
        alignedWhen predicate: (Double) -> Bool,
        from: Double = -0.40,
        to: Double = 0.40
    ) -> Judgment? {
        var judge = NoteJudge(beatTime: beat, windows: windows)
        var offset = from
        var resolved: Judgment?
        while offset <= to {
            let time = beat + offset
            if let judgment = judge.update(time: time, aligned: predicate(offset)) {
                resolved = judgment
                break
            }
            offset += 1.0 / 60.0
        }
        return resolved
    }

    @Test("aligned exactly on the beat is Perfect")
    func perfectOnBeat() {
        var judge = NoteJudge(beatTime: beat, windows: windows)
        #expect(judge.update(time: beat, aligned: true) == .perfect)
        #expect(judge.isResolved)
    }

    @Test("aligned only at +0.12 s is Good")
    func goodLate() {
        let resolved = run(alignedWhen: { abs($0 - 0.12) < 0.004 })
        #expect(resolved == .good)
    }

    @Test("aligned only at -0.12 s is Good")
    func goodEarly() {
        let resolved = run(alignedWhen: { abs($0 + 0.12) < 0.004 })
        #expect(resolved == .good)
    }

    @Test("never aligned is a Miss")
    func miss() {
        #expect(run(alignedWhen: { _ in false }) == .miss)
    }

    @Test("held through the whole window is Perfect")
    func heldThrough() {
        #expect(run(alignedWhen: { _ in true }) == .perfect)
    }

    @Test("aligned only before the window opens is a Miss")
    func alignedTooEarly() {
        #expect(run(alignedWhen: { $0 < -windows.good - 0.01 }) == .miss)
    }

    @Test("aligned only after the window closes is a Miss")
    func alignedTooLate() {
        #expect(run(alignedWhen: { $0 > windows.good + 0.01 }) == .miss)
    }

    @Test("the window edge at exactly +0.150 s still earns Good")
    func edgeOfGood() {
        var judge = NoteJudge(beatTime: beat, windows: windows)
        #expect(judge.update(time: beat + windows.good, aligned: true) == nil)
        #expect(judge.wasEverAligned)
        #expect(judge.update(time: beat + windows.good + 0.001, aligned: false) == .good)
    }

    @Test("the edge at exactly +0.080 s still earns Perfect")
    func edgeOfPerfect() {
        var judge = NoteJudge(beatTime: beat, windows: windows)
        #expect(judge.update(time: beat + windows.perfect, aligned: true) == .perfect)
    }

    @Test("a resolved note ignores every later frame")
    func resolvesOnce() {
        var judge = NoteJudge(beatTime: beat, windows: windows)
        #expect(judge.update(time: beat, aligned: true) == .perfect)
        #expect(judge.update(time: beat + 0.01, aligned: true) == nil)
        #expect(judge.update(time: beat + 1.0, aligned: false) == nil)
    }

    @Test("a frame that skips the entire window still resolves to Miss")
    func skippedWindow() {
        var judge = NoteJudge(beatTime: beat, windows: windows)
        #expect(judge.update(time: beat + 5.0, aligned: true) == .miss)
    }

    @Test("Good upgrades to Perfect if alignment is regained in time")
    func lateAlignmentBecomesPerfect() {
        var judge = NoteJudge(beatTime: beat, windows: windows)
        #expect(judge.update(time: beat - 0.14, aligned: true) == nil)
        #expect(judge.wasEverAligned)
        #expect(judge.update(time: beat - 0.02, aligned: true) == .perfect)
    }

    @Test("window bookkeeping reports open and closed correctly")
    func windowBounds() {
        let judge = NoteJudge(beatTime: beat, windows: windows)
        #expect(!judge.hasOpened(at: beat - 0.2))
        #expect(judge.hasOpened(at: beat - windows.good))
        #expect(!judge.hasClosed(at: beat + windows.good))
        #expect(judge.hasClosed(at: beat + windows.good + 0.001))
    }
}
