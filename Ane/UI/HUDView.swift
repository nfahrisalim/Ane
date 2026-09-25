import SwiftUI

struct HUDView: View {

    let controller: GameController
    let appState: AppState

    @State private var showHint = false

    var body: some View {
        ZStack {
            judgmentFlash
            VStack(spacing: 0) {
                topBar
                Spacer()
                if showHint { hint }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 30)

            if controller.isPaused {
                pauseOverlay
            }
        }
        // The HUD shares the screen with the playfield; past this size it would cover
        // targets the player has to see.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .task {
            guard !appState.hasSeenHint else { return }
            showHint = true
            appState.markHintSeen()
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.6)) { showHint = false }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(controller.score, format: .number)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: controller.score)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityLabel("Score \(controller.score)")

                // Below 4 the multiplier has not moved yet, so the badge would be noise.
                if controller.combo >= 4 {
                    Text("×\(controller.multiplier)")
                        .font(.subheadline.weight(.heavy))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Theme.textPrimary.opacity(0.16), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Multiplier \(controller.multiplier) times")
                }

                Spacer(minLength: 8)

                Text(controller.song.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                Button {
                    controller.togglePause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        // 44 pt: the HIG minimum, and this is hit mid-song with a thumb
                        // that is busy rotating the prism.
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .glassPanel(cornerRadius: 22)
                .accessibilityLabel("Pause")
            }

            ProgressView(value: controller.progress)
                .progressViewStyle(.linear)
                .tint(Theme.textPrimary.opacity(0.7))
                .scaleEffect(x: 1, y: 0.6, anchor: .center)
                .accessibilityLabel("Song progress")
                .accessibilityValue("\(Int((controller.progress * 100).rounded())) percent")
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .glassPanel(cornerRadius: 27)
        .animation(.snappy(duration: 0.25), value: controller.combo >= 4)
    }

    // MARK: - Judgment

    /// Sits directly below the prism: with targets at 45, 135, 225 and 315 degrees, the
    /// vertical axis is the one place text cannot cover something the player is aiming at.
    private var judgmentFlash: some View {
        ZStack {
            if let flash = controller.flash {
                Text(flash.judgment == .perfect ? "PERFECT" : "GOOD")
                    .font(.title3.weight(.heavy))
                    .kerning(1.5)
                    .foregroundStyle(flash.color.color)
                    .shadow(color: flash.color.color.opacity(0.6), radius: 12)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .id(flash.id)
            }
        }
        .offset(y: 86)
        .animation(.spring(response: 0.26, dampingFraction: 0.7), value: controller.flash)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Hint

    private var hint: some View {
        Label("Drag around the prism to rotate. Match the colour on the beat.", systemImage: "hand.draw")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassPanel(cornerRadius: 16)
            .transition(.opacity)
    }

    // MARK: - Pause

    private var pauseOverlay: some View {
        ZStack {
            Theme.background.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Paused")
                        .font(.title.weight(.heavy))
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(controller.song.title)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.bottom, 8)

                Button {
                    controller.resume()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(.primaryAction)

                Button {
                    controller.stop()
                    appState.play(controller.song)
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.secondaryAction)

                Button {
                    controller.stop()
                    appState.returnToSongs()
                } label: {
                    Text("Quit to Songs")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .glassPanel(cornerRadius: 28)
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
        // Resume is the expected answer; make it the one VoiceOver lands on and the one a
        // hardware keyboard's Escape toggles.
        .accessibilityAction(.escape) { controller.resume() }
    }
}
