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
    @ObservationIgnored let apiService = LLMAPIService()

    // Toggle input (tap-cycling) state
    @ObservationIgnored private var lastTappedKeyCenter: String = ""
    @ObservationIgnored private var tapCycleChars: [String] = []
    @ObservationIgnored private var tapCycleIndex: Int = 0
    @ObservationIgnored private var lastTapTime: Date = .distantPast
    @ObservationIgnored private var tapCycleTimer: Timer?
    @ObservationIgnored private let tapCycleTimeout: TimeInterval = 0.7
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
        confirmCurrentCycle()
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

    /// Cycles: original → small kana → dakuten → handakuten → original
    /// If no small kana: original → dakuten → handakuten → original
    func handleModifierToggle() {
        confirmCurrentCycle()
        guard !hiraganaBuffer.isEmpty else { return }
        let last = hiraganaBuffer.last!

        // Find the original (base) character
        let original: Character
        if let o = FlickKeyMap.smallKanaReverse[last] {
            original = o
        } else if let o = FlickKeyMap.dakutenReverse[last] {
            original = o
        } else if let o = FlickKeyMap.handakutenReverse[last] {
            original = o
        } else {
            original = last
        }

        // Build cycle: original → small → dakuten → handakuten
        var cycle: [Character] = [original]
        if let small = FlickKeyMap.smallKanaForward[original] {
            cycle.append(small)
        }
        if let dakuten = FlickKeyMap.dakutenForward[original] {
            cycle.append(dakuten)
        }
        if let handakuten = FlickKeyMap.handakutenForward[original] {
            cycle.append(handakuten)
        }

        guard cycle.count > 1 else { return }
        let currentIndex = cycle.firstIndex(of: last) ?? 0
        let nextIndex = (currentIndex + 1) % cycle.count

        hiraganaBuffer.removeLast()
        hiraganaBuffer.append(cycle[nextIndex])
        suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
    }

    // MARK: - Toggle Input (Tap-Cycling)

    /// Handles repeated taps on the same flick key: た→ち→つ→て→と
    func handleKanaTap(_ key: FlickKeyMap.FlickKey) {
        let now = Date()
        let cycle = key.toggleCycle
        guard !cycle.isEmpty else { return }

        if key.center == lastTappedKeyCenter,
           now.timeIntervalSince(lastTapTime) < tapCycleTimeout,
           !tapCycleChars.isEmpty {
            // Same key within timeout → cycle to next character
            tapCycleIndex = (tapCycleIndex + 1) % cycle.count
            if !hiraganaBuffer.isEmpty {
                hiraganaBuffer.removeLast()
            }
        } else {
            // Different key or timeout expired → confirm previous, start new cycle
            confirmCurrentCycle()
            tapCycleIndex = 0
            lastTappedKeyCenter = key.center
            tapCycleChars = cycle
        }

        hiraganaBuffer += cycle[tapCycleIndex]
        lastTapTime = now
        startTapCycleTimer()
        suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
    }

    // MARK: - Advance Cursor (→ key)

    /// Confirms the current cycling character so the next tap starts a new character.
    func handleAdvanceCursor() {
        confirmCurrentCycle()
    }

    // MARK: - Undo Kana (↩ key)

    /// Reverts one step in the tap-cycling sequence (e.g., ち → た).
    func handleUndoKana() {
        guard !tapCycleChars.isEmpty, tapCycleIndex > 0 else { return }
        tapCycleIndex -= 1
        if !hiraganaBuffer.isEmpty {
            hiraganaBuffer.removeLast()
        }
        hiraganaBuffer += tapCycleChars[tapCycleIndex]
        lastTapTime = Date()
        startTapCycleTimer()
        suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
    }

    /// Ends the current tap cycle, locking in the current character.
    private func confirmCurrentCycle() {
        tapCycleTimer?.invalidate()
        tapCycleTimer = nil
        lastTappedKeyCenter = ""
        tapCycleChars = []
        tapCycleIndex = 0
        lastTapTime = .distantPast
    }

    private func startTapCycleTimer() {
        tapCycleTimer?.invalidate()
        tapCycleTimer = Timer.scheduledTimer(withTimeInterval: tapCycleTimeout, repeats: false) { [weak self] _ in
            self?.confirmCurrentCycle()
        }
    }

    // MARK: - Backspace

    func handleBackspace() {
        confirmCurrentCycle()
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
        confirmCurrentCycle()
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
        confirmCurrentCycle()
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
