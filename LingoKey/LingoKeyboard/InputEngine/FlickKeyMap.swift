import Foundation

/// Flick keyboard key definitions and character conversion maps
/// Layout matches Apple's native Japanese flick keyboard
enum FlickKeyMap {
    /// Flick direction
    enum Direction {
        case center // tap (あ段)
        case left   // い段
        case up     // う段
        case right  // え段
        case down   // お段
    }

    /// A single flick key with its 5-direction outputs
    struct FlickKey {
        let center: String
        let left: String
        let up: String
        let right: String
        let down: String

        /// Characters in toggle-tap order: center → left → up → right → down
        var toggleCycle: [String] {
            [center, left, up, right, down].filter { !$0.isEmpty }
        }

        func kana(for direction: Direction) -> String {
            switch direction {
            case .center: return center
            case .left:   return left
            case .up:     return up
            case .right:  return right
            case .down:   return down
            }
        }
    }

    // MARK: - Kana Grid (3 columns × 3 rows, matching Apple center columns)

    static let kanaGrid: [[FlickKey]] = [
        // Row 0: あ か さ
        [
            FlickKey(center: "あ", left: "い", up: "う", right: "え", down: "お"),
            FlickKey(center: "か", left: "き", up: "く", right: "け", down: "こ"),
            FlickKey(center: "さ", left: "し", up: "す", right: "せ", down: "そ"),
        ],
        // Row 1: た な は
        [
            FlickKey(center: "た", left: "ち", up: "つ", right: "て", down: "と"),
            FlickKey(center: "な", left: "に", up: "ぬ", right: "ね", down: "の"),
            FlickKey(center: "は", left: "ひ", up: "ふ", right: "へ", down: "ほ"),
        ],
        // Row 2: ま や ら
        [
            FlickKey(center: "ま", left: "み", up: "む", right: "め", down: "も"),
            FlickKey(center: "や", left: "（", up: "ゆ", right: "）", down: "よ"),
            FlickKey(center: "ら", left: "り", up: "る", right: "れ", down: "ろ"),
        ],
    ]

    // Bottom-row center keys
    static let kanaWa = FlickKey(center: "わ", left: "を", up: "ん", right: "ー", down: "〜")
    static let punctuation = FlickKey(center: "、", left: "。", up: "？", right: "！", down: "")

    // MARK: - English ABC Flick Grid (3 columns × 4 rows, matching Apple native)

    static let englishGrid: [[FlickKey]] = [
        // Row 0: @#/&_ | ABC | DEF
        [
            FlickKey(center: "@", left: "#", up: "/", right: "&", down: "_"),
            FlickKey(center: "A", left: "B", up: "C", right: "", down: ""),
            FlickKey(center: "D", left: "E", up: "F", right: "", down: ""),
        ],
        // Row 1: GHI | JKL | MNO
        [
            FlickKey(center: "G", left: "H", up: "I", right: "", down: ""),
            FlickKey(center: "J", left: "K", up: "L", right: "", down: ""),
            FlickKey(center: "M", left: "N", up: "O", right: "", down: ""),
        ],
        // Row 2: PQRS | TUV | WXYZ
        [
            FlickKey(center: "P", left: "Q", up: "R", right: "S", down: ""),
            FlickKey(center: "T", left: "U", up: "V", right: "", down: ""),
            FlickKey(center: "W", left: "X", up: "Y", right: "Z", down: ""),
        ],
    ]

    // Bottom row special keys for English flick
    static let englishShift = FlickKey(center: "a/A", left: "", up: "", right: "", down: "")
    static let englishQuote = FlickKey(center: "'", left: "\"", up: "(", right: ")", down: "")
    static let englishPunctuation = FlickKey(center: ".", left: ",", up: "?", right: "!", down: "")

    // MARK: - Number/Symbol Flick Grid (3 columns × 4 rows, matching Apple native)

    static let numberGrid: [[FlickKey]] = [
        // Row 0: 1 | 2 | 3
        [
            FlickKey(center: "1", left: "☆", up: "♪", right: "→", down: ""),
            FlickKey(center: "2", left: "¥", up: "$", right: "€", down: ""),
            FlickKey(center: "3", left: "%", up: "°", right: "#", down: ""),
        ],
        // Row 1: 4 | 5 | 6
        [
            FlickKey(center: "4", left: "○", up: "＊", right: "・", down: ""),
            FlickKey(center: "5", left: "+", up: "×", right: "÷", down: ""),
            FlickKey(center: "6", left: "<", up: "=", right: ">", down: ""),
        ],
        // Row 2: 7 | 8 | 9
        [
            FlickKey(center: "7", left: "「", up: "」", right: ":", down: ""),
            FlickKey(center: "8", left: "〒", up: "々", right: "〆", down: ""),
            FlickKey(center: "9", left: "^", up: "|", right: "\\", down: ""),
        ],
    ]

    // Bottom row special keys for Number flick
    static let numberParens = FlickKey(center: "(", left: ")", up: "[", right: "]", down: "")
    static let numberZero = FlickKey(center: "0", left: "〜", up: "…", right: "", down: "")
    static let numberPunctuation = FlickKey(center: ".", left: ",", up: "-", right: "/", down: "")

    // MARK: - Dakuten (濁点) Forward Map

    static let dakutenForward: [Character: Character] = [
        "か": "が", "き": "ぎ", "く": "ぐ", "け": "げ", "こ": "ご",
        "さ": "ざ", "し": "じ", "す": "ず", "せ": "ぜ", "そ": "ぞ",
        "た": "だ", "ち": "ぢ", "つ": "づ", "て": "で", "と": "ど",
        "は": "ば", "ひ": "び", "ふ": "ぶ", "へ": "べ", "ほ": "ぼ",
        "う": "ゔ",
    ]

    // MARK: - Dakuten Reverse Map

    static let dakutenReverse: [Character: Character] = [
        "が": "か", "ぎ": "き", "ぐ": "く", "げ": "け", "ご": "こ",
        "ざ": "さ", "じ": "し", "ず": "す", "ぜ": "せ", "ぞ": "そ",
        "だ": "た", "ぢ": "ち", "づ": "つ", "で": "て", "ど": "と",
        "ば": "は", "び": "ひ", "ぶ": "ふ", "べ": "へ", "ぼ": "ほ",
        "ゔ": "う",
    ]

    // MARK: - Handakuten (半濁点) Forward Map

    static let handakutenForward: [Character: Character] = [
        "は": "ぱ", "ひ": "ぴ", "ふ": "ぷ", "へ": "ぺ", "ほ": "ぽ",
    ]

    // MARK: - Handakuten Reverse Map

    static let handakutenReverse: [Character: Character] = [
        "ぱ": "は", "ぴ": "ひ", "ぷ": "ふ", "ぺ": "へ", "ぽ": "ほ",
    ]

    // MARK: - Small Kana (小文字) Forward Map

    static let smallKanaForward: [Character: Character] = [
        "あ": "ぁ", "い": "ぃ", "う": "ぅ", "え": "ぇ", "お": "ぉ",
        "や": "ゃ", "ゆ": "ゅ", "よ": "ょ",
        "つ": "っ",
    ]

    // MARK: - Small Kana Reverse Map

    static let smallKanaReverse: [Character: Character] = [
        "ぁ": "あ", "ぃ": "い", "ぅ": "う", "ぇ": "え", "ぉ": "お",
        "ゃ": "や", "ゅ": "ゆ", "ょ": "よ",
        "っ": "つ",
    ]
}

// MARK: - Character Helpers

extension Character {
    /// Returns true if the character is a hiragana character (U+3040–U+309F)
    var isHiragana: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return (0x3040...0x309F).contains(scalar.value)
    }
}
