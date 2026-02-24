import UIKit
import SwiftUI
import KeyboardKit

class KeyboardViewController: KeyboardInputViewController {

    private lazy var keyboardState = LingoKeyboardState(controller: self)

    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardState.loadSettings()
        // Use system keyboard-style translucent background (like Apple's native keyboard)
        if let iv = inputView {
            let kbView = UIInputView(frame: iv.frame, inputViewStyle: .keyboard)
            kbView.allowsSelfSizing = true
            // Move existing subviews
            for sub in iv.subviews {
                kbView.addSubview(sub)
            }
            inputView = kbView
        }
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

    /// Sub-keyboard state for flick mode switching: kana → english → number
    enum FlickSubKeyboard { case kana, english, number }
    var flickSubKeyboard: FlickSubKeyboard = .kana

    // MARK: - Trackpad Cursor
    /// Cursor position within `confirmedText + hiraganaBuffer`. nil = end (legacy behavior).
    var bufferCursorPosition: Int? = nil
    var isTrackpadActive: Bool = false

    enum CursorDirection { case left, right }

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
        flickSubKeyboard = .kana
        bufferCursorPosition = nil
        isTrackpadActive = false
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
        flickSubKeyboard = .kana
        romajiConverter.reset()
    }

    // MARK: - Flick Sub-Keyboard Switching

    func switchToEnglishFlick() {
        flickSubKeyboard = .english
    }

    func switchToNumberFlick() {
        flickSubKeyboard = .number
    }

    func switchToKanaFlick() {
        flickSubKeyboard = .kana
    }

    func handleFlickDirectChar(_ char: String) {
        if currentMode.isJapaneseInput {
            // In Japanese mode, route through the buffer so it stays in the preview
            if char.hasPrefix("\u{0008}") {
                let replacement = String(char.dropFirst())
                if !hiraganaBuffer.isEmpty {
                    if bufferCursorPosition != nil {
                        deleteFromBuffer()
                        insertIntoBuffer(replacement)
                    } else {
                        hiraganaBuffer.removeLast()
                        hiraganaBuffer += replacement
                    }
                } else {
                    controller?.textDocumentProxy.deleteBackward()
                    controller?.textDocumentProxy.insertText(replacement)
                }
            } else {
                insertIntoBuffer(char)
            }
            suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
        } else {
            guard let proxy = controller?.textDocumentProxy else { return }
            if char.hasPrefix("\u{0008}") {
                let replacement = String(char.dropFirst())
                proxy.deleteBackward()
                proxy.insertText(replacement)
            } else {
                proxy.insertText(char)
            }
        }
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
            if bufferCursorPosition != nil {
                // When cursor is positioned mid-buffer, insert raw char
                insertIntoBuffer(char)
                suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
            } else {
                let result = romajiConverter.process(char)
                hiraganaBuffer = romajiConverter.displayText
                if result.converted {
                    // Don't insert into proxy; show in preview only
                }
                suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
            }
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
                if bufferCursorPosition != nil {
                    deleteFromBuffer()
                    insertIntoBuffer(replacement)
                } else {
                    hiraganaBuffer.removeLast()
                    hiraganaBuffer += replacement
                }
            } else {
                // Already committed to proxy – replace there
                controller?.textDocumentProxy.deleteBackward()
                controller?.textDocumentProxy.insertText(replacement)
            }
            suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
            return
        }

        insertIntoBuffer(kana)
        suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
    }

    /// Cycles: original → small kana → dakuten → handakuten → original
    /// If no small kana: original → dakuten → handakuten → original
    func handleModifierToggle() {
        confirmCurrentCycle()
        guard !hiraganaBuffer.isEmpty else { return }

        // Determine the character to modify based on cursor position
        let combined = confirmedText + hiraganaBuffer
        let pos = effectiveCursorPosition
        guard pos > 0 else { return }
        let charIndex = combined.index(combined.startIndex, offsetBy: pos - 1)
        let last = combined[charIndex]

        // Only operate on hiraganaBuffer portion
        guard pos > confirmedText.count else { return }

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

        // Replace in hiraganaBuffer at the correct position
        let bufferOffset = pos - confirmedText.count - 1
        let bufIdx = hiraganaBuffer.index(hiraganaBuffer.startIndex, offsetBy: bufferOffset)
        hiraganaBuffer.replaceSubrange(bufIdx...bufIdx, with: String(cycle[nextIndex]))
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
                if bufferCursorPosition != nil {
                    deleteFromBuffer()
                } else {
                    hiraganaBuffer.removeLast()
                }
            }
        } else {
            // Different key or timeout expired → confirm previous, start new cycle
            confirmCurrentCycle()
            tapCycleIndex = 0
            lastTappedKeyCenter = key.center
            tapCycleChars = cycle
        }

        insertIntoBuffer(cycle[tapCycleIndex])
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

    // MARK: - Trackpad Cursor Movement

    func activateTrackpad() {
        confirmCurrentCycle()
        if !romajiConverter.displayText.isEmpty && hiraganaBuffer.isEmpty {
            hiraganaBuffer = romajiConverter.displayText
        }
        romajiConverter.reset()
        isTrackpadActive = true
        let combined = confirmedText + hiraganaBuffer
        if bufferCursorPosition == nil {
            bufferCursorPosition = combined.count
        }
    }

    func deactivateTrackpad() {
        isTrackpadActive = false
    }

    func moveBufferCursor(direction: CursorDirection) {
        let combined = confirmedText + hiraganaBuffer
        let pos = bufferCursorPosition ?? combined.count
        switch direction {
        case .left:
            if pos > 0 { bufferCursorPosition = pos - 1 }
        case .right:
            if pos < combined.count {
                let newPos = pos + 1
                bufferCursorPosition = newPos == combined.count ? nil : newPos
            }
        }
    }

    func resetCursorToEnd() {
        bufferCursorPosition = nil
    }

    private var effectiveCursorPosition: Int {
        bufferCursorPosition ?? (confirmedText.count + hiraganaBuffer.count)
    }

    private func insertIntoBuffer(_ text: String) {
        let pos = effectiveCursorPosition
        if bufferCursorPosition == nil {
            hiraganaBuffer += text
        } else if pos >= confirmedText.count {
            let idx = hiraganaBuffer.index(hiraganaBuffer.startIndex, offsetBy: pos - confirmedText.count)
            hiraganaBuffer.insert(contentsOf: text, at: idx)
            bufferCursorPosition = pos + text.count
        } else {
            let idx = confirmedText.index(confirmedText.startIndex, offsetBy: pos)
            confirmedText.insert(contentsOf: text, at: idx)
            bufferCursorPosition = pos + text.count
        }
    }

    private func deleteFromBuffer() {
        let pos = effectiveCursorPosition
        guard pos > 0 else { return }

        if pos > confirmedText.count {
            let bufIdx = pos - confirmedText.count - 1
            let idx = hiraganaBuffer.index(hiraganaBuffer.startIndex, offsetBy: bufIdx)
            hiraganaBuffer.remove(at: idx)
        } else {
            let idx = confirmedText.index(confirmedText.startIndex, offsetBy: pos - 1)
            confirmedText.remove(at: idx)
        }

        let newPos = pos - 1
        let totalLen = confirmedText.count + hiraganaBuffer.count
        bufferCursorPosition = newPos == totalLen ? nil : newPos
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
            if bufferCursorPosition != nil {
                deleteFromBuffer()
                suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
                if confirmedText.isEmpty && hiraganaBuffer.isEmpty {
                    suggestions = []
                    resetCursorToEnd()
                }
            } else if !hiraganaBuffer.isEmpty {
                hiraganaBuffer.removeLast()
                suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
            } else if !romajiConverter.displayText.isEmpty {
                romajiConverter.backspace()
                hiraganaBuffer = romajiConverter.displayText
                suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
            } else if !confirmedText.isEmpty {
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
        resetCursorToEnd()
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
            resetCursorToEnd()
            return
        }

        TextReplacementService.apply(suggestion: suggestion, to: proxy, mode: currentMode)
        suggestions = []
        if currentMode.isJapaneseInput {
            confirmedText = ""
            hiraganaBuffer = ""
            romajiConverter.reset()
        }
        resetCursorToEnd()
    }

    var textDocumentProxy: UITextDocumentProxy? {
        controller?.textDocumentProxy
    }
}
