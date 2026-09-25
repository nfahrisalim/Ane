import Foundation

/// Running score, combo and tallies for one run.
public struct ScoreKeeper: Sendable {

    public private(set) var score = 0
    public private(set) var combo = 0
    public private(set) var maxCombo = 0
    public private(set) var perfectCount = 0
    public private(set) var goodCount = 0
    public private(set) var missCount = 0

    public init() {}

    /// 1, 2, 3 or 4. Every 8 consecutive hits buys one more step.
    public var multiplier: Int { 1 + min(combo / 8, 3) }

    public var judgedCount: Int { perfectCount + goodCount + missCount }

    /// Share of the maximum attainable base points, ignoring the multiplier so that
    /// accuracy reads as "how well did I play" rather than "how long was my combo".
    public var accuracy: Double {
        guard judgedCount > 0 else { return 0 }
        let earned = Double(perfectCount * Judgment.perfect.points + goodCount * Judgment.good.points)
        let attainable = Double(judgedCount * Judgment.perfect.points)
        return earned / attainable
    }

    public mutating func register(_ judgment: Judgment) {
        switch judgment {
        case .perfect: perfectCount += 1
        case .good: goodCount += 1
        case .miss: missCount += 1
        }

        if judgment.breaksCombo {
            combo = 0
            return
        }

        // Combo advances first, so the hit that reaches 8 is already worth the higher step.
        combo += 1
        maxCombo = max(maxCombo, combo)
        score += judgment.points * multiplier
    }
}

/// Everything the results screen needs, snapshotted at the end of a run.
public struct RunResult: Equatable, Sendable {
    public let score: Int
    public let perfectCount: Int
    public let goodCount: Int
    public let missCount: Int
    public let maxCombo: Int
    public let accuracy: Double

    public init(score: Int, perfectCount: Int, goodCount: Int, missCount: Int, maxCombo: Int, accuracy: Double) {
        self.score = score
        self.perfectCount = perfectCount
        self.goodCount = goodCount
        self.missCount = missCount
        self.maxCombo = maxCombo
        self.accuracy = accuracy
    }

    public init(_ keeper: ScoreKeeper) {
        self.init(
            score: keeper.score,
            perfectCount: keeper.perfectCount,
            goodCount: keeper.goodCount,
            missCount: keeper.missCount,
            maxCombo: keeper.maxCombo,
            accuracy: keeper.accuracy
        )
    }

    public var noteCount: Int { perfectCount + goodCount + missCount }
}
