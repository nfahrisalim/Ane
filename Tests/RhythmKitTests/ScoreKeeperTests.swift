import Testing
import Foundation
@testable import RhythmKit

@Suite("ScoreKeeper")
struct ScoreKeeperTests {

    @Test("a fresh keeper is empty")
    func empty() {
        let keeper = ScoreKeeper()
        #expect(keeper.score == 0)
        #expect(keeper.combo == 0)
        #expect(keeper.multiplier == 1)
        #expect(keeper.accuracy == 0)
    }

    @Test("the first Perfect is worth 300 at x2")
    func firstHit() {
        var keeper = ScoreKeeper()
        keeper.register(.perfect)
        // Combo advances to 1 before scoring, which is still inside the x1 step.
        #expect(keeper.combo == 1)
        #expect(keeper.multiplier == 1)
        #expect(keeper.score == 300)
    }

    @Test("the multiplier steps up every 8 hits and caps at x4")
    func multiplierLadder() {
        var keeper = ScoreKeeper()
        for _ in 0..<7 { keeper.register(.perfect) }
        #expect(keeper.multiplier == 1)
        keeper.register(.perfect)
        #expect(keeper.combo == 8)
        #expect(keeper.multiplier == 2)
        for _ in 0..<8 { keeper.register(.perfect) }
        #expect(keeper.multiplier == 3)
        for _ in 0..<8 { keeper.register(.perfect) }
        #expect(keeper.multiplier == 4)
        for _ in 0..<40 { keeper.register(.perfect) }
        #expect(keeper.multiplier == 4)
    }

    @Test("a Miss resets the combo but keeps max combo")
    func missResetsCombo() {
        var keeper = ScoreKeeper()
        for _ in 0..<10 { keeper.register(.perfect) }
        #expect(keeper.maxCombo == 10)
        keeper.register(.miss)
        #expect(keeper.combo == 0)
        #expect(keeper.multiplier == 1)
        #expect(keeper.maxCombo == 10)
        #expect(keeper.missCount == 1)
    }

    @Test("a Miss adds no score")
    func missScoresNothing() {
        var keeper = ScoreKeeper()
        keeper.register(.miss)
        #expect(keeper.score == 0)
        #expect(keeper.judgedCount == 1)
    }

    @Test("counts are tallied per judgment")
    func tallies() {
        var keeper = ScoreKeeper()
        keeper.register(.perfect)
        keeper.register(.good)
        keeper.register(.good)
        keeper.register(.miss)
        #expect(keeper.perfectCount == 1)
        #expect(keeper.goodCount == 2)
        #expect(keeper.missCount == 1)
        #expect(keeper.judgedCount == 4)
    }

    @Test("all Perfects is 100% accuracy, all Misses is 0%")
    func accuracyBounds() {
        var perfect = ScoreKeeper()
        for _ in 0..<20 { perfect.register(.perfect) }
        #expect(abs(perfect.accuracy - 1.0) < 1e-12)

        var missed = ScoreKeeper()
        for _ in 0..<20 { missed.register(.miss) }
        #expect(missed.accuracy == 0)
    }

    @Test("a Good is worth a third of a Perfect in accuracy")
    func accuracyWeighting() {
        var keeper = ScoreKeeper()
        keeper.register(.good)
        #expect(abs(keeper.accuracy - (100.0 / 300.0)) < 1e-12)
    }

    @Test("RunResult snapshots the keeper")
    func snapshot() {
        var keeper = ScoreKeeper()
        keeper.register(.perfect)
        keeper.register(.good)
        keeper.register(.miss)
        let result = RunResult(keeper)
        #expect(result.score == keeper.score)
        #expect(result.maxCombo == keeper.maxCombo)
        #expect(result.noteCount == 3)
        #expect(abs(result.accuracy - keeper.accuracy) < 1e-12)
    }
}
