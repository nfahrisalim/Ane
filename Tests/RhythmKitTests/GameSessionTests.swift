import Testing
import Foundation
@testable import RhythmKit

@Suite("GameSession")
struct GameSessionTests {

    private let frameRate = 60.0

    private func makeChart(totalBeats: Int = 40) -> Chart {
        var config = ChartGenerator.Config()
        config.totalBeats = totalBeats
        return ChartGenerator(config: config).makeChart(seed: 42)
    }

    /// Simulates a run. `angle` decides where the prism points at a given song time.
    private func simulate(
        chart: Chart,
        angle: (Double, Chart) -> Double
    ) -> (events: [GameEvent], session: GameSession) {
        let clock = MockBeatClock(songTime: 0)
        let session = GameSession(chart: chart, clock: clock)
        var events: [GameEvent] = []
        session.onEvent = { events.append($0) }

        var time = 0.0
        while time <= chart.duration + 0.5, !session.isFinished {
            clock.songTime = time
            session.update(prismAngle: angle(time, chart))
            time += 1.0 / frameRate
        }
        return (events, session)
    }

    /// Where a flawless player would hold the prism: on the note whose beat is nearest.
    private func perfectAngle(at time: Double, chart: Chart) -> Double {
        var best = chart.notes[0]
        var bestDistance = Double.infinity
        for note in chart.notes {
            let d = abs(chart.beatTime(note.beatIndex) - time)
            if d < bestDistance {
                bestDistance = d
                best = note
            }
        }
        return chart.layout.requiredPrismAngle(for: best)
    }

    @Test("a flawless run scores every note Perfect")
    func flawlessRun() {
        let chart = makeChart()
        let (events, session) = simulate(chart: chart, angle: perfectAngle)

        #expect(session.result.perfectCount == chart.notes.count)
        #expect(session.result.goodCount == 0)
        #expect(session.result.missCount == 0)
        #expect(abs(session.accuracy - 1.0) < 1e-12)
        #expect(session.result.maxCombo == chart.notes.count)

        let judged = events.compactMap { event -> Judgment? in
            if case let .judged(judgment, _, _) = event { return judgment }
            return nil
        }
        #expect(judged.count == chart.notes.count)
        #expect(judged.allSatisfy { $0 == .perfect })
    }

    @Test("a player who never rotates misses everything")
    func idleRun() {
        let chart = makeChart()
        // Park the prism where no note's beam can reach any target.
        let parked = chart.layout.requiredPrismAngle(for: chart.notes[0]) + AngleMath.radians(degrees: 60)
        let (_, session) = simulate(chart: chart) { _, _ in parked }

        #expect(session.result.missCount + session.result.goodCount + session.result.perfectCount == chart.notes.count)
        #expect(session.result.missCount > 0)
        #expect(session.result.maxCombo < chart.notes.count)
    }

    @Test("every note is judged exactly once")
    func judgedOnce() {
        let chart = makeChart()
        let (events, _) = simulate(chart: chart, angle: perfectAngle)
        var seen: [Int] = []
        for event in events {
            if case let .judged(_, noteIndex, _) = event { seen.append(noteIndex) }
        }
        #expect(seen.count == chart.notes.count)
        #expect(Set(seen).count == chart.notes.count)
    }

    @Test("every note is telegraphed once, one beat ahead, before it is judged")
    func telegraphOrdering() {
        let chart = makeChart()
        let (events, _) = simulate(chart: chart, angle: perfectAngle)

        var telegraphed: [Int] = []
        var judgedAfterTelegraph = 0
        for event in events {
            switch event {
            case let .telegraph(noteIndex, _):
                telegraphed.append(noteIndex)
            case let .judged(_, noteIndex, _):
                if telegraphed.contains(noteIndex) { judgedAfterTelegraph += 1 }
            default:
                break
            }
        }
        #expect(telegraphed.count == chart.notes.count)
        #expect(Set(telegraphed).count == chart.notes.count)
        #expect(judgedAfterTelegraph == chart.notes.count)
    }

    @Test("songEnded fires exactly once, at the end")
    func endsOnce() {
        let chart = makeChart()
        let (events, session) = simulate(chart: chart, angle: perfectAngle)
        let endings = events.filter { if case .songEnded = $0 { return true } else { return false } }
        #expect(endings.count == 1)
        #expect(session.isFinished)
        if case let .songEnded(result) = endings[0] {
            #expect(result.score == session.result.score)
        }
    }

    @Test("downbeats land on every 4th beat and nowhere else")
    func downbeats() {
        let chart = makeChart()
        let (events, _) = simulate(chart: chart, angle: perfectAngle)
        var beats: [Int] = []
        for event in events {
            if case let .downbeat(beatIndex) = event { beats.append(beatIndex) }
        }
        #expect(!beats.isEmpty)
        #expect(beats.allSatisfy { $0 % 4 == 0 })
        #expect(beats == beats.sorted())
        #expect(Set(beats).count == beats.count)
    }

    @Test("the session stays idle until the clock starts")
    func idleBeforeClock() {
        let chart = makeChart()
        let clock = MockBeatClock(songTime: nil)
        let session = GameSession(chart: chart, clock: clock)
        var events: [GameEvent] = []
        session.onEvent = { events.append($0) }

        for _ in 0..<120 { session.update(prismAngle: 0) }
        #expect(events.isEmpty)
        #expect(session.score == 0)
    }

    @Test("a long stall still resolves every skipped note")
    func stallResolvesEverything() {
        let chart = makeChart()
        let clock = MockBeatClock(songTime: 0)
        let session = GameSession(chart: chart, clock: clock)
        session.update(prismAngle: 0)
        // One enormous frame, as if the app were backgrounded mid-song.
        clock.songTime = chart.duration
        session.update(prismAngle: 0)
        #expect(session.result.noteCount == chart.notes.count)
        #expect(session.isFinished)
    }

    @Test("holding one target through its repeat earns Perfect on both notes")
    func heldRepeatsAreBothPerfect() {
        let chart = makeChart()
        // Find a target that the generator asks for twice in a row.
        guard let runStart = zip(chart.notes, chart.notes.dropFirst())
            .first(where: { $0.targetIndex == $1.targetIndex })?.0 else {
            return
        }
        let hold = chart.layout.requiredPrismAngle(for: runStart)
        let clock = MockBeatClock(songTime: 0)
        let session = GameSession(chart: chart, clock: clock)
        var judgments: [Int: Judgment] = [:]
        session.onEvent = { event in
            if case let .judged(judgment, noteIndex, _) = event { judgments[noteIndex] = judgment }
        }

        var time = 0.0
        while time <= chart.duration, !session.isFinished {
            clock.songTime = time
            session.update(prismAngle: hold)
            time += 1.0 / frameRate
        }

        let indices = chart.notes.indices.filter { chart.notes[$0].targetIndex == runStart.targetIndex }
        let perfects = indices.compactMap { judgments[$0] }.filter { $0 == .perfect }
        #expect(perfects.count >= 2)
    }
}
