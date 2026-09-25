import Foundation

/// The single source of song time.
///
/// Implementations must derive time from the audio hardware's own render position.
/// `Timer`, `DispatchQueue.asyncAfter` and accumulated frame deltas all drift, and over
/// a two-minute song that drift is audible long before the outro.
public protocol BeatClock: AnyObject {
    /// Seconds since beat 0, already latency-compensated, or nil before playback begins.
    var songTime: Double? { get }
}

/// Hand-driven clock for tests and previews.
public final class MockBeatClock: BeatClock {
    public var songTime: Double?

    public init(songTime: Double? = nil) {
        self.songTime = songTime
    }

    /// Advances the clock, starting it at 0 if it had not begun.
    public func advance(by delta: Double) {
        songTime = (songTime ?? 0) + delta
    }
}
