import Foundation
import Combine

final class SharedSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var apiKey: String {
        didSet { defaults.set(apiKey, forKey: AppGroupConstants.Keys.apiKey) }
    }

    @Published var defaultMode: String {
        didSet { defaults.set(defaultMode, forKey: AppGroupConstants.Keys.defaultMode) }
    }

    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: AppGroupConstants.Keys.onboardingCompleted) }
    }

    init() {
        let store = AppGroupConstants.sharedDefaults ?? .standard
        self.defaults = store
        self.apiKey = store.string(forKey: AppGroupConstants.Keys.apiKey) ?? ""
        self.defaultMode = store.string(forKey: AppGroupConstants.Keys.defaultMode) ?? KeyboardMode.enCorrection.rawValue
        self.onboardingCompleted = store.bool(forKey: AppGroupConstants.Keys.onboardingCompleted)
    }
}
