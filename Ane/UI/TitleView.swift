import SwiftUI

struct TitleView: View {

    let appState: AppState

    @State private var emblemAngle: Double = 0
    @State private var showsCredits = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            PrismEmblem(angle: emblemAngle)
                .frame(width: 190, height: 190)
                .accessibilityHidden(true)

            Spacer().frame(height: 44)

            Text("PRISM GROOVE")
                .font(.largeTitle.weight(.heavy))
                .kerning(2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Prism Groove")

            Text("Bend light into colour. Colour into song.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 10)
                .multilineTextAlignment(.center)

            Spacer(minLength: 24)

            Button {
                appState.menuPath.append(.songs)
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            .buttonStyle(.primaryAction)
            .accessibilityHint("Choose a song to play")

            Text("\(SongCatalog.all.count) songs")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 14)

            Spacer().frame(height: 20)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsCredits = true
                } label: {
                    Label("Credits", systemImage: "info.circle")
                }
                .tint(Theme.textPrimary)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsCredits) {
            CreditsView()
        }
        .task(id: reduceMotion) {
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

#Preview {
    NavigationStack {
        TitleView(appState: AppState(defaults: .previewDefaults))
    }
    .fontDesign(.rounded)
    .preferredColorScheme(.dark)
}
