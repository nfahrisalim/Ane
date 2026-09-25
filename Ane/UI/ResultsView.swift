import SwiftUI

struct ResultsView: View {

    let appState: AppState
    let result: RunResult

    @State private var isNewBest = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(isNewBest ? "NEW BEST" : "SCORE")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .kerning(2.5)
                .foregroundStyle(isNewBest ? BeamColor.amber.color : Theme.textSecondary)

            Text(result.score, format: .number)
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 4)

            Text("\(Int((result.accuracy * 100).rounded()))% accuracy")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
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
            .padding(.top, 30)

            Spacer()

            Button {
                appState.play()
            } label: {
                Label("Play Again", systemImage: "arrow.clockwise")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.textPrimary, in: Capsule())
            }

            Button {
                appState.returnToTitle()
            } label: {
                Text("Title")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .padding(.top, 2)

            Text("Best \(appState.bestScore.formatted())")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 6)

            Spacer().frame(height: 22)
        }
        .padding(.horizontal, 30)
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
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value, format: .number)
                .font(.system(size: 17, weight: .bold, design: .rounded))
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
    ResultsView(appState: AppState(defaults: .previewDefaults), result: .preview)
        .background(Theme.background)
}

#Preview("Rough run") {
    ResultsView(appState: AppState(defaults: .previewDefaults), result: .previewRough)
        .background(Theme.background)
}
