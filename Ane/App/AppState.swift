import SwiftUI

/// Top-level navigation and the only thing that outlives a run.
@Observable
@MainActor
final class AppState {

    enum Screen: Equatable {
        case title
        case playing
        case results(RunResult)
    }

    private enum Keys {
        static let bestScore = "bestScore"
        static let hasSeenHint = "hasSeenHint"
    }

    var screen: Screen = .title
    private(set) var bestScore: Int
    private(set) var hasSeenHint: Bool
    /// Whether the most recent run beat the stored best. Recorded at the moment it is
    /// known; re-deriving it later would call an exact tie a new best.
    private(set) var lastRunWasBest = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.bestScore = defaults.integer(forKey: Keys.bestScore)
        self.hasSeenHint = defaults.bool(forKey: Keys.hasSeenHint)
    }

    /// Records a finished run. Returns true when it beat the stored best.
    @discardableResult
    func finish(_ result: RunResult) -> Bool {
        let isNewBest = result.score > bestScore
        lastRunWasBest = isNewBest
        if isNewBest {
            bestScore = result.score
            defaults.set(result.score, forKey: Keys.bestScore)
        }
        screen = .results(result)
        return isNewBest
    }

    func markHintSeen() {
        guard !hasSeenHint else { return }
        hasSeenHint = true
        defaults.set(true, forKey: Keys.hasSeenHint)
    }

    func play() { screen = .playing }
    func returnToTitle() { screen = .title }
}
