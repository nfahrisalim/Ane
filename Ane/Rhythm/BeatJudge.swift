import Foundation

public enum Judgment: Equatable, Hashable, Sendable {
    case perfect
    case good
    case miss

    public var points: Int {
        switch self {
        case .perfect: return 300
        case .good: return 100
        case .miss: return 0
        }
    }

    public var breaksCombo: Bool { self == .miss }
}

/// Timing windows, in seconds either side of the beat.
public struct JudgeWindows: Sendable {
    public let perfect: Double
    public let good: Double

    public init(perfect: Double, good: Double) {
        precondition(perfect <= good, "the perfect window must sit inside the good window")
        self.perfect = perfect
        self.good = good
    }

    public static let standard = JudgeWindows(perfect: 0.080, good: 0.150)

    /// Slack for float dust at the window edges.
    ///
    /// Song time arrives as an accumulated `Double`, so a delta the spec calls exactly
    /// 0.150 can surface as 0.15000000000000036. Without this the documented inclusive
    /// bound would silently reject its own boundary. A nanosecond is far below anything
    /// a player or the audio hardware can express.
    public static let edgeEpsilon = 1e-9
}

/// Judges one note by being fed `(time, aligned)` once per frame.
///
/// Resolution is deliberately split: a Perfect fires the instant it is earned so the
/// player feels the hit on the beat, while Good and Miss can only be known once the
/// window has closed. That means a frame sequence, not a single sample, decides the
/// outcome -- which is exactly what the tests feed it.
public struct NoteJudge {

    public let beatTime: Double
    public let windows: JudgeWindows

    /// True once the player has been aligned on any frame inside the window.
    public private(set) var wasEverAligned = false
    public private(set) var resolution: Judgment?

    public init(beatTime: Double, windows: JudgeWindows = .standard) {
        self.beatTime = beatTime
        self.windows = windows
    }

    public var isResolved: Bool { resolution != nil }

    public func hasOpened(at time: Double) -> Bool {
        time >= beatTime - windows.good - JudgeWindows.edgeEpsilon
    }

    public func hasClosed(at time: Double) -> Bool {
        time > beatTime + windows.good + JudgeWindows.edgeEpsilon
    }

    /// Feeds one frame. Returns a judgment only on the frame the note resolves.
    @discardableResult
    public mutating func update(time: Double, aligned: Bool) -> Judgment? {
        guard resolution == nil else { return nil }

        let delta = time - beatTime

        // Before the window opens nothing counts -- holding alignment early must not
        // bank a Good the player never actually timed.
        if delta < -(windows.good + JudgeWindows.edgeEpsilon) { return nil }

        if delta <= windows.good + JudgeWindows.edgeEpsilon {
            if aligned {
                if abs(delta) <= windows.perfect + JudgeWindows.edgeEpsilon {
                    resolution = .perfect
                    return .perfect
                }
                wasEverAligned = true
            }
            return nil
        }

        let outcome: Judgment = wasEverAligned ? .good : .miss
        resolution = outcome
        return outcome
    }
}
