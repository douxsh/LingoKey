import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary

/// Local kana-to-kanji conversion using AzooKeyKanaKanjiConverter.
/// This avoids hitting the Claude API for basic Japanese conversion.
final class LocalKanaKanjiConverter {
    private let converter = KanaKanjiConverter.withDefaultDictionary()
    private let memoryDir: URL
    private let sharedDir: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        memoryDir = docs.appendingPathComponent("kana_kanji_memory")
        sharedDir = docs.appendingPathComponent("kana_kanji_shared")
        try? FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)
    }

    /// Convert hiragana/mixed text to kanji candidates.
    /// Returns up to `maxResults` conversion candidates.
    func convert(_ text: String, maxResults: Int = 5) -> [String] {
        guard !text.isEmpty else { return [] }

        var composing = ComposingText()
        composing.insertAtCursorPosition(text, inputStyle: .direct)

        let options = ConvertRequestOptions(
            requireJapanesePrediction: true,
            requireEnglishPrediction: false,
            keyboardLanguage: .ja_JP,
            learningType: .inputAndOutput,
            memoryDirectoryURL: memoryDir,
            sharedContainerURL: sharedDir,
            textReplacer: .empty,
            specialCandidateProviders: nil,
            metadata: .init(versionString: "LingoKey 1.0")
        )

        let results = converter.requestCandidates(composing, options: options)

        // Collect unique candidates
        var seen = Set<String>()
        var candidates: [String] = []

        for candidate in results.mainResults {
            let t = candidate.text
            if !seen.contains(t) {
                seen.insert(t)
                candidates.append(t)
                if candidates.count >= maxResults { break }
            }
        }

        return candidates
    }
}
