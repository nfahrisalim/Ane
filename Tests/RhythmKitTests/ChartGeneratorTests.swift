import Testing
import Foundation
@testable import RhythmKit

@Suite("ChartGenerator")
struct ChartGeneratorTests {

    private let generator = ChartGenerator()

    @Test("the same seed yields an identical chart")
    func deterministic() {
        let a = generator.makeChart(seed: 20260325)
        let b = generator.makeChart(seed: 20260325)
        #expect(a.notes == b.notes)
    }

    @Test("different seeds yield different charts")
    func seedMatters() {
        let a = generator.makeChart(seed: 1)
        let b = generator.makeChart(seed: 2)
        #expect(a.notes != b.notes)
    }

    @Test("no target is asked for more than twice in a row")
    func targetRuns() {
        for seed in UInt64(1)...40 {
            let notes = generator.makeChart(seed: seed).notes
            var run = 0
            var previous = -1
            for note in notes {
                run = note.targetIndex == previous ? run + 1 : 1
                previous = note.targetIndex
                #expect(run <= generator.config.maxTargetRun, "seed \(seed) ran a target \(run) times")
            }
        }
    }

    @Test("the last four beats are empty for the outro")
    func outroIsEmpty() {
        let chart = generator.makeChart(seed: 7)
        let firstOutroBeat = chart.totalBeats - generator.config.outroBeats
        #expect(chart.notes.allSatisfy { $0.beatIndex < firstOutroBeat })
    }

    @Test("nothing lands before the lead-in")
    func leadInIsEmpty() {
        let chart = generator.makeChart(seed: 7)
        #expect(chart.notes.allSatisfy { $0.beatIndex >= generator.config.leadInBeats })
    }

    @Test("the warm-up is sparse, the body is one note per beat")
    func density() {
        let config = generator.config
        let chart = generator.makeChart(seed: 11)
        let warmUpEnd = config.leadInBeats + config.warmUpBeats

        let warmUp = chart.notes.filter { $0.beatIndex < warmUpEnd }
        for (earlier, later) in zip(warmUp, warmUp.dropFirst()) {
            #expect(later.beatIndex - earlier.beatIndex == config.warmUpStride)
        }

        let body = chart.notes.filter { $0.beatIndex >= warmUpEnd }
        for (earlier, later) in zip(body, body.dropFirst()) {
            #expect(later.beatIndex - earlier.beatIndex == 1)
        }
        #expect(body.count > warmUp.count)
    }

    @Test("beat indices strictly increase")
    func monotonic() {
        let chart = generator.makeChart(seed: 99)
        for (earlier, later) in zip(chart.notes, chart.notes.dropFirst()) {
            #expect(later.beatIndex > earlier.beatIndex)
        }
    }

    @Test("every note's colour matches its target's colour")
    func coloursAgreeWithTargets() {
        let chart = generator.makeChart(seed: 3)
        for note in chart.notes {
            #expect(note.color == chart.layout.targetColors[note.targetIndex])
        }
    }

    @Test("a 120 BPM 240-beat chart is two minutes long")
    func duration() {
        let chart = generator.makeChart(seed: 1)
        #expect(abs(chart.duration - 120.0) < 1e-9)
        #expect(abs(chart.beatDuration - 0.5) < 1e-9)
    }
}
