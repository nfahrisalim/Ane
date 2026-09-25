import Foundation

/// The songs that ship with the game.
///
/// Tempo and beat-0 offsets were measured from the audio (onset comb-fit, to the
/// millisecond), and each `sections` list was read off the track's energy per four bars:
/// `sparse` in the pad-only intro, `half` in the verses, `full` in the drops, `rest` in
/// breakdowns and fades. Re-measure if a file is ever re-exported -- a different encoder
/// can shift beat 0.
///
/// `SongCatalogTests` checks every chart fits inside its song.
public enum SongCatalog {

    private static let s = Density.sparse
    private static let h = Density.half
    private static let f = Density.full
    private static let r = Density.rest

    public static let retroOrbit = Song(
        id: "retro-orbit",
        title: "Retro Orbit",
        artist: "Mazarelli",
        audio: .mixed(resource: "retro-orbit"),
        bpm: 115,
        firstBeatOffset: 0.011,
        totalBeats: 302,
        sections: [s, s, h, h, h, h, h, h, f, f, h, h, h, h, f, f, f, f, r],
        seed: 0x5E70_0B17,
        previewStart: 66.8
    )

    public static let hyperspaceFinish = Song(
        id: "hyperspace-finish",
        title: "Hyperspace Finish",
        artist: "Mazarelli",
        audio: .mixed(resource: "hyperspace-finish"),
        bpm: 115,
        firstBeatOffset: 0.043,
        totalBeats: 308,
        sections: [s, s, h, h, h, h, h, f, f, f, s, r, s, h, f, f, f, f, s, r],
        seed: 0x4E7F_1A15,
        previewStart: 58.5
    )

    public static let galaxyLaunch = Song(
        id: "galaxy-launch",
        title: "Galaxy Launch",
        artist: "Mazarelli",
        audio: .mixed(resource: "galaxy-launch"),
        bpm: 115,
        firstBeatOffset: 0.017,
        totalBeats: 308,
        sections: [s, s, h, h, h, h, f, f, f, f, h, h, h, h, f, f, f, f, s, r],
        seed: 0x6A1A_C71C,
        previewStart: 50.1
    )

    public static let starlightArpeggio = Song(
        id: "starlight-arpeggio",
        title: "Starlight Arpeggio",
        artist: "Mazarelli",
        audio: .mixed(resource: "starlight-arpeggio"),
        bpm: 115,
        firstBeatOffset: 0.010,
        totalBeats: 308,
        sections: [s, s, h, h, h, h, f, f, f, f, h, h, h, h, f, f, f, f, s, r],
        seed: 0x57A2_A4E6,
        previewStart: 50.1
    )

    public static let nebulaDisco = Song(
        id: "nebula-disco",
        title: "Nebula Disco",
        artist: "Mazarelli",
        audio: .mixed(resource: "nebula-disco"),
        bpm: 115,
        firstBeatOffset: 0.043,
        totalBeats: 310,
        sections: [s, s, s, h, h, h, h, f, f, f, f, s, s, f, f, f, f, f, f, r],
        seed: 0x2EB0_D15C,
        previewStart: 58.5
    )

    public static let solsticeParty = Song(
        id: "solstice-party",
        title: "Solstice Party",
        artist: "gbproductions",
        audio: .mixed(resource: "solstice-party"),
        bpm: 129,
        firstBeatOffset: 0.010,
        totalBeats: 303,
        sections: [h, f, f, f, h, f, f, f, f, f, h, h, f, f, f, f, f, f, h],
        seed: 0x5015_71CE,
        previewStart: 37.2
    )

    /// The original synthesised loop. Needs no file, so it is also what plays if a
    /// bundled track ever fails to load.
    public static let prismDemo = Song(
        id: "prism-demo",
        title: "Prism Groove",
        artist: "Prism Groove team",
        audio: .procedural,
        bpm: 120,
        firstBeatOffset: 0,
        totalBeats: 240,
        sections: nil,
        seed: 2026_0325,
        previewStart: 0
    )

    /// Easiest first, so the list reads as a path through the game.
    public static let all: [Song] = [
        retroOrbit,
        hyperspaceFinish,
        galaxyLaunch,
        starlightArpeggio,
        nebulaDisco,
        solsticeParty,
        prismDemo
    ]

    public static func song(id: String) -> Song? {
        all.first { $0.id == id }
    }
}
