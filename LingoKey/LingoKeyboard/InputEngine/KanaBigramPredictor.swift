import Foundation

/// Predicts the next likely kana row based on bigram statistics of Japanese kana.
/// Used for dynamic hit area expansion on the flick keyboard (invisible to user).
enum KanaBigramPredictor {

    /// Kana row indices matching the flick keyboard grid layout.
    /// Row 0: あ(0,0) か(0,1) さ(0,2)
    /// Row 1: た(1,0) な(1,1) は(1,2)
    /// Row 2: ま(2,0) や(2,1) ら(2,2)
    /// Special: わ(-1,0)
    private enum KanaRow: Int, CaseIterable {
        case a = 0, ka, sa, ta, na, ha, ma, ya, ra, wa
    }

    /// Map a hiragana character to its row.
    private static func row(of char: Character) -> KanaRow? {
        switch char {
        case "あ", "い", "う", "え", "お": return .a
        case "か", "き", "く", "け", "こ", "が", "ぎ", "ぐ", "げ", "ご": return .ka
        case "さ", "し", "す", "せ", "そ", "ざ", "じ", "ず", "ぜ", "ぞ": return .sa
        case "た", "ち", "つ", "て", "と", "だ", "ぢ", "づ", "で", "ど", "っ": return .ta
        case "な", "に", "ぬ", "ね", "の": return .na
        case "は", "ひ", "ふ", "へ", "ほ", "ば", "び", "ぶ", "べ", "ぼ", "ぱ", "ぴ", "ぷ", "ぺ", "ぽ": return .ha
        case "ま", "み", "む", "め", "も": return .ma
        case "や", "ゆ", "よ": return .ya
        case "ら", "り", "る", "れ", "ろ": return .ra
        case "わ", "を", "ん": return .wa
        default: return nil
        }
    }

    /// Bigram table: previousRow → [nextRow] ordered by probability (max 3).
    /// Based on Japanese kana bigram frequency statistics.
    private static let bigramTable: [KanaRow: [KanaRow]] = [
        .a:  [.ra, .na, .ta],     // ある、あな、あた / いる、いた / うか、うな
        .ka: [.ra, .na, .ta],     // から、かな、かた / きた、きて
        .sa: [.ra, .ta, .ha],     // され、した、して、しば
        .ta: [.ka, .na, .a],      // たか、たな、たい / ちか、てき、ての
        .na: [.ka, .ra, .a],      // なか、なら、ない / にし、にち
        .ha: [.na, .ka, .a],      // はな、はか、はい / ひと
        .ma: [.a, .ta, .sa],      // まい、また、ます / みた
        .ya: [.ka, .sa, .ta],     // やか、やす、やっ
        .ra: [.na, .ka, .a],      // らな、らか、らい / れた、れる
        .wa: [.ta, .na, .ka],     // んた、んな、んか / わた、わか
    ]

    /// Returns grid coordinates (row, col) of the top predicted next keys.
    /// - Parameter lastChar: The last character in the hiragana buffer.
    /// - Returns: Up to 3 (row, col) pairs ordered by likelihood. Empty if no prediction.
    static func predictNextKeys(lastChar: Character?) -> [(row: Int, col: Int)] {
        guard let char = lastChar, let currentRow = row(of: char) else {
            return []
        }
        guard let predictions = bigramTable[currentRow] else {
            return []
        }
        return predictions.map { gridPosition(for: $0) }
    }

    /// Returns true if the last character in the buffer can be modified
    /// (dakuten, handakuten, or small kana), meaning the modifier key should
    /// have an expanded touch target.
    static func isModifiable(lastChar: Character?) -> Bool {
        guard let char = lastChar else { return false }
        return FlickKeyMap.dakutenForward[char] != nil
            || FlickKeyMap.handakutenForward[char] != nil
            || FlickKeyMap.smallKanaForward[char] != nil
    }

    /// Convert a KanaRow to flick grid (row, col).
    private static func gridPosition(for kanaRow: KanaRow) -> (row: Int, col: Int) {
        switch kanaRow {
        case .a:  return (0, 0)
        case .ka: return (0, 1)
        case .sa: return (0, 2)
        case .ta: return (1, 0)
        case .na: return (1, 1)
        case .ha: return (1, 2)
        case .ma: return (2, 0)
        case .ya: return (2, 1)
        case .ra: return (2, 2)
        case .wa: return (-1, 0)
        }
    }
}
