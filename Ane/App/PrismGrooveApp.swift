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
                // One typeface voice for the whole app. Every size below is a text style,
                // so the menus follow the reader's Dynamic Type setting.
                .fontDesign(.rounded)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {

    @Bindable var appState: AppState
    let haptics: Haptics

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch appState.screen {
            case .menu:
                NavigationStack(path: $appState.menuPath) {
                    TitleView(appState: appState)
                        .navigationDestination(for: AppState.MenuRoute.self) { route in
                            switch route {
                            case .songs:
                                SongSelectView(appState: appState)
                            }
                        }
                }
                .statusBarHidden(false)
                .transition(.opacity)

            case let .playing(song, run):
                GameView(appState: appState, haptics: haptics, song: song)
                    .id(run)
                    .transition(.opacity)
                    // The playfield is edge to edge; system chrome only gets in the way.
                    .statusBarHidden()
                    .persistentSystemOverlays(.hidden)

            case let .results(result, song):
                ResultsView(appState: appState, result: result, song: song)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: appState.screen)
    }
}

#Preview {
    RootView(appState: AppState(defaults: .previewDefaults), haptics: Haptics())
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
}
