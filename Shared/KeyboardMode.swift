import Foundation

enum KeyboardMode: String, CaseIterable, Identifiable {
    case enCorrection = "en_correction"
    case krCorrection = "kr_correction"
    case jpToEn = "jp_to_en"
    case jpToKr = "jp_to_kr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .enCorrection: return "EN"
        case .krCorrection: return "KR"
        case .jpToEn:       return "J>E"
        case .jpToKr:       return "J>K"
        }
    }

    var description: String {
        switch self {
        case .enCorrection: return "English Correction"
        case .krCorrection: return "Korean Correction"
        case .jpToEn:       return "Japanese to English"
        case .jpToKr:       return "Japanese to Korean"
        }
    }

    var usesQwertyLayout: Bool {
        switch self {
        case .enCorrection, .jpToEn, .jpToKr: return true
        case .krCorrection: return false
        }
    }

    var isJapaneseInput: Bool {
        switch self {
        case .jpToEn, .jpToKr: return true
        default: return false
        }
    }
}
