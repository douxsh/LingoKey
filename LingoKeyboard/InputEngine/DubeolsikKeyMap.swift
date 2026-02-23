import Foundation

/// 2벌식 (Dubeolsik) standard Korean keyboard mapping: QWERTY key → Jamo
enum DubeolsikKeyMap {
    // MARK: - Consonants (자음)

    /// Maps a QWERTY key to its corresponding Korean jamo character
    static func jamo(for key: String) -> Character? {
        return keyMap[key.lowercased()] ?? shiftKeyMap[key]
    }

    static func isConsonant(_ char: Character) -> Bool {
        return consonants.contains(char)
    }

    static func isVowel(_ char: Character) -> Bool {
        return vowels.contains(char)
    }

    // Regular key mapping (lowercase)
    private static let keyMap: [String: Character] = [
        // Consonants
        "q": "\u{3142}", // ㅂ
        "w": "\u{3148}", // ㅈ
        "e": "\u{3137}", // ㄷ
        "r": "\u{3131}", // ㄱ
        "t": "\u{3145}", // ㅅ
        "a": "\u{3141}", // ㅁ
        "s": "\u{3134}", // ㄴ
        "d": "\u{3147}", // ㅇ
        "f": "\u{3139}", // ㄹ
        "g": "\u{314E}", // ㅎ
        "z": "\u{314B}", // ㅋ
        "x": "\u{314C}", // ㅌ
        "c": "\u{314A}", // ㅊ
        "v": "\u{314D}", // ㅍ
        // Vowels
        "y": "\u{315B}", // ㅛ
        "u": "\u{3155}", // ㅕ
        "i": "\u{3151}", // ㅑ
        "o": "\u{3150}", // ㅐ
        "p": "\u{3154}", // ㅔ
        "h": "\u{3157}", // ㅗ
        "j": "\u{3153}", // ㅓ
        "k": "\u{314F}", // ㅏ
        "l": "\u{3163}", // ㅣ
        "b": "\u{3160}", // ㅠ
        "n": "\u{315C}", // ㅜ
        "m": "\u{3161}", // ㅡ
    ]

    // Shift key mapping (uppercase / doubled consonants)
    private static let shiftKeyMap: [String: Character] = [
        "Q": "\u{3143}", // ㅃ
        "W": "\u{3149}", // ㅉ
        "E": "\u{3138}", // ㄸ
        "R": "\u{3132}", // ㄲ
        "T": "\u{3146}", // ㅆ
        "O": "\u{3152}", // ㅒ
        "P": "\u{3156}", // ㅖ
    ]

    // All consonant jamo
    private static let consonants: Set<Character> = [
        "\u{3131}", "\u{3132}", "\u{3134}", "\u{3137}", "\u{3138}",
        "\u{3139}", "\u{3141}", "\u{3142}", "\u{3143}", "\u{3145}",
        "\u{3146}", "\u{3147}", "\u{3148}", "\u{3149}", "\u{314A}",
        "\u{314B}", "\u{314C}", "\u{314D}", "\u{314E}",
    ]

    // All vowel jamo
    private static let vowels: Set<Character> = [
        "\u{314F}", "\u{3150}", "\u{3151}", "\u{3152}", "\u{3153}",
        "\u{3154}", "\u{3155}", "\u{3156}", "\u{3157}", "\u{3158}",
        "\u{3159}", "\u{315A}", "\u{315B}", "\u{315C}", "\u{315D}",
        "\u{315E}", "\u{315F}", "\u{3160}", "\u{3161}", "\u{3162}",
        "\u{3163}",
    ]

    // MARK: - Choseong / Jungseong / Jongseong indices

    /// Initial consonant (초성) index table
    static let choseongList: [Character] = [
        "\u{3131}", "\u{3132}", "\u{3134}", "\u{3137}", "\u{3138}",
        "\u{3139}", "\u{3141}", "\u{3142}", "\u{3143}", "\u{3145}",
        "\u{3146}", "\u{3147}", "\u{3148}", "\u{3149}", "\u{314A}",
        "\u{314B}", "\u{314C}", "\u{314D}", "\u{314E}",
    ]

    /// Medial vowel (중성) index table
    static let jungseongList: [Character] = [
        "\u{314F}", "\u{3150}", "\u{3151}", "\u{3152}", "\u{3153}",
        "\u{3154}", "\u{3155}", "\u{3156}", "\u{3157}", "\u{3158}",
        "\u{3159}", "\u{315A}", "\u{315B}", "\u{315C}", "\u{315D}",
        "\u{315E}", "\u{315F}", "\u{3160}", "\u{3161}", "\u{3162}",
        "\u{3163}",
    ]

    /// Final consonant (종성) index table (0 = no final)
    static let jongseongList: [Character?] = [
        nil,         "\u{3131}", "\u{3132}", "\u{3133}", "\u{3134}",
        "\u{3135}", "\u{3136}", "\u{3137}", "\u{3139}", "\u{313A}",
        "\u{313B}", "\u{313C}", "\u{313D}", "\u{313E}", "\u{313F}",
        "\u{3140}", "\u{3141}", "\u{3142}", "\u{3144}", "\u{3145}",
        "\u{3146}", "\u{3147}", "\u{3148}", "\u{314A}", "\u{314B}",
        "\u{314C}", "\u{314D}", "\u{314E}",
    ]

    /// Compound vowel combinations: (vowel1, vowel2) → compound vowel
    static let compoundVowels: [(Character, Character, Character)] = [
        ("\u{3157}", "\u{314F}", "\u{3158}"), // ㅗ + ㅏ = ㅘ
        ("\u{3157}", "\u{3150}", "\u{3159}"), // ㅗ + ㅐ = ㅙ
        ("\u{3157}", "\u{3163}", "\u{315A}"), // ㅗ + ㅣ = ㅚ
        ("\u{315C}", "\u{3153}", "\u{315D}"), // ㅜ + ㅓ = ㅝ
        ("\u{315C}", "\u{3154}", "\u{315E}"), // ㅜ + ㅔ = ㅞ
        ("\u{315C}", "\u{3163}", "\u{315F}"), // ㅜ + ㅣ = ㅟ
        ("\u{3161}", "\u{3163}", "\u{3162}"), // ㅡ + ㅣ = ㅢ
    ]

    /// Compound jongseong combinations: (jong1, jong2) → compound jongseong
    static let compoundJongseong: [(Character, Character, Character)] = [
        ("\u{3131}", "\u{3145}", "\u{3133}"), // ㄱ + ㅅ = ㄳ
        ("\u{3134}", "\u{3148}", "\u{3135}"), // ㄴ + ㅈ = ㄵ
        ("\u{3134}", "\u{314E}", "\u{3136}"), // ㄴ + ㅎ = ㄶ
        ("\u{3139}", "\u{3131}", "\u{313A}"), // ㄹ + ㄱ = ㄺ
        ("\u{3139}", "\u{3141}", "\u{313B}"), // ㄹ + ㅁ = ㄻ
        ("\u{3139}", "\u{3142}", "\u{313C}"), // ㄹ + ㅂ = ㄼ
        ("\u{3139}", "\u{3145}", "\u{313D}"), // ㄹ + ㅅ = ㄽ
        ("\u{3139}", "\u{314C}", "\u{313E}"), // ㄹ + ㅌ = ㄾ
        ("\u{3139}", "\u{314D}", "\u{313F}"), // ㄹ + ㅍ = ㄿ
        ("\u{3139}", "\u{314E}", "\u{3140}"), // ㄹ + ㅎ = ㅀ
        ("\u{3142}", "\u{3145}", "\u{3144}"), // ㅂ + ㅅ = ㅄ
    ]

    static func choseongIndex(of char: Character) -> Int? {
        choseongList.firstIndex(of: char)
    }

    static func jungseongIndex(of char: Character) -> Int? {
        jungseongList.firstIndex(of: char)
    }

    static func jongseongIndex(of char: Character) -> Int? {
        for (i, c) in jongseongList.enumerated() {
            if c == char { return i }
        }
        return nil
    }

    static func compoundVowel(first: Character, second: Character) -> Character? {
        compoundVowels.first { $0.0 == first && $0.1 == second }?.2
    }

    static func compoundJong(first: Character, second: Character) -> Character? {
        compoundJongseong.first { $0.0 == first && $0.1 == second }?.2
    }

    /// Split a compound jongseong into its two component jamo
    static func splitCompoundJong(_ compound: Character) -> (Character, Character)? {
        compoundJongseong.first { $0.2 == compound }.map { ($0.0, $0.1) }
    }
}
