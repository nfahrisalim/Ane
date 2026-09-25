import Foundation

/// Everything the session tells the outside world about. The scene draws these, the
/// audio layer mixes on them, haptics fire on them and the HUD reads them -- none of
/// those subsystems ever judges anything itself.
public enum GameEvent: Equatable, Sendable {
    /// One beat before `note` must be hit. Drives the shrinking approach ring and the pulse.
    case telegraph(noteIndex: Int, note: Note)
    case judged(Judgment, noteIndex: Int, note: Note)
    /// Every 4th beat, straight off the audio clock.
    case downbeat(beatIndex: Int)
    case songEnded(RunResult)
}

/// Owns the clock, the chart, judging and scoring for one run.
///
/// This is the rule layer. `GameScene` reports the prism angle each frame and renders
/// what comes back; it never computes a judgment or a score. Because nothing here
/// imports SpriteKit or UIKit, a whole run can be simulated in a unit test.
public final class GameSession {

    public let chart: Chart
    public let windows: JudgeWindows
    private let clock: BeatClock

    public var onEvent: ((GameEvent) -> Void)?

    private var keeper = ScoreKeeper()
    private var telegraphCursor = 0
    private var activationCursor = 0
    private var active: [(index: Int, judge: NoteJudge)] = []
    private var lastDownbeat = -1
    private var hasEnded = false

    public init(chart: Chart, clock: BeatClock, windows: JudgeWindows = .standard) {
        self.chart = chart
        self.clock = clock
        self.windows = windows
    }

    // MARK: - Read-only state for the HUD

    public var score: Int { keeper.score }
    public var combo: Int { keeper.combo }
    public var multiplier: Int { keeper.multiplier }
    public var accuracy: Double { keeper.accuracy }
    public var result: RunResult { RunResult(keeper) }
    public var isFinished: Bool { hasEnded }
    public var songTime: Double? { clock.songTime }

    private var layout: Layout { chart.layout }

    // MARK: - Frame tick

    /// Call once per rendered frame. Pulls song time from the clock itself, so a slow or
    /// skipped frame can never shift the beat grid.
    public func update(prismAngle: Double) {
        guard let time = clock.songTime else { return }
        step(time: time, prismAngle: prismAngle)
    }

    /// Deterministic entry point used by tests and previews.
    public func step(time: Double, prismAngle: Double) {
        guard !hasEnded else { return }

        emitDownbeat(at: time)
        emitTelegraphs(upTo: time)
        activateNotes(upTo: time)
        judgeActiveNotes(time: time, prismAngle: prismAngle)

        if time >= chart.duration {
            hasEnded = true
            onEvent?(.songEnded(RunResult(keeper)))
        }
    }

    private func emitDownbeat(at time: Double) {
        let elapsed = time - chart.firstBeatOffset
        guard elapsed >= 0 else { return }
        let beat = Int(floor(elapsed / chart.beatDuration))
        guard beat > lastDownbeat else { return }
        lastDownbeat = beat
        if beat % 4 == 0 {
            onEvent?(.downbeat(beatIndex: beat))
        }
    }

    private func emitTelegraphs(upTo time: Double) {
        while telegraphCursor < chart.notes.count,
              time >= chart.time(of: telegraphCursor) - chart.beatDuration {
            onEvent?(.telegraph(noteIndex: telegraphCursor, note: chart.notes[telegraphCursor]))
            telegraphCursor += 1
        }
    }

    private func activateNotes(upTo time: Double) {
        while activationCursor < chart.notes.count,
              time >= chart.time(of: activationCursor) - windows.good {
            active.append(
                (activationCursor, NoteJudge(beatTime: chart.time(of: activationCursor), windows: windows))
            )
            activationCursor += 1
        }
    }

    private func judgeActiveNotes(time: Double, prismAngle: Double) {
        guard !active.isEmpty else { return }

        for slot in active.indices {
            let note = chart.notes[active[slot].index]
            let aligned = layout.isAligned(
                prismAngle: prismAngle,
                targetIndex: note.targetIndex,
                color: note.color
            )

            guard let judgment = active[slot].judge.update(time: time, aligned: aligned) else { continue }

            keeper.register(judgment)
            onEvent?(.judged(judgment, noteIndex: active[slot].index, note: note))
        }

        active.removeAll { $0.judge.isResolved }
    }
}
