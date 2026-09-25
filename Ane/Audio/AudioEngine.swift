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

    /// Builds the graph and loads or synthesises the stems. Safe to call once per app run.
    func prepare() async {
        configureSession()
        await loadSources()
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

    private func loadSources() async {
        if let loaded = loadStemFiles(), loaded.count == StemKind.allCases.count {
            files = loaded
            source = .stems
            return
        }

        if let mixed = loadFile(named: "song") {
            files = [.drums: mixed]
            source = .mixed
            return
        }

        source = .procedural
        buffers = await synthesiseStems()
    }

    private func loadStemFiles() -> [StemKind: AVAudioFile]? {
        var loaded: [StemKind: AVAudioFile] = [:]
        for kind in StemKind.allCases {
            guard let file = loadFile(named: kind.fileName) else { return nil }
            loaded[kind] = file
        }
        return loaded
    }

    private func loadFile(named name: String) -> AVAudioFile? {
        for ext in ["m4a", "caf", "wav", "aif", "aiff", "mp3"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { continue }
            do {
                return try AVAudioFile(forReading: url)
            } catch {
                logger.error("could not read \(name, privacy: .public).\(ext, privacy: .public)")
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
