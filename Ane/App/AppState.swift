import SwiftUI

/// Top-level navigation and the only thing that outlives a run.
@Observable
@MainActor
final class AppState {

    enum Screen: Equatable {
        /// Title and song select, inside one navigation stack.
        case menu
        /// `run` changes on every start, so Restart builds a fresh game even for the
        /// same song.
        case playing(Song, run: Int)
        case results(RunResult, Song)
    }

    /// Pushed destinations inside the menu's navigation stack.
    enum MenuRoute: Hashable {
        case songs
    }

    private enum Keys {
        /// Builds from before song select stored one best score for the only song.
        static let legacyBestScore = "bestScore"
        static let hasSeenHint = "hasSeenHint"
        static let lastSongID = "lastSongID"

        static func bestScore(_ songID: String) -> String { "bestScore.\(songID)" }
    }

    var screen: Screen = .menu
    var menuPath: [MenuRoute] = []
    /// The song highlighted in the list, remembered between launches.
    var selectedSongID: String {
        didSet { defaults.set(selectedSongID, forKey: Keys.lastSongID) }
    }

    private(set) var bestScores: [String: Int] = [:]
    private(set) var hasSeenHint: Bool
    /// Whether the most recent run beat the stored best. Recorded at the moment it is
    /// known; re-deriving it later would call an exact tie a new best.
    private(set) var lastRunWasBest = false

    private let defaults: UserDefaults
    private var runCounter = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasSeenHint = defaults.bool(forKey: Keys.hasSeenHint)
        self.selectedSongID = defaults.string(forKey: Keys.lastSongID)
            ?? SongCatalog.all.first?.id
            ?? SongCatalog.prismDemo.id

        // The old single best belonged to the procedural song; keep it there.
        let legacy = defaults.integer(forKey: Keys.legacyBestScore)
        let demoKey = Keys.bestScore(SongCatalog.prismDemo.id)
        if legacy > 0, defaults.object(forKey: demoKey) == nil {
            defaults.set(legacy, forKey: demoKey)
        }

        for song in SongCatalog.all {
            bestScores[song.id] = defaults.integer(forKey: Keys.bestScore(song.id))
        }
    }

    var selectedSong: Song {
        SongCatalog.song(id: selectedSongID) ?? SongCatalog.all[0]
    }

    func bestScore(for song: Song) -> Int {
        bestScores[song.id] ?? 0
    }

    /// Records a finished run. Returns true when it beat that song's stored best.
    @discardableResult
    func finish(_ result: RunResult, song: Song) -> Bool {
        let isNewBest = result.score > bestScore(for: song)
        lastRunWasBest = isNewBest
        if isNewBest {
            bestScores[song.id] = result.score
            defaults.set(result.score, forKey: Keys.bestScore(song.id))
        }
        screen = .results(result, song)
        return isNewBest
    }

    func markHintSeen() {
        guard !hasSeenHint else { return }
        hasSeenHint = true
        defaults.set(true, forKey: Keys.hasSeenHint)
    }

    func play(_ song: Song) {
        selectedSongID = song.id
        runCounter += 1
        screen = .playing(song, run: runCounter)
    }

    /// Back to the list, with the song just played still selected.
    func returnToSongs() {
        menuPath = [.songs]
        screen = .menu
    }

    func returnToTitle() {
        menuPath = []
        screen = .menu
    }
}
