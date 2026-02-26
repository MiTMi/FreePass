import SwiftUI

/// Routes between onboarding, unlock, and main vault views.
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isFirstLaunch {
                OnboardingView()
            } else if !appState.isUnlocked {
                UnlockView()
            } else {
                VaultListView()
            }
        }
        .frame(minWidth: 800, minHeight: 550)
        .background(Color.fpBackground)
        .animation(.easeInOut(duration: 0.4), value: appState.isUnlocked)
        .animation(.easeInOut(duration: 0.4), value: appState.isFirstLaunch)
    }
}
