import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: SharedSettings

    var body: some View {
        NavigationStack {
            if settings.onboardingCompleted {
                SettingsView()
            } else {
                OnboardingView()
            }
        }
    }
}
