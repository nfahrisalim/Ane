import SwiftUI

struct ResultsView: View {

    let appState: AppState
    let result: RunResult
    let song: Song

    @State private var isNewBest = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(song.title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 36)
                .accessibilityElement(children: .combine)

                Text(isNewBest ? "NEW BEST" : "SCORE")
                    .font(.caption.weight(.heavy))
                    .kerning(2.5)
                    .foregroundStyle(isNewBest ? BeamColor.amber.color : Theme.textSecondary)
                    .padding(.top, 36)

                Text(result.score, format: .number)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .scaleEffect(1.3)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .accessibilityLabel(isNewBest ? "New best score \(result.score)" : "Score \(result.score)")

                Text("\(Int((result.accuracy * 100).rounded()))% accuracy")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 6)

                VStack(spacing: 0) {
                    row("Perfect", result.perfectCount, tint: BeamColor.cyan.color)
                    divider
                    row("Good", result.goodCount, tint: BeamColor.amber.color)
                    divider
                    row("Miss", result.missCount, tint: BeamColor.magenta.color)
                    divider
                    row("Max combo", result.maxCombo, tint: Theme.textPrimary)
                }
                .padding(.vertical, 4)
                .glassPanel(cornerRadius: 22)
                .padding(.top, 28)

                Text("Best \(appState.bestScore(for: song).formatted())")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    appState.play(song)
                } label: {
                    Label("Play Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.primaryAction)

                Button {
                    appState.returnToSongs()
                } label: {
                    Label("Choose Song", systemImage: "music.note.list")
                }
                .buttonStyle(.secondaryAction)
            }
            .padding(.horizontal, 30)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: 520)
        }
        .task {
            isNewBest = appState.lastRunWasBest
        }
        .sensoryFeedback(.success, trigger: isNewBest) { _, current in current }
    }

    private func row(_ label: String, _ value: Int, tint: Color) -> some View {
        HStack {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value, format: .number)
                .font(.body.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.textPrimary.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 18)
    }
}

#Preview("Strong run") {
    ResultsView(appState: AppState(defaults: .previewDefaults), result: .preview, song: SongCatalog.galaxyLaunch)
        .background(Theme.background)
        .fontDesign(.rounded)
}

#Preview("Rough run") {
    ResultsView(appState: AppState(defaults: .previewDefaults), result: .previewRough, song: SongCatalog.solsticeParty)
        .background(Theme.background)
        .fontDesign(.rounded)
}
