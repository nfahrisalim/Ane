import Foundation

/// How busy one phrase of a chart is.
public enum Density: Sendable, Hashable {
    /// No notes. Breakdowns and fades.
    case rest
    /// One note a bar. Intros, where the track is still only a pad.
    case sparse
    /// A note every other beat. Verses.
    case half
    /// A note on every beat. Drops and choruses.
    case full

    /// Beats between notes, or nil for a phrase with none.
    public var stride: Int? {
        switch self {
        case .rest: return nil
        case .sparse: return 4
        case .half: return 2
        case .full: return 1
        }
    }

    /// Whether a note belongs on `beat`. Notes sit on the phrase grid (bar lines for
    /// `sparse`, strong beats for `half`), so the chart lands where the music accents.
    public func includes(beat: Int) -> Bool {
        guard let stride else { return false }
        return beat % stride == 0
    }
}

/// Where a song's audio comes from.
public enum SongAudio: Sendable, Hashable {
    /// Synthesised at runtime by `ProceduralTrack`. Needs no file.
    case procedural
    /// One mixed file in the bundle, named without its extension.
    case mixed(resource: String)
    /// Four aligned stems named `<prefix>-drums`, `-bass`, `-synth` and `-lead`.
    case stems(prefix: String)
}

/// Rough difficulty, derived from how many notes the chart asks for per minute.
public enum Difficulty: Int, Sendable, Hashable, Comparable, CaseIterable {
    case easy, normal, hard

    public var label: String {
        switch self {
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        }
    }

    public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Thresholds picked from the shipped catalogue: a verse-and-chorus song at
    /// 115 BPM lands around 70-80 notes a minute, every-beat charts above 100.
    public init(notesPerMinute: Double) {
        switch notesPerMinute {
        case ..<70: self = .easy
        case ..<95: self = .normal
        default: self = .hard
        }
    }
}

/// Everything needed to play one track: its audio, its beat grid and the shape of its
/// chart. Pure data, so the whole catalogue can be checked in a unit test.
public struct Song: Identifiable, Sendable, Hashable {

    public let id: String
    public let title: String
    public let artist: String
    public let audio: SongAudio

    public let bpm: Double
    /// Time of beat 0 in the audio file, in seconds.
    public let firstBeatOffset: Double
    /// Beats that fit inside the file, counted from `firstBeatOffset`.
    public let totalBeats: Int
    /// Density per 16-beat phrase. nil keeps the generator's original warm-up shape.
    public let sections: [Density]?
    /// Fixed per song, so every run of a song is the same chart and a best score means
    /// something.
    public let seed: UInt64
    /// Where the song-select preview starts, in seconds: the first chorus.
    public let previewStart: Double

    public init(
        id: String,
        title: String,
        artist: String,
        audio: SongAudio,
        bpm: Double,
        firstBeatOffset: Double,
        totalBeats: Int,
        sections: [Density]?,
        seed: UInt64,
        previewStart: Double
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.audio = audio
        self.bpm = bpm
        self.firstBeatOffset = firstBeatOffset
        self.totalBeats = totalBeats
        self.sections = sections
        self.seed = seed
        self.previewStart = previewStart
    }

    public var beatDuration: Double { 60.0 / bpm }

    /// Playable length, which is what the results screen and the list show.
    public var duration: Double { firstBeatOffset + Double(totalBeats) * beatDuration }

    public var generatorConfig: ChartGenerator.Config {
        var config = ChartGenerator.Config()
        config.bpm = bpm
        config.firstBeatOffset = firstBeatOffset
        config.totalBeats = totalBeats
        config.sections = sections
        return config
    }

    public func makeChart(layout: Layout = .standard) -> Chart {
        ChartGenerator(config: generatorConfig, layout: layout).makeChart(seed: seed)
    }

    public var difficulty: Difficulty {
        let chart = makeChart()
        guard duration > 0 else { return .easy }
        return Difficulty(notesPerMinute: Double(chart.notes.count) / duration * 60)
    }
}
