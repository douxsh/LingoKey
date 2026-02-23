import UIKit

enum TextReplacementService {
    static func apply(suggestion: Suggestion, to proxy: UITextDocumentProxy, mode: KeyboardMode) {
        switch mode {
        case .enCorrection, .krCorrection:
            replaceSentence(with: suggestion.text, originalText: suggestion.originalText, proxy: proxy)
        case .jpToEn, .jpToKr:
            // For translation, just insert the translated text
            proxy.insertText(suggestion.text)
        }
    }

    private static func replaceSentence(with newText: String, originalText: String, proxy: UITextDocumentProxy) {
        let before = proxy.documentContextBeforeInput ?? ""

        // Find how many characters of the original text match the end of the buffer
        let matchLength = min(originalText.count, before.count)
        guard matchLength > 0 else {
            proxy.insertText(newText)
            return
        }

        // Delete the original text
        for _ in 0..<matchLength {
            proxy.deleteBackward()
        }

        // Insert the corrected text
        proxy.insertText(newText)
    }
}
