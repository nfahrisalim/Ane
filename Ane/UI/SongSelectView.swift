import SwiftUI

/// Pick a song, hear it, play it.
///
/// A standard pushed list with a large title and a system back button, so it behaves the
/// way every other iPhone list does: swipe back works, VoiceOver reads each row as one
/// element, and every row is a full-width 44 pt+ target. The one action -- Play -- stays
/// pinned above the home indicator, where the thumb already is.
struct SongSelectView: View {

    @Bindable var appState: AppState

    @State private var preview = TrackPreviewPlayer()
    @Environment(\.scenePhase) private var scenePhase

    /// Difficulty and note count need a generated chart, so they are worked out once.
    private static let details: [String: SongDetails] = Dictionary(
        uniqueKeysWithValues: SongCatalog.all.map { ($0.id, SongDetails($0)) }
    )

    var body: some View {
        List {
            Section {
                ForEach(Array(SongCatalog.all.enumerated()), id: \.element.id) { index, song in
                    row(for: song, index: index)
                }
            } footer: {
                Text("Tap a song to hear it. Harder songs ask for a note on every beat.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Songs")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { playBar }
        .onAppear { preview.play(appState.selectedSong) }
        .onDisappear { preview.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { preview.stop() }
        }
    }

    // MARK: - Rows

    private func row(for song: Song, index: Int) -> some View {
        let isSelected = song.id == appState.selectedSongID
        let isAvailable = AudioEngine.hasAudio(for: song)
        let details = Self.details[song.id] ?? SongDetails(song)
        let best = appState.bestScore(for: song)

        return Button {
            appState.selectedSongID = song.id
            preview.play(song)
        } label: {
            SongRow(
                song: song,
                details: details,
                best: best,
                artwork: SongArtwork.palette(at: index),
                isSelected: isSelected
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.4)
        .listRowBackground(isSelected ? Theme.surfaceSelected : Theme.surface)
        .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(song, details: details, best: best, isAvailable: isAvailable))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "" : "Selects this song and plays a preview")
    }

    private func accessibilityLabel(_ song: Song, details: SongDetails, best: Int, isAvailable: Bool) -> String {
        var parts = [
            song.title,
            "by \(song.artist)",
            details.difficulty.label,
            "\(Int(song.bpm)) beats per minute",
            Duration.seconds(song.duration).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
        ]
        if best > 0 { parts.append("best score \(best.formatted())") }
        if !isAvailable { parts.append("unavailable") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Play bar

    private var playBar: some View {
        let song = appState.selectedSong
        return VStack(spacing: 0) {
            Button {
                preview.stop()
                appState.play(song)
            } label: {
                Label("Play \(song.title)", systemImage: "play.fill")
                    .lineLimit(1)
            }
            .buttonStyle(.primaryAction)
            .disabled(!AudioEngine.hasAudio(for: song))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Row

private struct SongRow: View {

    let song: Song
    let details: SongDetails
    let best: Int
    let artwork: SongArtwork
    let isSelected: Bool

    @ScaledMetric(relativeTo: .headline) private var artworkSize: CGFloat = 56

    var body: some View {
        HStack(spacing: 14) {
            artwork
                .frame(width: artworkSize, height: artworkSize)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.textPrimary, lineWidth: 2)
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(Int(song.bpm)) BPM")
                    Text("·")
                    Text(Duration.seconds(song.duration).formatted(.time(pattern: .minuteSecond)))
                }
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                DifficultyBadge(difficulty: details.difficulty)

                if best > 0 {
                    Text(best, format: .number)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("New")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .contentShape(Rectangle())
        .frame(minHeight: 60)
    }
}

// MARK: - Pieces

/// Chart-derived facts, computed once per song.
struct SongDetails {
    let difficulty: Difficulty
    let noteCount: Int

    init(_ song: Song) {
        noteCount = song.makeChart().notes.count
        difficulty = song.difficulty
    }
}

struct DifficultyBadge: View {

    let difficulty: Difficulty

    var body: some View {
        Text(difficulty.label)
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .kerning(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.16), in: Capsule())
    }

    /// Colour backs up the word, never replaces it.
    private var tint: Color {
        switch difficulty {
        case .easy: return BeamColor.cyan.color
        case .normal: return BeamColor.amber.color
        case .hard: return BeamColor.magenta.color
        }
    }
}

/// Stand-in cover art drawn from the beam palette, so the list has something to scan by
/// without shipping (or licensing) images.
struct SongArtwork: View {

    let colors: [Color]

    static func palette(at index: Int) -> SongArtwork {
        let beams = BeamColor.allCases
        let first = beams[index % beams.count]
        let second = beams[(index + 1) % beams.count]
        return SongArtwork(colors: [first.color, second.color])
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Image(systemName: "waveform")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.background.opacity(0.75))
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        SongSelectView(appState: AppState(defaults: .previewDefaults))
    }
    .fontDesign(.rounded)
    .preferredColorScheme(.dark)
}
