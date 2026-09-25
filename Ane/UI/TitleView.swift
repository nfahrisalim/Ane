import SwiftUI

struct TitleView: View {

    let appState: AppState

    @State private var emblemAngle: Double = 0

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            PrismEmblem(angle: emblemAngle)
                .frame(width: 190, height: 190)
                .accessibilityHidden(true)

            Spacer().frame(height: 44)

            Text("PRISM GROOVE")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .kerning(2)
                .foregroundStyle(Theme.textPrimary)

            Text("Bend light into colour. Colour into song.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 10)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                appState.play()
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Theme.textPrimary, in: Capsule())
            }
            .accessibilityHint("Starts a two minute song")

            if appState.bestScore > 0 {
                Text("Best \(appState.bestScore.formatted())")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 18)
            }

            Spacer().frame(height: 28)
        }
        .padding(.horizontal, 32)
        .task {
            guard !reduceMotion else { return }
            // A slow idle turn, so the emblem reads as the thing you are about to rotate.
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) {
                emblemAngle = 360
            }
        }
    }
}

/// Static rendering of the playfield: prism, three beams, four targets.
private struct PrismEmblem: View {

    let angle: Double

    private let layout = Layout.standard

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let centre = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let orbit = side * 0.40

            ZStack {
                ForEach(Array(layout.targetColors.enumerated()), id: \.offset) { index, color in
                    Circle()
                        .strokeBorder(color.color, lineWidth: 1.5)
                        .frame(width: side * 0.13, height: side * 0.13)
                        .position(
                            x: centre.x + cos(layout.targetAngles[index]) * orbit,
                            y: centre.y - sin(layout.targetAngles[index]) * orbit
                        )
                        .opacity(0.45)
                }

                ZStack {
                    ForEach(BeamColor.allCases, id: \.rawValue) { beam in
                        Capsule()
                            .fill(beam.color)
                            .frame(width: orbit, height: 2.5)
                            .offset(x: orbit / 2)
                            .rotationEffect(.radians(-beam.beamOffset))
                            .blendMode(.plusLighter)
                    }

                    Triangle()
                        .stroke(Theme.textPrimary, lineWidth: 2)
                        .frame(width: side * 0.17, height: side * 0.17)
                }
                .rotationEffect(.degrees(-angle))
                .position(centre)
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Fresh install") {
    TitleView(appState: AppState(defaults: UserDefaults(suiteName: "PrismGroove.freshPreview") ?? .standard))
        .background(Theme.background)
}

#Preview("With a best score") {
    TitleView(appState: AppState(defaults: .previewDefaults))
        .background(Theme.background)
}
