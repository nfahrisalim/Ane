import AVFoundation

/// The four parts the song is built from.
enum StemKind: String, CaseIterable {
    case drums, bass, synth, lead

    /// Bundled file name, without extension.
    var fileName: String { rawValue }

    /// The beam colour that keeps this stem audible. Drums never drop out, so the
    /// player always has a beat to hold on to even during a total collapse.
    var color: BeamColor? {
        switch self {
        case .drums: return nil
        case .bass: return .magenta
        case .synth: return .cyan
        case .lead: return .amber
        }
    }

    static func stem(for color: BeamColor) -> StemKind {
        switch color {
        case .magenta: return .bass
        case .cyan: return .synth
        case .amber: return .lead
        }
    }
}

/// How performance is turned into sound.
///
/// Two implementations exist because the two depend on different assets: real separated
/// stems give the intended "hear your own score" payoff, while a single mixed track can
/// only be filtered. The game talks to this protocol so swapping one for the other is a
/// single line in `AudioEngine`.
protocol MusicLayering: AnyObject {
    /// A correct hit on `color` brings that colour's layer back.
    func registerHit(_ color: BeamColor)
    /// A miss on `color` pulls that colour's layer down.
    func registerMiss(_ color: BeamColor)
    /// Current combo, for implementations that respond to it rather than to colours.
    func updateCombo(_ combo: Int)
    /// Advances any in-flight fades. Driven from the render loop, so no extra timer
    /// exists to drift or to keep running while the game is paused.
    func tick(deltaTime: Double)
    /// Returns every layer to full for a new run.
    func reset()
}

/// Smoothly chases a target value at a frame-rate independent rate.
struct SmoothedValue {
    private(set) var current: Double
    var target: Double
    /// Seconds to cover roughly 95% of the remaining distance.
    var duration: Double

    init(_ value: Double, duration: Double = 0.15) {
        self.current = value
        self.target = value
        self.duration = duration
    }

    var isSettled: Bool { abs(target - current) < 0.0005 }

    mutating func tick(deltaTime: Double) {
        guard !isSettled else {
            current = target
            return
        }
        // 3 time constants reach ~95% in `duration`, matching the spec's 0.15 s fade.
        let rate = 3.0 / max(duration, 0.0001)
        current += (target - current) * (1 - exp(-rate * deltaTime))
    }

    mutating func snap(to value: Double) {
        current = value
        target = value
    }
}

/// Mutes and restores one stem per colour. This is the intended experience: play well
/// and the whole arrangement plays, play badly and you are left with drums.
final class StemLayering: MusicLayering {

    /// Volume a missed colour drops to. Not zero, so the player can still hear what
    /// they are losing and aim to bring it back.
    static let duckedVolume = 0.15

    private let players: [StemKind: AVAudioPlayerNode]
    private var volumes: [StemKind: SmoothedValue] = [:]

    init(players: [StemKind: AVAudioPlayerNode]) {
        self.players = players
        for kind in StemKind.allCases {
            volumes[kind] = SmoothedValue(1.0)
        }
    }

    func registerHit(_ color: BeamColor) {
        volumes[StemKind.stem(for: color)]?.target = 1.0
    }

    func registerMiss(_ color: BeamColor) {
        volumes[StemKind.stem(for: color)]?.target = Self.duckedVolume
    }

    func updateCombo(_ combo: Int) {}

    func tick(deltaTime: Double) {
        for kind in StemKind.allCases {
            guard var value = volumes[kind] else { continue }
            guard !value.isSettled else { continue }
            value.tick(deltaTime: deltaTime)
            volumes[kind] = value
            players[kind]?.volume = Float(value.current)
        }
    }

    func reset() {
        for kind in StemKind.allCases {
            volumes[kind]?.snap(to: 1.0)
            players[kind]?.volume = 1.0
        }
    }
}

/// For a single mixed track: a miss muffles the song, and a streak of hits opens it back up.
///
/// Less expressive than stems -- it cannot tell the player *which* colour they are
/// losing -- but it still ties the sound to the performance, and it needs only one file.
///
/// The song starts fully open. Starting closed and opening with the combo made every
/// run begin with half a minute of muffled intro, because intros are charted sparsely
/// and the combo there climbs one note a bar. First impressions of a real track matter
/// more than that symmetry.
final class FilterLayering: MusicLayering {

    /// Where one miss drops the cutoff. Muffled, but the melody is still recognisable, so
    /// the player can hear what they are about to win back.
    static let closedCutoff = 700.0
    static let openCutoff = 20_000.0
    /// Hits in a row, after a miss, that fully reopen the filter.
    static let fullyOpenCombo = 6.0

    private let lowPass: AVAudioUnitEQ
    private var cutoff = SmoothedValue(FilterLayering.openCutoff, duration: 0.15)
    /// Until the first miss the combo has nothing to recover from.
    private var isRecovering = false

    init(lowPass: AVAudioUnitEQ) {
        self.lowPass = lowPass
        let band = lowPass.bands[0]
        band.filterType = .lowPass
        band.frequency = Float(FilterLayering.openCutoff)
        band.bypass = false
        lowPass.bypass = false
    }

    func registerHit(_ color: BeamColor) {}

    func registerMiss(_ color: BeamColor) {
        isRecovering = true
        cutoff.target = Self.closedCutoff
    }

    func updateCombo(_ combo: Int) {
        guard isRecovering else { return }
        let progress = min(Double(combo) / Self.fullyOpenCombo, 1.0)
        if progress >= 1 { isRecovering = false }
        // Geometric, because pitch and brightness are perceived logarithmically; a linear
        // sweep would spend most of its travel in a range the ear barely distinguishes.
        cutoff.target = Self.closedCutoff * pow(Self.openCutoff / Self.closedCutoff, progress)
    }

    func tick(deltaTime: Double) {
        guard !cutoff.isSettled else { return }
        cutoff.tick(deltaTime: deltaTime)
        lowPass.bands[0].frequency = Float(cutoff.current)
    }

    func reset() {
        isRecovering = false
        cutoff.snap(to: Self.openCutoff)
        lowPass.bands[0].frequency = Float(Self.openCutoff)
    }
}
