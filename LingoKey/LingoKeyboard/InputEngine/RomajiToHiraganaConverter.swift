import Foundation

/// Romaji to Hiragana converter using a greedy buffer-based approach
final class RomajiToHiraganaConverter {
    struct Result {
        var converted: Bool
    }

    private var romajiBuffer: String = ""
    private var hiraganaResult: String = ""

    var displayText: String {
        hiraganaResult + romajiToPartialHiragana(romajiBuffer)
    }

    func reset() {
        romajiBuffer = ""
        hiraganaResult = ""
    }

    func process(_ char: String) -> Result {
        let c = char.lowercased()
        romajiBuffer += c

        // Try to convert buffer greedily
        let converted = tryConvert()
        return Result(converted: converted)
    }

    func backspace() {
        if !romajiBuffer.isEmpty {
            romajiBuffer.removeLast()
        } else if !hiraganaResult.isEmpty {
            hiraganaResult.removeLast()
        }
    }

    // MARK: - Private

    private func tryConvert() -> Bool {
        var didConvert = false

        while !romajiBuffer.isEmpty {
            // Handle double consonant (っ): nn→ん, or same consonant
            if romajiBuffer.count >= 2 {
                let first = romajiBuffer[romajiBuffer.startIndex]
                let second = romajiBuffer[romajiBuffer.index(after: romajiBuffer.startIndex)]

                // "nn" → ん
                if first == "n" && second == "n" {
                    hiraganaResult += "ん"
                    romajiBuffer.removeFirst(2)
                    didConvert = true
                    continue
                }

                // Double consonant → っ + keep second
                if first == second && first != "a" && first != "i" && first != "u" && first != "e" && first != "o" && first != "n" {
                    hiraganaResult += "っ"
                    romajiBuffer.removeFirst()
                    didConvert = true
                    continue
                }
            }

            // Try 3-char match first, then 2-char, then 1-char
            var matched = false

            for len in stride(from: min(romajiBuffer.count, 4), through: 1, by: -1) {
                let prefix = String(romajiBuffer.prefix(len))
                if let hiragana = romajiMap[prefix] {
                    hiraganaResult += hiragana
                    romajiBuffer.removeFirst(len)
                    matched = true
                    didConvert = true
                    break
                }
            }

            if !matched {
                // Handle "n" before non-vowel/non-y
                if romajiBuffer.count >= 2 && romajiBuffer.first == "n" {
                    let second = romajiBuffer[romajiBuffer.index(after: romajiBuffer.startIndex)]
                    let vowelsAndY: Set<Character> = ["a","i","u","e","o","y","n"]
                    if !vowelsAndY.contains(second) {
                        hiraganaResult += "ん"
                        romajiBuffer.removeFirst()
                        didConvert = true
                        continue
                    }
                }
                break // Can't convert more – wait for more input
            }
        }

        return didConvert
    }

    /// Show partial romaji as-is (can't convert yet)
    private func romajiToPartialHiragana(_ text: String) -> String {
        return text
    }

    // MARK: - Romaji → Hiragana Map

    private let romajiMap: [String: String] = [
        // Vowels
        "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
        // K-row
        "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
        // S-row
        "sa": "さ", "si": "し", "shi": "し", "su": "す", "se": "せ", "so": "そ",
        // T-row
        "ta": "た", "ti": "ち", "chi": "ち", "tu": "つ", "tsu": "つ", "te": "て", "to": "と",
        // N-row
        "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
        // H-row
        "ha": "は", "hi": "ひ", "hu": "ふ", "fu": "ふ", "he": "へ", "ho": "ほ",
        // M-row
        "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
        // Y-row
        "ya": "や", "yu": "ゆ", "yo": "よ",
        // R-row
        "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
        // W-row
        "wa": "わ", "wi": "ゐ", "we": "ゑ", "wo": "を",
        // N
        "n'": "ん",
        // G-row (dakuten)
        "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
        // Z-row
        "za": "ざ", "zi": "じ", "ji": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
        // D-row
        "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
        // B-row
        "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
        // P-row (handakuten)
        "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
        // Combo kana
        "kya": "きゃ", "kyu": "きゅ", "kyo": "きょ",
        "sha": "しゃ", "shu": "しゅ", "sho": "しょ",
        "sya": "しゃ", "syu": "しゅ", "syo": "しょ",
        "cha": "ちゃ", "chu": "ちゅ", "cho": "ちょ",
        "tya": "ちゃ", "tyu": "ちゅ", "tyo": "ちょ",
        "nya": "にゃ", "nyu": "にゅ", "nyo": "にょ",
        "hya": "ひゃ", "hyu": "ひゅ", "hyo": "ひょ",
        "mya": "みゃ", "myu": "みゅ", "myo": "みょ",
        "rya": "りゃ", "ryu": "りゅ", "ryo": "りょ",
        "gya": "ぎゃ", "gyu": "ぎゅ", "gyo": "ぎょ",
        "ja": "じゃ", "ju": "じゅ", "jo": "じょ",
        "jya": "じゃ", "jyu": "じゅ", "jyo": "じょ",
        "bya": "びゃ", "byu": "びゅ", "byo": "びょ",
        "pya": "ぴゃ", "pyu": "ぴゅ", "pyo": "ぴょ",
        // Small kana
        "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ",
        "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ",
        "xtu": "っ", "xtsu": "っ",
        // Punctuation
        "-": "ー", ".": "。", ",": "、",
    ]
}
