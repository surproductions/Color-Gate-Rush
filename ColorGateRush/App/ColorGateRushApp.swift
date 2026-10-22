import SwiftUI

@main
struct ColorGateRushApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}

/// Switches between top-level screens and forwards lifecycle changes.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch model.screen {
            case .home:
                HomeView().transition(.opacity)
            case .game:
                GameView(model: model)
                    .id(model.gameToken)
                    .transition(.opacity)
            case .results:
                ResultsView().transition(.opacity.combined(with: .scale(scale: 0.96)))
            case .cosmetics:
                CosmeticsView().transition(.move(edge: .trailing).combined(with: .opacity))
            case .progress:
                ProgressScreen().transition(.move(edge: .trailing).combined(with: .opacity))
            case .settings:
                SettingsView().transition(.move(edge: .trailing).combined(with: .opacity))
            case .privacy:
                PrivacyPolicyView().transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .statusBarHidden(true)
        .onChange(of: scenePhase) { phase in
            model.scenePhaseChanged(phase)
        }
    }
}
