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
        HStack(alignment: .center, spacing: 12) {
            Text(controller.score, format: .number)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: controller.score)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityLabel("Score")

            // Below 4 the multiplier has not moved yet, so the badge would be noise.
            if controller.combo >= 4 {
                Text("×\(controller.multiplier)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.textPrimary.opacity(0.16), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Multiplier \(controller.multiplier) times")
            }

            Spacer()

            Button {
                controller.togglePause()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 38, height: 38)
            }
            .glassPanel(cornerRadius: 19)
            .accessibilityLabel("Pause")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
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
        Text("Rotate to match the colour. Hit on the beat.")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
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

            VStack(spacing: 18) {
                Text("Paused")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                Button {
                    controller.resume()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.textPrimary, in: Capsule())
                }

                Button {
                    controller.stop()
                    appState.returnToTitle()
                } label: {
                    Text("Quit to title")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(26)
            .frame(maxWidth: 320)
            .glassPanel(cornerRadius: 26)
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }
}
