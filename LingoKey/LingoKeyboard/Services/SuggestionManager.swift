import Foundation
import UIKit

final class SuggestionManager {
    private weak var state: LingoKeyboardState?
    private var debounceTask: Task<Void, Never>?

    private let sentenceBoundaries: Set<Character> = [".", "!", "?", "\u{3002}", "\u{FF01}", "\u{FF1F}", "\n"]

    init(state: LingoKeyboardState) {
        self.state = state
    }

    func hiraganaBufferDidChange(buffer: String) {
        debounceTask?.cancel()

        guard let state = state else { return }
        let mode = state.currentMode

        guard mode.isJapaneseInput else { return }

        guard buffer.count >= 1 else {
            state.suggestions = []
            return
        }

        // Local kana-kanji conversion: fast, no API needed.
        // Short debounce just to avoid converting on every keystroke.
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))
            guard !Task.isCancelled else { return }

            guard let self = self, let state = self.state else { return }

            let candidates = state.localConverter.convert(buffer)
            let suggestions = candidates.map {
                Suggestion(text: $0, originalText: buffer, kind: .conversion)
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                state.suggestions = suggestions
            }
        }
    }

    func textDidChange(proxy: UITextDocumentProxy) {
        debounceTask?.cancel()

        guard let state = state else { return }
        let mode = state.currentMode

        // JP modes use explicit confirmation, not auto-suggestion
        guard !mode.isJapaneseInput else { return }

        let text = currentSentence(from: proxy)
        let minLength = mode == .enCorrection ? 5 : 2

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
        guard let last = text.last else { return 0.8 }
        if sentenceBoundaries.contains(last) { return 0.0 }
        if last == " " { return 0.2 }
        return 0.8
    }
}
