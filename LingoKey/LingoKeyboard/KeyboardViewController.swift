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
    struct EnglishAutoCorrectionRecord {
        let originalWord: String
        let correctedWord: String
        let delimiter: String
    }

    struct JapaneseAutoConversionRecord {
        let previousConfirmedText: String
        let originalComposing: String
        let convertedText: String
    }

    var currentMode: KeyboardMode = .enCorrection
    var autoCorrectionLevel: AutoCorrectionLevel = .conservative
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
    @ObservationIgnored private let englishTextChecker = UITextChecker()
    @ObservationIgnored private var pendingEnglishAutoCorrection: EnglishAutoCorrectionRecord?
    @ObservationIgnored private var pendingJapaneseAutoConversion: JapaneseAutoConversionRecord?
    @ObservationIgnored private let englishAutoCorrectionDelimiters: Set<String> = [".", ",", "!", "?", ";", ":"]

    init(controller: KeyboardViewController?) {
        self.controller = controller
    }

    func loadSettings() {
        let settings = SharedSettings()
        if let mode = KeyboardMode(rawValue: settings.defaultMode) {
            currentMode = mode
        }
        if let level = AutoCorrectionLevel(rawValue: settings.autoCorrectionLevel) {
            autoCorrectionLevel = level
        } else {
            autoCorrectionLevel = .conservative
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
        pendingEnglishAutoCorrection = nil
        pendingJapaneseAutoConversion = nil
    }

    // MARK: - Number Keyboard

    func toggleNumberKeyboard() {
        showNumberKeyboard = true
    }

    func switchToLetterKeyboard() {
        showNumberKeyboard = false
    }

    func handleNumberSymbolChar(_ char: String) {
        HapticManager.keyTap()
        guard let proxy = controller?.textDocumentProxy else { return }
        if currentMode == .enCorrection && englishAutoCorrectionDelimiters.contains(char) {
            if applyEnglishAutoCorrectionBeforeDelimiter(proxy: proxy, delimiter: char) {
                suggestionManager.textDidChange(proxy: proxy)
                return
            }
            pendingEnglishAutoCorrection = nil
        }
        proxy.insertText(char)
        if currentMode == .enCorrection {
            suggestionManager.textDidChange(proxy: proxy)
        }
    }

    // MARK: - Emoji Picker

    func toggleEmojiPicker() {
        showEmojiPicker = true
    }

    func dismissEmojiPicker() {
        showEmojiPicker = false
    }

    func handleEmojiInput(_ emoji: String) {
        HapticManager.keyTap()
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
        HapticManager.keyTap()
        if currentMode.isJapaneseInput {
            pendingJapaneseAutoConversion = nil
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
        HapticManager.keyTap()
        guard let proxy = controller?.textDocumentProxy else { return }

        switch currentMode {
        case .enCorrection:
            pendingEnglishAutoCorrection = nil
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
            pendingJapaneseAutoConversion = nil
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
        HapticManager.keyTap()
        pendingJapaneseAutoConversion = nil
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
        pendingJapaneseAutoConversion = nil
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
        HapticManager.keyTap()
        pendingJapaneseAutoConversion = nil
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
        HapticManager.specialKeyTap()
        confirmCurrentCycle()
        guard let proxy = controller?.textDocumentProxy else { return }

        switch currentMode {
        case .enCorrection:
            if undoLastEnglishAutoCorrectionIfPossible(proxy: proxy) {
                suggestionManager.textDidChange(proxy: proxy)
                return
            }
            pendingEnglishAutoCorrection = nil
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
            if undoLastJapaneseAutoConversionIfPossible() {
                suggestionManager.hiraganaBufferDidChange(buffer: hiraganaBuffer)
            } else if bufferCursorPosition != nil {
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
        HapticManager.specialKeyTap()
        confirmCurrentCycle()
        guard let proxy = controller?.textDocumentProxy else { return }

        switch currentMode {
        case .enCorrection, .krCorrection:
            if currentMode == .enCorrection {
                if applyEnglishAutoCorrectionBeforeDelimiter(proxy: proxy, delimiter: " ") {
                    suggestionManager.textDidChange(proxy: proxy)
                    return
                }
                pendingEnglishAutoCorrection = nil
            }
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
        HapticManager.specialKeyTap()
        confirmCurrentCycle()
        guard let proxy = controller?.textDocumentProxy else { return }

        if currentMode == .enCorrection {
            if applyEnglishAutoCorrectionBeforeDelimiter(proxy: proxy, delimiter: "\n") {
                suggestionManager.textDidChange(proxy: proxy)
                return
            }
            pendingEnglishAutoCorrection = nil
        }
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
            // --- Composing text exists: auto-convert first candidate if enabled ---
            romajiConverter.reset()
            let previousConfirmedText = confirmedText
            if let autoConverted = preferredJapaneseAutoConversion(for: composing) {
                confirmedText += autoConverted
                pendingJapaneseAutoConversion = JapaneseAutoConversionRecord(
                    previousConfirmedText: previousConfirmedText,
                    originalComposing: composing,
                    convertedText: autoConverted
                )
            } else {
                confirmedText += composing
                pendingJapaneseAutoConversion = nil
            }
            hiraganaBuffer = ""
            suggestions = []
        } else if !confirmedText.isEmpty {
            // --- All text confirmed, no composing: translate ---
            // If auto-translation already provided results, use them directly
            pendingJapaneseAutoConversion = nil
            let existingTranslations = suggestions.filter { $0.kind == .translation }
            if !existingTranslations.isEmpty {
                suggestions = existingTranslations
                confirmedText = ""
                hiraganaBuffer = ""
                romajiConverter.reset()
            } else {
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
            pendingJapaneseAutoConversion = nil
            resetCursorToEnd()
            return
        }

        TextReplacementService.apply(suggestion: suggestion, to: proxy, mode: currentMode)
        pendingEnglishAutoCorrection = nil
        suggestions = []
        if currentMode.isJapaneseInput {
            confirmedText = ""
            hiraganaBuffer = ""
            romajiConverter.reset()
            pendingJapaneseAutoConversion = nil
        }
        resetCursorToEnd()
    }

    // MARK: - Local Auto Correction

    private func applyEnglishAutoCorrectionBeforeDelimiter(
        proxy: UITextDocumentProxy,
        delimiter: String
    ) -> Bool {
        guard currentMode == .enCorrection, autoCorrectionLevel != .off else { return false }
        guard let before = proxy.documentContextBeforeInput, !before.isEmpty else { return false }
        guard let originalWord = extractLastEnglishWord(from: before) else { return false }

        let fullRange = NSRange(location: 0, length: originalWord.utf16.count)
        let misspelledRange = englishTextChecker.rangeOfMisspelledWord(
            in: originalWord,
            range: fullRange,
            startingAt: 0,
            wrap: false,
            language: "en_US"
        )
        guard misspelledRange.location != NSNotFound else { return false }

        guard let guesses = englishTextChecker.guesses(
            forWordRange: misspelledRange,
            in: originalWord,
            language: "en_US"
        ), !guesses.isEmpty else { return false }

        guard let corrected = bestEnglishGuess(for: originalWord, guesses: guesses) else { return false }
        guard corrected.caseInsensitiveCompare(originalWord) != .orderedSame else { return false }

        for _ in 0..<originalWord.count {
            proxy.deleteBackward()
        }
        proxy.insertText(corrected)
        proxy.insertText(delimiter)

        pendingEnglishAutoCorrection = EnglishAutoCorrectionRecord(
            originalWord: originalWord,
            correctedWord: corrected,
            delimiter: delimiter
        )
        return true
    }

    private func undoLastEnglishAutoCorrectionIfPossible(proxy: UITextDocumentProxy) -> Bool {
        guard let pending = pendingEnglishAutoCorrection else { return false }
        let before = proxy.documentContextBeforeInput ?? ""
        let expectedSuffix = pending.correctedWord + pending.delimiter
        guard before.hasSuffix(expectedSuffix) else {
            pendingEnglishAutoCorrection = nil
            return false
        }

        for _ in 0..<expectedSuffix.count {
            proxy.deleteBackward()
        }
        proxy.insertText(pending.originalWord)
        pendingEnglishAutoCorrection = nil
        return true
    }

    private func preferredJapaneseAutoConversion(for composing: String) -> String? {
        guard autoCorrectionLevel != .off else { return nil }
        guard composing.contains(where: \.isHiragana) else { return nil }

        let currentConversions = suggestions
            .filter { $0.kind == .conversion }
            .map(\.text)
        let localConversions = currentConversions.isEmpty
            ? localConverter.convert(composing, maxResults: 1)
            : currentConversions

        guard let best = localConversions.first else { return nil }
        guard best != composing else { return nil }

        if autoCorrectionLevel == .conservative {
            let delta = abs(best.count - composing.count)
            guard delta <= 2 else { return nil }
        }
        return best
    }

    private func undoLastJapaneseAutoConversionIfPossible() -> Bool {
        guard let pending = pendingJapaneseAutoConversion else { return false }
        guard bufferCursorPosition == nil else { return false }
        guard hiraganaBuffer.isEmpty else { return false }
        guard confirmedText == pending.previousConfirmedText + pending.convertedText else {
            pendingJapaneseAutoConversion = nil
            return false
        }

        confirmedText = pending.previousConfirmedText
        hiraganaBuffer = pending.originalComposing
        pendingJapaneseAutoConversion = nil
        return true
    }

    private func extractLastEnglishWord(from text: String) -> String? {
        guard !text.isEmpty else { return nil }
        var end = text.endIndex
        while end > text.startIndex {
            let prev = text.index(before: end)
            if text[prev].isWhitespace {
                end = prev
            } else {
                break
            }
        }
        guard end > text.startIndex else { return nil }

        var start = end
        while start > text.startIndex {
            let prev = text.index(before: start)
            if isEnglishWordCharacter(text[prev]) {
                start = prev
            } else {
                break
            }
        }

        let word = String(text[start..<end])
        guard word.count >= 2 else { return nil }
        guard word.unicodeScalars.contains(where: { isEnglishLetter($0) }) else { return nil }
        guard word.unicodeScalars.allSatisfy({ isEnglishLetter($0) || $0.value == 39 }) else { return nil }
        return word
    }

    private func isEnglishWordCharacter(_ char: Character) -> Bool {
        char.unicodeScalars.allSatisfy { isEnglishLetter($0) || $0.value == 39 }
    }

    private func isEnglishLetter(_ scalar: UnicodeScalar) -> Bool {
        (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
    }

    private func bestEnglishGuess(for originalWord: String, guesses: [String]) -> String? {
        let originalLower = originalWord.lowercased()
        let maxDistance: Int
        switch autoCorrectionLevel {
        case .off:
            return nil
        case .conservative:
            maxDistance = 1
        case .aggressive:
            maxDistance = max(2, originalWord.count / 3)
        }

        let ranked = guesses
            .filter { !$0.isEmpty }
            .compactMap { guess -> (String, Int)? in
                guard guess.unicodeScalars.allSatisfy({ isEnglishLetter($0) || $0.value == 39 }) else {
                    return nil
                }
                let distance = editDistance(originalLower, guess.lowercased())
                return (guess, distance)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.count < rhs.0.count
            }

        guard let selected = ranked.first(where: { $0.1 <= maxDistance })?.0 else { return nil }
        return normalizedGuessCase(selected, originalWord: originalWord)
    }

    private func normalizedGuessCase(_ guess: String, originalWord: String) -> String {
        if originalWord == "i" || originalWord == "I" {
            return "I"
        }
        if originalWord == originalWord.uppercased(), originalWord.count > 1 {
            return guess.uppercased()
        }
        if let first = originalWord.first,
           String(first) == String(first).uppercased(),
           String(originalWord.dropFirst()) == String(originalWord.dropFirst()).lowercased() {
            return guess.prefix(1).uppercased() + guess.dropFirst().lowercased()
        }
        return guess.lowercased()
    }

    private func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        if lhsChars.isEmpty { return rhsChars.count }
        if rhsChars.isEmpty { return lhsChars.count }

        var previous = Array(0...rhsChars.count)
        for (i, lch) in lhsChars.enumerated() {
            var current = Array(repeating: 0, count: rhsChars.count + 1)
            current[0] = i + 1
            for (j, rch) in rhsChars.enumerated() {
                let cost = lch == rch ? 0 : 1
                current[j + 1] = min(
                    previous[j + 1] + 1,
                    current[j] + 1,
                    previous[j] + cost
                )
            }
            previous = current
        }
        return previous[rhsChars.count]
    }

    var textDocumentProxy: UITextDocumentProxy? {
        controller?.textDocumentProxy
    }
}
