import SwiftUI

@main
struct LingoKeyApp: App {
    @StateObject private var settings = SharedSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
    }
}
