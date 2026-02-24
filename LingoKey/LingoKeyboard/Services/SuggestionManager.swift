import Foundation
import UIKit

final class SuggestionManager {
    private weak var state: LingoKeyboardState?
    private var debounceTask: Task<Void, Never>?
    private var translationTask: Task<Void, Never>?

    private let sentenceBoundaries: Set<Character> = [".", "!", "?", "\u{3002}", "\u{FF01}", "\u{FF1F}", "\n"]

    init(state: LingoKeyboardState) {
        self.state = state
    }

    func hiraganaBufferDidChange(buffer: String) {
        debounceTask?.cancel()
        translationTask?.cancel()

        guard let state = state else { return }
        let mode = state.currentMode

        guard mode.isJapaneseInput else { return }

        guard buffer.count >= 1 else {
            state.suggestions = []
            return
        }

        // Stage 1: Local kana-kanji conversion (150ms debounce)
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(0.15 * 1_000_000_000))
            guard !Task.isCancelled else { return }

            guard let self = self, let state = self.state else { return }

            let candidates = state.localConverter.convert(buffer)
            let conversionSuggestions = candidates.map {
                Suggestion(text: $0, originalText: buffer, kind: .conversion)
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                // Keep existing translation suggestions, replace only conversion ones
                let existingTranslations = state.suggestions.filter { $0.kind == .translation }
                state.suggestions = conversionSuggestions + existingTranslations
            }

            // Stage 2: API translation (800ms debounce from original keystroke)
            // Wait an additional 650ms after conversion completes (total ~800ms from keystroke)
            self.startTranslationTask(buffer: buffer)
        }
    }

    private func startTranslationTask(buffer: String) {
        translationTask?.cancel()
        translationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(0.65 * 1_000_000_000))
            guard !Task.isCancelled else { return }

            guard let self = self, let state = self.state else { return }

            // Build full text: confirmedText (already converted) + current composing part
            let confirmed = await MainActor.run { state.confirmedText }
            let conversionSuggestions = await MainActor.run { state.suggestions.filter { $0.kind == .conversion } }
            let composingPart: String
            if let firstConversion = conversionSuggestions.first {
                composingPart = firstConversion.text
            } else {
                composingPart = buffer
            }
            let textToTranslate = confirmed + composingPart

            let translations = await state.apiService.translateOnly(text: textToTranslate, mode: state.currentMode)

            guard !Task.isCancelled else { return }
            await MainActor.run {
                // Keep conversion suggestions, replace translation ones
                let currentConversions = state.suggestions.filter { $0.kind == .conversion }
                state.suggestions = currentConversions + translations
            }
        }
    }

    func textDidChange(proxy: UITextDocumentProxy) {
        debounceTask?.cancel()
        translationTask?.cancel()

        guard let state = state else { return }
        let mode = state.currentMode

        // JP modes use explicit confirmation, not auto-suggestion
        guard !mode.isJapaneseInput else { return }

        let text = currentSentence(from: proxy)
        let minLength = mode == .enCorrection ? 3 : 2

        guard text.count >= minLength else {
            state.suggestions = []
            return
        }

        let delay = debounceDelay(for: text)

        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            guard let self = self, let state = self.state else { return }

            await MainActor.run { state.isLoading = true }

            let results = await state.apiService.correct(text: text, mode: mode)

            guard !Task.isCancelled else { return }
            await MainActor.run {
                state.suggestions = results
                state.isLoading = false
            }
        }
    }

    // MARK: - Private

    private func currentSentence(from proxy: UITextDocumentProxy) -> String {
        let before = proxy.documentContextBeforeInput ?? ""
        // Find the last sentence boundary
        if let lastBoundary = before.lastIndex(where: { sentenceBoundaries.contains($0) }) {
            let start = before.index(after: lastBoundary)
            return String(before[start...]).trimmingCharacters(in: .whitespaces)
        }
        return before.trimmingCharacters(in: .whitespaces)
    }

    private func debounceDelay(for text: String) -> Double {
        guard let last = text.last else { return 0.5 }
        if sentenceBoundaries.contains(last) { return 0.0 }
        if last == " " { return 0.2 }
        return 0.5
    }
}
