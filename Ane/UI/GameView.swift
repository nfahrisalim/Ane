import SwiftUI
import SpriteKit
import AVFoundation

struct GameView: View {

    let appState: AppState
    let haptics: Haptics
    let song: Song

    @Environment(\.scenePhase) private var scenePhase
    @State private var controller: GameController?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.background.ignoresSafeArea()

                if let controller {
                    SpriteView(
                        scene: controller.scene,
                        preferredFramesPerSecond: 120,
                        options: [.ignoresSiblingOrder]
                    )
                    .ignoresSafeArea()

                    HUDView(controller: controller, appState: appState)
                } else {
                    ProgressView()
                        .tint(Theme.textPrimary)
                }
            }
            .task(id: proxy.size) {
                await startIfNeeded(size: proxy.size)
            }
        }
        // Losing audio means losing the clock, so the run must not keep scoring.
        .task {
            let interruptions = NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification
            )
            for await notification in interruptions {
                let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                if raw == AVAudioSession.InterruptionType.began.rawValue {
                    controller?.pause()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { controller?.pause() }
        }
        .onDisappear {
            controller?.stop()
        }
    }

    private func startIfNeeded(size: CGSize) async {
        guard controller == nil, size.width > 0, size.height > 0 else { return }

        // Each song carries its own fixed seed. A random chart per run would make the
        // stored best score meaningless to compare against, and would rob the player of
        // ever learning the track.
        let controller = GameController(
            song: song,
            size: size,
            haptics: haptics
        )
        self.controller = controller

        let played = controller.song
        await controller.start { result in
            appState.finish(result, song: played)
        }
    }
}
