import SwiftUI

extension UserDefaults {
    /// Isolated defaults so previews never read or clobber a real best score.
    static let previewDefaults: UserDefaults = {
        let defaults = UserDefaults(suiteName: "PrismGroove.previews") ?? .standard
        defaults.set(48_600, forKey: "bestScore")
        defaults.set(true, forKey: "hasSeenHint")
        return defaults
    }()
}

extension RunResult {
    static let preview = RunResult(
        score: 52_400,
        perfectCount: 186,
        goodCount: 24,
        missCount: 10,
        maxCombo: 97,
        accuracy: 0.912
    )

    static let previewRough = RunResult(
        score: 9_800,
        perfectCount: 42,
        goodCount: 58,
        missCount: 120,
        maxCombo: 11,
        accuracy: 0.312
    )
}
