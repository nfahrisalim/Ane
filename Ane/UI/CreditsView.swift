import SwiftUI

/// Who made what, and under which terms. Shown from the title screen's info button.
///
/// Keep this in step with CREDITS.md: the jam asks for credits on the itch.io page, and
/// the music licences ask for them wherever the music is heard.
struct CreditsView: View {

    @Environment(\.dismiss) private var dismiss

    private struct MusicCredit: Identifiable {
        let id: String
        let tracks: String
        let artist: String
        let terms: String
        let url: URL?
    }

    private let music: [MusicCredit] = [
        MusicCredit(
            id: "mazarelli",
            tracks: "Galaxy Launch, Nebula Disco, Retro Orbit, Starlight Arpeggio, Hyperspace Finish",
            artist: "Mazarelli — Cosmic Synth Disco (AI-assisted)",
            terms: "Free for non-commercial projects",
            url: URL(string: "https://mazarelli.itch.io/cosmic-synth-disco-game-music-pack")
        ),
        MusicCredit(
            id: "gbproductions",
            tracks: "Solstice Party",
            artist: "gbproductions",
            terms: "Creative Commons, credit required",
            url: URL(string: "https://gbproductions.itch.io/solstice-party-free-jrpg-disco-funk-music-loop")
        ),
        MusicCredit(
            id: "procedural",
            tracks: "Prism Groove",
            artist: "Prism Groove team",
            terms: "Synthesised in code at launch",
            url: nil
        )
    ]

    private let team = [
        "Muhamad Ega Nugraha",
        "Muh. Naufal Fahri Salim"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Music") {
                    ForEach(music) { credit in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(credit.tracks)
                                .font(.headline)
                            Text(credit.artist)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                            Text(credit.terms)
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                            if let url = credit.url {
                                Link(destination: url) {
                                    Label("Source", systemImage: "arrow.up.right.square")
                                        .font(.footnote.weight(.semibold))
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }

                Section("Team") {
                    ForEach(team, id: \.self) { name in
                        Text(name)
                    }
                }

                Section {
                    Text("Made for Very Disco Game Jam 2026.3. Prism, beams and effects are drawn in code; type is SF Pro Rounded; icons are SF Symbols.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    CreditsView()
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
}
