import Foundation
import Combine

enum AutoCorrectionLevel: String, CaseIterable, Identifiable {
    case off = "off"
    case conservative = "conservative"
    case aggressive = "aggressive"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .conservative: return "Standard"
        case .aggressive: return "Aggressive"
        }
    }
}

final class SharedSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var apiKey: String {
        didSet { defaults.set(apiKey, forKey: AppGroupConstants.Keys.apiKey) }
    }

    @Published var defaultMode: String {
        didSet { defaults.set(defaultMode, forKey: AppGroupConstants.Keys.defaultMode) }
    }

    @Published var autoCorrectionLevel: String {
        didSet { defaults.set(autoCorrectionLevel, forKey: AppGroupConstants.Keys.autoCorrectionLevel) }
    }

    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: AppGroupConstants.Keys.onboardingCompleted) }
    }

    init() {
        let store = AppGroupConstants.sharedDefaults ?? .standard
        self.defaults = store
        self.apiKey = store.string(forKey: AppGroupConstants.Keys.apiKey) ?? ""
        self.defaultMode = store.string(forKey: AppGroupConstants.Keys.defaultMode) ?? KeyboardMode.enCorrection.rawValue
        self.autoCorrectionLevel = store.string(forKey: AppGroupConstants.Keys.autoCorrectionLevel) ?? AutoCorrectionLevel.conservative.rawValue
        self.onboardingCompleted = store.bool(forKey: AppGroupConstants.Keys.onboardingCompleted)
    }
}
