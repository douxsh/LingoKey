import Foundation

/// Hangul syllable composition state machine using Unicode composition formula:
/// Unicode = (choseong × 21 + jungseong) × 28 + jongseong + 0xAC00
final class HangulComposer {
    struct Result {
        var commitText: String?
        var deleteCount: Int?
    }

    private enum State {
        case empty
        case choseong(Character)                          // 초성 only
        case choseongJungseong(Character, Character)      // 초성 + 중성
        case complete(Character, Character, Character)     // 초성 + 중성 + 종성
    }

    private var state: State = .empty

    func reset() {
        state = .empty
    }

    // MARK: - Process input

    func process(_ key: String) -> Result {
        guard let jamo = DubeolsikKeyMap.jamo(for: key) else {
            // Not a Korean key – commit current and pass through
            let commit = finalize()
            let prefix = commit ?? ""
            return Result(commitText: prefix + key, deleteCount: commit != nil ? 1 : nil)
        }

        let isConsonant = DubeolsikKeyMap.isConsonant(jamo)
        let isVowel = DubeolsikKeyMap.isVowel(jamo)

        switch state {
        case .empty:
            if isConsonant {
                state = .choseong(jamo)
                return Result(commitText: String(jamo), deleteCount: nil)
            } else {
                // Lone vowel
                return Result(commitText: String(jamo), deleteCount: nil)
            }

        case .choseong(let cho):
            if isVowel {
                // cho + vowel → syllable
                state = .choseongJungseong(cho, jamo)
                let syllable = composeSyllable(cho: cho, jung: jamo, jong: nil)
                return Result(commitText: syllable, deleteCount: 1)
            } else {
                // Another consonant → commit previous, start new
                state = .choseong(jamo)
                return Result(commitText: String(jamo), deleteCount: nil)
            }

        case .choseongJungseong(let cho, let jung):
            if isVowel {
                // Try compound vowel
                if let compound = DubeolsikKeyMap.compoundVowel(first: jung, second: jamo) {
                    state = .choseongJungseong(cho, compound)
                    let syllable = composeSyllable(cho: cho, jung: compound, jong: nil)
                    return Result(commitText: syllable, deleteCount: 1)
                } else {
                    // Can't combine – commit current, start fresh vowel
                    state = .empty
                    let commit = composeSyllable(cho: cho, jung: jung, jong: nil)
                    // Actually, we need to handle this differently
                    // Commit the current syllable and output the new vowel separately
                    return Result(commitText: commit.map { _ in String(jamo) } ?? String(jamo), deleteCount: nil)
                }
            } else {
                // Consonant as jongseong
                if DubeolsikKeyMap.jongseongIndex(of: jamo) != nil {
                    state = .complete(cho, jung, jamo)
                    let syllable = composeSyllable(cho: cho, jung: jung, jong: jamo)
                    return Result(commitText: syllable, deleteCount: 1)
                } else {
                    // Can't be jongseong → commit syllable, start new choseong
                    state = .choseong(jamo)
                    return Result(commitText: String(jamo), deleteCount: nil)
                }
            }

        case .complete(let cho, let jung, let jong):
            if isVowel {
                // The jongseong moves to become choseong of new syllable
                // First, check if jong is compound – if so, split it
                if let (first, second) = DubeolsikKeyMap.splitCompoundJong(jong) {
                    // Recompose previous syllable without the second part of compound
                    let prevSyllable = composeSyllable(cho: cho, jung: jung, jong: first)
                    state = .choseongJungseong(second, jamo)
                    let newSyllable = composeSyllable(cho: second, jung: jamo, jong: nil)
                    return Result(commitText: (prevSyllable ?? "") + (newSyllable ?? ""), deleteCount: 1)
                } else {
                    // Simple jongseong → move to new syllable's choseong
                    let prevSyllable = composeSyllable(cho: cho, jung: jung, jong: nil)
                    state = .choseongJungseong(jong, jamo)
                    let newSyllable = composeSyllable(cho: jong, jung: jamo, jong: nil)
                    return Result(commitText: (prevSyllable ?? "") + (newSyllable ?? ""), deleteCount: 1)
                }
            } else {
                // Try compound jongseong
                if let compound = DubeolsikKeyMap.compoundJong(first: jong, second: jamo),
                   DubeolsikKeyMap.jongseongIndex(of: compound) != nil {
                    state = .complete(cho, jung, compound)
                    let syllable = composeSyllable(cho: cho, jung: jung, jong: compound)
                    return Result(commitText: syllable, deleteCount: 1)
                } else {
                    // Can't compound → commit current, start new choseong
                    state = .choseong(jamo)
                    return Result(commitText: String(jamo), deleteCount: nil)
                }
            }
        }
    }

    // MARK: - Backspace

    func backspace() -> Result {
        switch state {
        case .empty:
            return Result(commitText: nil, deleteCount: 1)

        case .choseong:
            state = .empty
            return Result(commitText: nil, deleteCount: 1)

        case .choseongJungseong(let cho, let jung):
            // Check if jung is compound vowel
            if let parts = DubeolsikKeyMap.compoundVowels.first(where: { $0.2 == jung }) {
                state = .choseongJungseong(cho, parts.0)
                let syllable = composeSyllable(cho: cho, jung: parts.0, jong: nil)
                return Result(commitText: syllable, deleteCount: 1)
            }
            // Revert to choseong only
            state = .choseong(cho)
            return Result(commitText: String(cho), deleteCount: 1)

        case .complete(let cho, let jung, let jong):
            // Check if jong is compound
            if let (first, _) = DubeolsikKeyMap.splitCompoundJong(jong) {
                state = .complete(cho, jung, first)
                let syllable = composeSyllable(cho: cho, jung: jung, jong: first)
                return Result(commitText: syllable, deleteCount: 1)
            }
            // Remove jongseong
            state = .choseongJungseong(cho, jung)
            let syllable = composeSyllable(cho: cho, jung: jung, jong: nil)
            return Result(commitText: syllable, deleteCount: 1)
        }
    }

    // MARK: - Finalize

    @discardableResult
    func finalize() -> String? {
        let result: String?
        switch state {
        case .empty:
            result = nil
        case .choseong:
            result = nil // Already displayed
        case .choseongJungseong:
            result = nil // Already displayed
        case .complete:
            result = nil // Already displayed
        }
        state = .empty
        return result
    }

    // MARK: - Compose

    private func composeSyllable(cho: Character, jung: Character, jong: Character?) -> String? {
        guard let choIdx = DubeolsikKeyMap.choseongIndex(of: cho),
              let jungIdx = DubeolsikKeyMap.jungseongIndex(of: jung) else {
            return nil
        }

        let jongIdx = jong.flatMap { DubeolsikKeyMap.jongseongIndex(of: $0) } ?? 0
        let code = (choIdx * 21 + jungIdx) * 28 + jongIdx + 0xAC00

        guard let scalar = Unicode.Scalar(code) else { return nil }
        return String(Character(scalar))
    }
}
