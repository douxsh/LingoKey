import Foundation

struct Suggestion: Identifiable, Equatable {
    enum Kind: Equatable {
        case conversion
        case translation
    }

    let id = UUID()
    let text: String
    let originalText: String
    var kind: Kind = .translation
}
