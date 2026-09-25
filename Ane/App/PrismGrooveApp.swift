import SwiftUI

@main
struct PrismGrooveApp: App {

    /// Portrait lock lives in the build settings
    /// (INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone), so the playfield's fixed
    /// polar layout never has to survive a rotation.
    @State private var appState = AppState()
    @State private var haptics = Haptics()

    var body: some Scene {
        WindowGroup {
            RootView(appState: appState, haptics: haptics)
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct RootView: View {

    let appState: AppState
    let haptics: Haptics

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch appState.screen {
            case .title:
                TitleView(appState: appState)
                    .transition(.opacity)
            case .playing:
                GameView(appState: appState, haptics: haptics)
                    .transition(.opacity)
            case let .results(result):
                ResultsView(appState: appState, result: result)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: appState.screen)
    }
}

#Preview {
    RootView(appState: AppState(defaults: .previewDefaults), haptics: Haptics())
}
