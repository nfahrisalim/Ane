import SwiftUI
import SpriteKit

/// Wires the rule layer to everything that reacts to it.
///
/// `GameSession` emits events; this object is the single place that decides what the scene
/// draws, what the hand feels, what the mixer does and what the HUD shows. Keeping that
/// fan-out here is what lets the session stay pure and unit-testable.
@Observable
@MainActor
final class GameController {

    /// A judgment worth announcing on screen, with an identity so the HUD can re-animate
    /// the same verdict twice in a row.
    struct Flash: Equatable {
        let id: Int
        let judgment: Judgment
        let color: BeamColor
    }

    // Mirrored for the HUD. Assigned only on change, so @Observable does not invalidate
    // the HUD on every one of 120 frames per second.
    var score = 0
    var combo = 0
    var multiplier = 1
    var flash: Flash?
    var isPaused = false
    var isReady = false
    /// 0...1 through the song, for the HUD's progress bar. Stepped, not continuous, for
    /// the same reason as the fields above.
    var progress: Double = 0

    /// The song actually being played. Differs from the one asked for only when that
    /// song's audio is missing from the bundle and the procedural track stands in.
    let song: Song
    let scene: GameScene
    let chart: Chart

    private let audio = AudioEngine()
    private let haptics: Haptics
    private let session: GameSession
    private var flashCounter = 0
    private var flashTask: Task<Void, Never>?
    private var onFinish: ((RunResult) -> Void)?

    init(song requested: Song, size: CGSize, haptics: Haptics) {
        // Decide the song before the chart: the chart has to match the audio that will
        // really play, or every judgment is measured against the wrong beat grid.
        let song = AudioEngine.hasAudio(for: requested) ? requested : SongCatalog.prismDemo
        let chart = song.makeChart()
        self.song = song
        self.chart = chart
        self.haptics = haptics

        let motion = MotionSettings.current
        self.scene = GameScene(
            size: size,
            layout: chart.layout,
            beatDuration: chart.beatDuration,
            motion: motion
        )
        self.session = GameSession(chart: chart, clock: audio)

        wire()
    }

    private func wire() {
        session.onEvent = { [weak self] event in
            self?.handle(event)
        }
        scene.onFrame = { [weak self] angle, delta in
            self?.tick(prismAngle: angle, delta: delta)
        }
        scene.onRotate = { [weak self] angle in
            self?.haptics.rotationTick(unboundedAngle: angle)
        }
        scene.onGestureBegan = { [weak self] in
            self?.haptics.prepareForRotation()
        }
    }

    // MARK: - Lifecycle

    func start(onFinish: @escaping (RunResult) -> Void) async {
        self.onFinish = onFinish
        await audio.prepare(song: song)
        audio.start()
        isReady = true
    }

    func togglePause() {
        isPaused ? resume() : pause()
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        // Both halves matter: the audio clock must stop advancing, and the scene must stop
        // animating, or the telegraph rings drift out of phase with the song on resume.
        audio.pause()
        scene.isPaused = true
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        scene.isPaused = false
        audio.resume()
    }

    func stop() {
        flashTask?.cancel()
        audio.stop()
        scene.isPaused = true
    }

    // MARK: - Frame

    private func tick(prismAngle: Double, delta: Double) {
        session.update(prismAngle: prismAngle)
        audio.layering?.tick(deltaTime: delta)

        if score != session.score { score = session.score }
        if combo != session.combo { combo = session.combo }
        if multiplier != session.multiplier { multiplier = session.multiplier }

        if let time = session.songTime, chart.duration > 0 {
            let fraction = min(max(time / chart.duration, 0), 1)
            if abs(fraction - progress) >= 0.005 || (fraction == 1 && progress != 1) { progress = fraction }
        }
    }

    // MARK: - Events

    private func handle(_ event: GameEvent) {
        switch event {
        case let .telegraph(_, note):
            scene.telegraph(note)

        case let .judged(judgment, _, note):
            scene.resolve(judgment, note: note)
            haptics.play(judgment)
            apply(judgment, color: note.color)
            if judgment != .miss {
                showFlash(judgment, color: note.color)
            }

        case .downbeat:
            haptics.playDownbeat()
            scene.markDownbeat()

        case let .songEnded(result):
            stop()
            onFinish?(result)
        }
    }

    private func apply(_ judgment: Judgment, color: BeamColor) {
        guard let layering = audio.layering else { return }
        if judgment == .miss {
            layering.registerMiss(color)
        } else {
            layering.registerHit(color)
        }
        layering.updateCombo(session.combo)
    }

    private func showFlash(_ judgment: Judgment, color: BeamColor) {
        flashCounter += 1
        flash = Flash(id: flashCounter, judgment: judgment, color: color)

        flashTask?.cancel()
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.flash = nil
        }
    }
}
