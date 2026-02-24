import Foundation

enum AppGroupConstants {
    static let suiteName = "group.com.lingokey.shared"

    enum Keys {
        static let apiKey = "openai_api_key"
        static let defaultMode = "default_keyboard_mode"
        static let autoCorrectionLevel = "auto_correction_level"
        static let onboardingCompleted = "onboarding_completed"
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}
