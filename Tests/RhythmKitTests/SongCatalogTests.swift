import Testing
import Foundation
@testable import RhythmKit

@Suite("SongCatalog")
struct SongCatalogTests {

    /// Decoded lengths of the bundled files, in seconds (ffprobe on Ane/Audio/Tracks).
    /// A chart that runs past its file would end the song in silence.
    private let fileDurations: [String: Double] = [
        "retro-orbit": 158.08,
        "hyperspace-finish": 161.14,
        "galaxy-launch": 160.77,
        "starlight-arpeggio": 160.96,
        "nebula-disco": 162.07,
        "solstice-party": 141.45
    ]

    @Test("ids and seeds are unique")
    func unique() {
        let ids = SongCatalog.all.map(\.id)
        let seeds = SongCatalog.all.map(\.seed)
        #expect(Set(ids).count == ids.count)
        #expect(Set(seeds).count == seeds.count)
    }

    @Test("every chart ends inside its audio file", arguments: SongCatalog.all)
    func fitsInFile(song: Song) {
        guard let fileDuration = fileDurations[song.id] else { return }
        let chart = song.makeChart()
        #expect(chart.duration <= fileDuration, "\(song.id) runs \(chart.duration - fileDuration) s past its file")
    }

    @Test("section lists cover the whole song", arguments: SongCatalog.all)
    func sectionsCover(song: Song) {
        guard let sections = song.sections else { return }
        let covered = sections.count * song.generatorConfig.phraseBeats
        // Within one phrase either way: the last entry is allowed to be partial.
        #expect(abs(covered - song.totalBeats) < song.generatorConfig.phraseBeats)
    }

    @Test("rest phrases really are empty")
    func restIsEmpty() {
        let song = SongCatalog.hyperspaceFinish
        let chart = song.makeChart()
        // Phrase 11 is the breakdown.
        let breakdown = (11 * 16)..<(12 * 16)
        #expect(chart.notes.allSatisfy { !breakdown.contains($0.beatIndex) })
    }

    @Test("sparse phrases put one note on each bar line")
    func sparseOnBarLines() {
        let song = SongCatalog.galaxyLaunch
        let chart = song.makeChart()
        let intro = chart.notes.filter { $0.beatIndex < 32 }
        #expect(!intro.isEmpty)
        #expect(intro.allSatisfy { $0.beatIndex % 4 == 0 })
    }

    @Test("the list is ordered easiest first")
    func ordered() {
        let levels = SongCatalog.all.map(\.difficulty)
        #expect(levels == levels.sorted())
        #expect(SongCatalog.retroOrbit.difficulty == .easy)
        #expect(SongCatalog.solsticeParty.difficulty == .hard)
    }

    @Test("the demo keeps the original chart")
    func demoUnchanged() {
        let demo = SongCatalog.prismDemo.makeChart()
        let original = ChartGenerator().makeChart(seed: 2026_0325)
        #expect(demo.notes == original.notes)
    }
}
