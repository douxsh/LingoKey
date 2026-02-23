import UIKit
import SwiftUI
import KeyboardKit

class KeyboardViewController: KeyboardInputViewController {

    private lazy var keyboardState = LingoKeyboardState(controller: self)

    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardState.loadSettings()
    }

    override func viewWillSetupKeyboardView() {
        setupKeyboardView { [weak self] controller in
            LingoKeyboardView(
                state: controller.state,
                lingoState: self?.keyboardState ?? LingoKeyboardState(controller: nil)
            )
        }
    }
}

// MARK: - Keyboard State

@Observable
final class LingoKeyboardState {
    var currentMode: KeyboardMode = .enCorrection
    var suggestions: [Suggestion] = []
    /// Confirmed (locked) Japanese text — already converted to kanji/katakana.
    var confirmedText: String = ""
    /// Composing hiragana — still being typed, shown with underline.
    var hiraganaBuffer: String = ""
    var isLoading: Bool = false
    var showNumberKeyboard: Bool = false
    var showEmojiPicker: Bool = false
    var useRomajiInput: Bool = false

    private weak var controller: KeyboardViewController?
    @ObservationIgnored private var _suggestionManager: SuggestionManager?
    private var suggestionManager: SuggestionManager {
        if let m = _suggestionManager { return m }
        let m = SuggestionManager(state: self)
        _suggestionManager = m
        return m
    }

    @ObservationIgnored let hangulComposer = HangulComposer()
    @ObservationIgnored let romajiConverter = RomajiToHiraganaConverter()
    @ObservationIgnored let apiService = ClaudeAPIService()
    @ObservationIgnored let localConverter = LocalKanaKanjiConverter()

    init(controller: KeyboardViewController?) {
        self.controller = controller
    }

    func loadSettings() {
        let settings = SharedSettings()
        if let mode = KeyboardMode(rawValue: settings.defaultMode) {
            currentMode = mode
        }
        apiService.apiKey = settings.apiKey
    }

    func switchMode(_ mode: KeyboardMode) {
        currentMode = mode
        suggestions = []
        confirmedText = ""
        hiraganaBuffer = ""
        showNumberKeyboard = false
        showEmojiPicker = false
        useRomajiInput = false
        hangulComposer.reset()
        romajiConverter.reset()
    }

    // MARK: - Number Keyboard

    func toggleNumberKeyboard() {
        showNumberKeyboard = true
    }

    func switchToLetterKeyboard() {
        showNumberKeyboard = false
    }

    func handleNumberSymbolChar(_ char: String) {
        guard let proxy = controller?.textDocumentProxy else { return }
        proxy.insertText(char)
    }

    // MARK: - Emoji Picker

    func toggleEmojiPicker() {
        showEmojiPicker = true
    }

    func dismissEmojiPicker() {
        showEmojiPicker = false
    }

    func handleEmojiInput(_ emoji: String) {
        guard let proxy = controller?.textDocumentProxy else { return }
        proxy.insertText(emoji)
    }

    // MARK: - Romaji / Flick Toggle

    func switchToRomajiInput() {
        useRomajiInput = true
        romajiConverter.reset()
    }

    func switchToFlickInput() {
        useRomajiInput = false
        romajiConverter.reset()
    }

    // MARK: - Character Input

    func handleCharacter(_ char: String) {
        guard let proxy = controller?.textDocumentProxy else { return }

        switch currentMode {
        case .enCorrection:
            proxy.insertText(char)
            suggestionManager.textDidChange(proxy: proxy)

        case .krCorrection:
            let result = hangulComposer.process(char)
            if let delete = result.deleteCount, delete > 0 {
                for _ in 0..<delete {
                    proxy.deleteBackward()
                }
            }
            if let text = result.commitText {
                proxy.insertText(text)
            }
            suggestionManager.textDidChange(proxy: proxy)

        case .jpToEn, .jpToKr:
            let result = romajiConverter.process(char)
            hiraganaBuffer = romajiConverter.displayText
            if result.converted {
                // Don't insert into proxy; show in preview only
            }
            suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
        }
    }

    // MARK: - Flick (Kana) Input

    func handleKana(_ kana: String) {
        // Handle punctuation cycling: "\u{0008}" prefix means
        // "delete last char, then insert the rest" (repeated-tap replacement).
        if kana.hasPrefix("\u{0008}") {
            let replacement = String(kana.dropFirst())
            if !hiraganaBuffer.isEmpty {
                hiraganaBuffer.removeLast()
                hiraganaBuffer += replacement
            } else {
                // Already committed to proxy – replace there
                controller?.textDocumentProxy.deleteBackward()
                controller?.textDocumentProxy.insertText(replacement)
            }
            suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
            return
        }

        hiraganaBuffer += kana
        suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
    }

    /// Cycles through dakuten → handakuten → small kana → original
    func handleModifierToggle() {
        guard !hiraganaBuffer.isEmpty else { return }
        let last = hiraganaBuffer.last!
        let oldBuffer = hiraganaBuffer

        // Currently dakuten → try handakuten, else revert to original
        if let original = FlickKeyMap.dakutenReverse[last] {
            if let handakuten = FlickKeyMap.handakutenForward[original] {
                hiraganaBuffer.removeLast()
                hiraganaBuffer.append(handakuten)
            } else {
                hiraganaBuffer.removeLast()
                hiraganaBuffer.append(original)
            }
        }
        // Currently handakuten → revert to original
        else if let original = FlickKeyMap.handakutenReverse[last] {
            hiraganaBuffer.removeLast()
            hiraganaBuffer.append(original)
        }
        // Currently small kana → revert to original
        else if let original = FlickKeyMap.smallKanaReverse[last] {
            hiraganaBuffer.removeLast()
            hiraganaBuffer.append(original)
        }
        // Try dakuten forward
        else if let dakuten = FlickKeyMap.dakutenForward[last] {
            hiraganaBuffer.removeLast()
            hiraganaBuffer.append(dakuten)
        }
        // Try small kana forward
        else if let small = FlickKeyMap.smallKanaForward[last] {
            hiraganaBuffer.removeLast()
            hiraganaBuffer.append(small)
        }

        if hiraganaBuffer != oldBuffer {
            suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
        }
    }

    // MARK: - Backspace

    func handleBackspace() {
        guard let proxy = controller?.textDocumentProxy else { return }

        switch currentMode {
        case .enCorrection:
            proxy.deleteBackward()
            suggestionManager.textDidChange(proxy: proxy)

        case .krCorrection:
            let result = hangulComposer.backspace()
            if let delete = result.deleteCount, delete > 0 {
                for _ in 0..<delete {
                    proxy.deleteBackward()
                }
            }
            if let text = result.commitText {
                proxy.insertText(text)
            }
            suggestionManager.textDidChange(proxy: proxy)

        case .jpToEn, .jpToKr:
            if !hiraganaBuffer.isEmpty {
                hiraganaBuffer.removeLast()
                suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
            } else if !romajiConverter.displayText.isEmpty {
                romajiConverter.backspace()
                hiraganaBuffer = romajiConverter.displayText
                suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
            } else if !confirmedText.isEmpty {
                // Delete from confirmed text
                confirmedText.removeLast()
                if confirmedText.isEmpty {
                    suggestions = []
                }
            } else if !suggestions.isEmpty {
                suggestions = []
            } else {
                proxy.deleteBackward()
            }
        }
    }

    // MARK: - Space / Return

    func handleSpace() {
        guard let proxy = controller?.textDocumentProxy else { return }

        switch currentMode {
        case .enCorrection, .krCorrection:
            if currentMode == .krCorrection {
                hangulComposer.finalize().map { text in
                    proxy.insertText(text)
                }
            }
            proxy.insertText(" ")
            suggestionManager.textDidChange(proxy: proxy)

        case .jpToEn, .jpToKr:
            let composing = hiraganaBuffer.isEmpty ? romajiConverter.displayText : hiraganaBuffer
            guard !composing.isEmpty || !confirmedText.isEmpty else {
                proxy.insertText(" ")
                return
            }
            confirmJapaneseInput()
        }
    }

    func handleReturn() {
        guard let proxy = controller?.textDocumentProxy else { return }

        if currentMode == .krCorrection {
            hangulComposer.finalize().map { text in
                proxy.insertText(text)
            }
        }
        if currentMode.isJapaneseInput {
            let composing = hiraganaBuffer.isEmpty ? romajiConverter.displayText : hiraganaBuffer
            if !composing.isEmpty || !confirmedText.isEmpty {
                confirmJapaneseInput()
                return
            }
        }

        proxy.insertText("\n")
    }

    func confirmJapaneseInput() {
        let composing = hiraganaBuffer.isEmpty ? romajiConverter.displayText : hiraganaBuffer

        if !composing.isEmpty {
            // --- Composing text exists: lock as-is (no auto-conversion) ---
            romajiConverter.reset()
            confirmedText += composing
            hiraganaBuffer = ""
            suggestions = []
        } else if !confirmedText.isEmpty {
            // --- All text confirmed, no composing: translate ---
            let textToTranslate = confirmedText
            confirmedText = ""
            hiraganaBuffer = ""
            romajiConverter.reset()
            isLoading = true

            Task {
                let translations = await apiService.translateOnly(text: textToTranslate, mode: currentMode)
                await MainActor.run {
                    suggestions = translations
                    isLoading = false
                }
            }
        }
    }

    func applySuggestion(_ suggestion: Suggestion) {
        guard let proxy = controller?.textDocumentProxy else { return }

        // In JP modes, conversion candidates lock into confirmedText.
        // User can continue typing more, or press 確定 to translate.
        if currentMode.isJapaneseInput && suggestion.kind == .conversion {
            confirmedText += suggestion.text
            hiraganaBuffer = ""
            romajiConverter.reset()
            suggestions = []
            return
        }

        TextReplacementService.apply(suggestion: suggestion, to: proxy, mode: currentMode)
        suggestions = []
        if currentMode.isJapaneseInput {
            confirmedText = ""
            hiraganaBuffer = ""
            romajiConverter.reset()
        }
    }

    var textDocumentProxy: UITextDocumentProxy? {
        controller?.textDocumentProxy
    }
}
