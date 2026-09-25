import AVFoundation
import os

/// Plays a short excerpt of the highlighted song on the song-select screen.
///
/// Deliberately separate from `AudioEngine`: a preview needs none of the sample-accurate
/// clock, and keeping it on a plain `AVAudioPlayer` means the game's engine is never
/// built until a run actually starts.
@MainActor
final class TrackPreviewPlayer {

    /// Long enough to hear the groove, short enough not to become background music.
    private static let excerptLength: Duration = .seconds(20)
    private static let volume: Float = 0.8

    private var player: AVAudioPlayer?
    private var currentSongID: String?
    private var excerptTask: Task<Void, Never>?

    private let logger = Logger(subsystem: "com.dissent.academy.Ane", category: "preview")

    /// Starts `song`'s excerpt, cross-fading out whatever was playing. Songs with no
    /// single bundled file (the synthesised one, or stems) have no preview.
    func play(_ song: Song) {
        guard currentSongID != song.id else { return }
        stop()
        currentSongID = song.id

        guard case let .mixed(resource) = song.audio,
              let url = AudioEngine.bundledURL(named: resource) else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.currentTime = min(song.previewStart, max(player.duration - 1, 0))
            player.volume = 0
            player.prepareToPlay()
            player.play()
            player.setVolume(Self.volume, fadeDuration: 0.6)
            self.player = player
        } catch {
            logger.error("preview failed for \(song.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }

        excerptTask = Task { [weak self] in
            try? await Task.sleep(for: Self.excerptLength)
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    /// Fades out and releases the player. Safe to call when nothing is playing.
    func stop() {
        excerptTask?.cancel()
        excerptTask = nil
        currentSongID = nil

        guard let outgoing = player else { return }
        player = nil
        outgoing.setVolume(0, fadeDuration: 0.25)
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            outgoing.stop()
        }
    }
}
