import AVFoundation
import os

/// Owns playback and, more importantly, owns time.
///
/// Song time is read from the drum player's own render position, so it is the same clock
/// the speaker is working from. `Timer`, `DispatchQueue.asyncAfter` and accumulated frame
/// deltas were all rejected: each drifts, and across a two-minute song the drift is
/// audible well before the outro.
final class AudioEngine: BeatClock {

    enum Source {
        /// Four separated files in the bundle. The intended experience.
        case stems
        /// One mixed file in the bundle. Layering degrades to a filter.
        case mixed
        /// Nothing in the bundle: synthesised on the fly.
        case procedural
    }

    private let engine = AVAudioEngine()
    private let lowPass = AVAudioUnitEQ(numberOfBands: 1)
    /// Every stem lands here first.
    ///
    /// A mixer converts whatever format each stem happens to have, which matters because
    /// an AU effect like the EQ refuses to start unless its input and output agree on
    /// channel count -- wiring mono players straight into it fails with -10868.
    private let stemMixer = AVAudioMixerNode()

    /// One format for the whole processing chain, so nothing has to be renegotiated.
    private static let processingFormat = AVAudioFormat(
        standardFormatWithSampleRate: 44_100,
        channels: 2
    )
    private var players: [StemKind: AVAudioPlayerNode] = [:]
    private var buffers: [StemKind: AVAudioPCMBuffer] = [:]
    private var files: [StemKind: AVAudioFile] = [:]

    private let logger = Logger(subsystem: "com.dissent.academy.Ane", category: "audio")

    private(set) var source: Source = .procedural
    private(set) var layering: MusicLayering?
    private(set) var isRunning = false

    /// Compensation for the delay between a rendered sample and the speaker.
    private var outputLatency: Double = 0

    /// The node whose render position defines song time. Drums, because they are the one
    /// stem that is never ducked and never stops.
    private var clockNode: AVAudioPlayerNode? { players[.drums] }

    /// Set while paused so the HUD and session see a frozen, not a jumping, clock.
    private var pausedSongTime: Double?

    // MARK: - BeatClock

    var songTime: Double? {
        if let pausedSongTime { return pausedSongTime }
        guard isRunning,
              let node = clockNode,
              let nodeTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: nodeTime),
              playerTime.sampleRate > 0 else { return nil }

        let rendered = Double(playerTime.sampleTime) / playerTime.sampleRate
        // What the player has *heard* lags what the engine has rendered.
        return rendered - outputLatency
    }

    // MARK: - Setup

    /// Builds the graph and loads or synthesises `song`'s audio. Call once per engine.
    ///
    /// If a bundled file is missing or unreadable the engine falls back to the procedural
    /// track and reports it through `source`, so the caller can switch to the chart that
    /// matches what is actually playing instead of judging against the wrong beat grid.
    func prepare(song: Song) async {
        configureSession()
        await loadSources(for: song)
        buildGraph()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            logger.error("audio session setup failed: \(error.localizedDescription, privacy: .public)")
        }
        outputLatency = session.outputLatency
    }

    private func loadSources(for song: Song) async {
        switch song.audio {
        case let .stems(prefix):
            if let loaded = loadStemFiles(prefix: prefix), loaded.count == StemKind.allCases.count {
                files = loaded
                source = .stems
                return
            }
        case let .mixed(resource):
            if let mixed = loadFile(named: resource) {
                files = [.drums: mixed]
                source = .mixed
                return
            }
        case .procedural:
            break
        }

        if song.audio != .procedural {
            logger.error("audio for \(song.id, privacy: .public) is missing; falling back to the procedural track")
        }
        source = .procedural
        buffers = await synthesiseStems()
    }

    private func loadStemFiles(prefix: String) -> [StemKind: AVAudioFile]? {
        var loaded: [StemKind: AVAudioFile] = [:]
        for kind in StemKind.allCases {
            guard let file = loadFile(named: "\(prefix)-\(kind.fileName)") else { return nil }
            loaded[kind] = file
        }
        validate(loaded)
        return loaded
    }

    /// Checks that the stems really are the one song cut four ways.
    ///
    /// They are scheduled on a single shared start time and never resynchronised, so a
    /// stem that is a different length or a different sample rate simply drifts out of the
    /// arrangement. Without this the failure is silent: the song still plays, the clock is
    /// still correct, and one layer is quietly wrong for the whole run.
    private func validate(_ loaded: [StemKind: AVAudioFile]) {
        guard let reference = loaded[.drums] else { return }
        let referenceRate = reference.processingFormat.sampleRate
        let referenceDuration = duration(of: reference)

        // A tenth of a beat at 120 BPM. Anything larger is audible as a flam.
        let tolerance = 0.05

        for kind in StemKind.allCases where kind != .drums {
            guard let file = loaded[kind] else { continue }

            let rate = file.processingFormat.sampleRate
            if rate != referenceRate {
                logger.error("""
                    stem \(kind.rawValue, privacy: .public) is \(rate, privacy: .public) Hz                     but drums is \(referenceRate, privacy: .public) Hz
                    """)
            }

            let delta = duration(of: file) - referenceDuration
            if abs(delta) > tolerance {
                logger.error("""
                    stem \(kind.rawValue, privacy: .public) is \(delta, privacy: .public) s                     longer than drums; stems must be the same length and aligned at sample 0
                    """)
            }
        }
    }

    private func duration(of file: AVAudioFile) -> Double {
        let rate = file.processingFormat.sampleRate
        guard rate > 0 else { return 0 }
        return Double(file.length) / rate
    }

    private func loadFile(named name: String) -> AVAudioFile? {
        guard let url = Self.bundledURL(named: name) else { return nil }
        do {
            return try AVAudioFile(forReading: url)
        } catch {
            logger.error("could not read \(url.lastPathComponent, privacy: .public)")
            return nil
        }
    }

    /// Whether `song`'s audio is in the bundle. Checked before a chart is built, so a
    /// missing file swaps in the procedural song *and its chart* rather than judging a
    /// 115 BPM chart against a 120 BPM fallback.
    static func hasAudio(for song: Song) -> Bool {
        switch song.audio {
        case .procedural:
            return true
        case let .mixed(resource):
            return bundledURL(named: resource) != nil
        case let .stems(prefix):
            return StemKind.allCases.allSatisfy { bundledURL(named: "\(prefix)-\($0.fileName)") != nil }
        }
    }

    /// Supported extensions, in order of preference. `.caf` first: the shipped tracks are
    /// ALAC in CAF, which carries no encoder priming, so beat 0 stays exactly where it was
    /// measured. AAC in `.m4a` can shift it by a few dozen milliseconds.
    static let audioExtensions = ["caf", "m4a", "wav", "aif", "aiff", "mp3"]

    /// Finds a bundled audio file. A synchronised folder is flattened into the bundle
    /// root, but a folder reference would keep `Tracks/`, so both are checked.
    static func bundledURL(named name: String) -> URL? {
        for ext in audioExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Tracks") {
                return url
            }
        }
        return nil
    }

    /// Synthesis touches a few million samples, so it stays off the main actor.
    private func synthesiseStems() async -> [StemKind: AVAudioPCMBuffer] {
        await Task.detached(priority: .userInitiated) {
            let track = ProceduralTrack()
            guard let format = AVAudioFormat(
                standardFormatWithSampleRate: track.sampleRate,
                channels: 1
            ) else { return [:] }
            return track.makeBuffers(format: format)
        }.value
    }

    private func buildGraph() {
        engine.attach(stemMixer)
        engine.attach(lowPass)
        lowPass.bypass = true

        engine.connect(stemMixer, to: lowPass, format: Self.processingFormat)
        engine.connect(lowPass, to: engine.mainMixerNode, format: Self.processingFormat)

        for kind in activeStems() {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: stemMixer, format: formatFor(kind))
            players[kind] = player
        }

        switch source {
        case .stems, .procedural:
            layering = StemLayering(players: players)
        case .mixed:
            // One file cannot be un-mixed, so brightness stands in for the arrangement.
            layering = FilterLayering(lowPass: lowPass)
        }

        startEngine()
    }

    @discardableResult
    private func startEngine() -> Bool {
        guard !engine.isRunning else { return true }
        do {
            try engine.start()
            return true
        } catch {
            logger.error("engine start failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func activeStems() -> [StemKind] {
        source == .mixed ? [.drums] : StemKind.allCases
    }

    private func formatFor(_ kind: StemKind) -> AVAudioFormat? {
        files[kind]?.processingFormat ?? buffers[kind]?.format
    }

    // MARK: - Transport

    /// Starts every stem on one shared, sample-accurate start time.
    ///
    /// Scheduling each player "now" would let them begin on different render cycles, and
    /// a stem a few milliseconds out of phase reads as a flam rather than a chord.
    func start() {
        guard !players.isEmpty else { return }
        pausedSongTime = nil

        // Without a running engine there is no render clock, so the session would sit at
        // songTime nil forever and silently judge nothing. Better to know.
        guard startEngine() else {
            logger.error("cannot start playback: audio engine is not running")
            return
        }

        outputLatency = AVAudioSession.sharedInstance().outputLatency
        layering?.reset()

        // Far enough ahead that every node is armed before the shared start time passes.
        let leadIn = 0.2
        let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: leadIn)
        let startTime = AVAudioTime(hostTime: hostTime)

        for (kind, player) in players {
            player.stop()
            player.volume = 1.0
            schedule(kind, on: player)
            player.play(at: startTime)
        }
        isRunning = true
    }

    private func schedule(_ kind: StemKind, on player: AVAudioPlayerNode) {
        if let buffer = buffers[kind] {
            // The synthesised track is an 8-bar loop, so it repeats for the whole song.
            player.scheduleBuffer(buffer, at: nil, options: [.loops])
        } else if let file = files[kind] {
            file.framePosition = 0
            player.scheduleFile(file, at: nil)
        }
    }

    func pause() {
        guard isRunning, pausedSongTime == nil else { return }
        pausedSongTime = songTime
        engine.pause()
    }

    func resume() {
        guard isRunning, pausedSongTime != nil else { return }
        startEngine()
        pausedSongTime = nil
    }

    func stop() {
        for player in players.values {
            player.stop()
        }
        isRunning = false
        pausedSongTime = nil
    }
}
