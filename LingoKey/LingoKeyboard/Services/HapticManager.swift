import UIKit

enum HapticManager {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)

    /// Light tap for character keys.
    static func keyTap() {
        lightGenerator.impactOccurred(intensity: 0.15)
    }

    /// Rigid tap for special keys (backspace, space, return, shift).
    static func specialKeyTap() {
        rigidGenerator.impactOccurred(intensity: 0.25)
    }

    /// Pre-warm generators for lower latency on first tap.
    static func prepare() {
        lightGenerator.prepare()
        rigidGenerator.prepare()
    }
}
