import SwiftUI
import KeyboardKit

struct LingoKeyboardView: View {
    let state: Keyboard.State
    @Bindable var lingoState: LingoKeyboardState

    var body: some View {
        VStack(spacing: 0) {
            // Suggestion bar
            SuggestionBarView(
                suggestions: lingoState.suggestions,
                isLoading: lingoState.isLoading,
                onTap: { lingoState.applySuggestion($0) }
            )

            // Hiragana preview (JP modes only)
            if lingoState.currentMode.isJapaneseInput &&
                (!lingoState.confirmedText.isEmpty || !lingoState.hiraganaBuffer.isEmpty) {
                HiraganaPreviewView(
                    confirmedText: lingoState.confirmedText,
                    composingText: lingoState.hiraganaBuffer,
                    cursorPosition: lingoState.bufferCursorPosition,
                    isTrackpadActive: lingoState.isTrackpadActive,
                    onCursorMove: { lingoState.moveBufferCursor(direction: $0) },
                    onTrackpadActivated: { lingoState.activateTrackpad() },
                    onTrackpadDeactivated: { lingoState.deactivateTrackpad() }
                )
            }

            // Mode tab bar
            ModeTabBarView(
                currentMode: lingoState.currentMode,
                onSelect: { lingoState.switchMode($0) }
            )

            // Keyboard layout
            keyboardContent
        }
    }

    @ViewBuilder
    private var keyboardContent: some View {
        if lingoState.showEmojiPicker {
            EmojiPickerView(
                onEmoji: { lingoState.handleEmojiInput($0) },
                onBackspace: { lingoState.handleBackspace() },
                onDismiss: { lingoState.dismissEmojiPicker() },
                dismissLabel: lingoState.currentMode.isJapaneseInput && !lingoState.useRomajiInput
                    ? "あいう"
                    : "ABC"
            )
        } else if lingoState.showNumberKeyboard {
            NumberSymbolKeyboardView(
                onChar: { lingoState.handleNumberSymbolChar($0) },
                onBackspace: { lingoState.handleBackspace() },
                onSpace: { lingoState.handleSpace() },
                onReturn: { lingoState.handleReturn() },
                onSwitchToLetters: { lingoState.switchToLetterKeyboard() },
                onToggleEmojiPicker: { lingoState.toggleEmojiPicker() }
            )
        } else if lingoState.currentMode == .krCorrection {
            HangulKeyboardLayoutView(
                onChar: { lingoState.handleCharacter($0) },
                onBackspace: { lingoState.handleBackspace() },
                onSpace: { lingoState.handleSpace() },
                onReturn: { lingoState.handleReturn() },
                onToggleNumberKeyboard: { lingoState.toggleNumberKeyboard() },
                onToggleEmojiPicker: { lingoState.toggleEmojiPicker() }
            )
        } else if lingoState.currentMode.isJapaneseInput && !lingoState.useRomajiInput && lingoState.flickSubKeyboard == .english {
            EnglishFlickKeyboardView(
                onChar: { lingoState.handleFlickDirectChar($0) },
                onBackspace: { lingoState.handleBackspace() },
                onSpace: { lingoState.handleSpace() },
                onReturn: { lingoState.handleReturn() },
                onSwitchToNumberFlick: { lingoState.switchToNumberFlick() },
                onSwitchToKana: { lingoState.switchToKanaFlick() },
                onToggleEmojiPicker: { lingoState.toggleEmojiPicker() }
            )
        } else if lingoState.currentMode.isJapaneseInput && !lingoState.useRomajiInput && lingoState.flickSubKeyboard == .number {
            NumberFlickKeyboardView(
                onChar: { lingoState.handleFlickDirectChar($0) },
                onBackspace: { lingoState.handleBackspace() },
                onSpace: { lingoState.handleSpace() },
                onReturn: { lingoState.handleReturn() },
                onSwitchToKana: { lingoState.switchToKanaFlick() },
                onToggleEmojiPicker: { lingoState.toggleEmojiPicker() }
            )
        } else if lingoState.currentMode.isJapaneseInput && !lingoState.useRomajiInput {
            FlickKeyboardView(
                onKana: { lingoState.handleKana($0) },
                onKanaTap: { lingoState.handleKanaTap($0) },
                onModifierToggle: { lingoState.handleModifierToggle() },
                onBackspace: { lingoState.handleBackspace() },
                onSpace: { lingoState.handleSpace() },
                onReturn: { lingoState.handleReturn() },
                onSwitchToRomaji: { lingoState.switchToEnglishFlick() },
                onAdvanceCursor: { lingoState.handleAdvanceCursor() },
                onUndoKana: { lingoState.handleUndoKana() },
                onToggleEmojiPicker: { lingoState.toggleEmojiPicker() },
                isComposing: !lingoState.hiraganaBuffer.isEmpty,
                onCursorMove: { lingoState.moveBufferCursor(direction: $0) },
                onTrackpadActivated: { lingoState.activateTrackpad() },
                onTrackpadDeactivated: { lingoState.deactivateTrackpad() },
                isTrackpadActive: lingoState.isTrackpadActive,
                hasBufferContent: !lingoState.confirmedText.isEmpty || !lingoState.hiraganaBuffer.isEmpty,
                hiraganaBuffer: lingoState.hiraganaBuffer
            )
        } else {
            QwertyKeyboardView(
                onChar: { lingoState.handleCharacter($0) },
                onBackspace: { lingoState.handleBackspace() },
                onSpace: { lingoState.handleSpace() },
                onReturn: { lingoState.handleReturn() },
                onToggleNumberKeyboard: { lingoState.toggleNumberKeyboard() },
                onToggleEmojiPicker: { lingoState.toggleEmojiPicker() },
                showKanaSwitch: lingoState.currentMode.isJapaneseInput && lingoState.useRomajiInput,
                onSwitchToKana: { lingoState.switchToFlickInput() }
            )
        }
    }
}

// MARK: - Shift State

enum ShiftState {
    case off, shift, capsLock

    var icon: String {
        switch self {
        case .off: return "shift"
        case .shift: return "shift.fill"
        case .capsLock: return "capslock.fill"
        }
    }

    var isUppercase: Bool {
        self != .off
    }
}

// MARK: - QWERTY Keyboard

struct QwertyKeyboardView: View {
    let onChar: (String) -> Void
    let onBackspace: () -> Void
    let onSpace: () -> Void
    let onReturn: () -> Void
    let onToggleNumberKeyboard: () -> Void
    var onToggleEmojiPicker: (() -> Void)? = nil
    var showKanaSwitch: Bool = false
    var onSwitchToKana: (() -> Void)? = nil

    @State private var shiftState: ShiftState = .off
    @State private var lastShiftTapTime: Date? = nil

    private let row1 = ["q","w","e","r","t","y","u","i","o","p"]
    private let row2 = ["a","s","d","f","g","h","j","k","l"]
    private let row3 = ["z","x","c","v","b","n","m"]

    private let ksp: CGFloat = 6
    private let rsp: CGFloat = 11
    private let hPad: CGFloat = 5
    private let keyH: CGFloat = 43

    var body: some View {
        GeometryReader { geo in
            let aw = geo.size.width - hPad * 2
            let kw = (aw - ksp * 9) / 10
            let sideW = (aw - kw * 7 - ksp * 8) / 2

            VStack(spacing: rsp) {
                letterRow(row1, keyWidth: kw)
                letterRow(row2, keyWidth: kw)
                HStack(spacing: ksp) {
                    shiftButton(width: sideW)
                    letterRow(row3, keyWidth: kw)
                    backspaceBtn(width: sideW)
                }
                bottomRow(keyWidth: kw, sideWidth: sideW, availableWidth: aw)
            }
            .padding(.horizontal, hPad)
            .padding(.top, 4)
            .padding(.bottom, 0)
        }
        .frame(height: keyH * 4 + rsp * 3 + 4)
    }

    private func letterRow(_ keys: [String], keyWidth: CGFloat) -> some View {
        HStack(spacing: ksp) {
            ForEach(keys, id: \.self) { key in
                let display = shiftState.isUppercase ? key.uppercased() : key
                QwertyKeyView(label: display, width: keyWidth, height: keyH) {
                    onChar(display)
                    if shiftState == .shift { shiftState = .off }
                }
            }
        }
    }

    private func shiftButton(width: CGFloat) -> some View {
        Button {
            HapticManager.specialKeyTap()
            let now = Date()
            if let last = lastShiftTapTime, now.timeIntervalSince(last) < 0.3 {
                shiftState = .capsLock
                lastShiftTapTime = nil
            } else if shiftState == .capsLock {
                shiftState = .off
                lastShiftTapTime = nil
            } else {
                shiftState = shiftState == .off ? .shift : .off
                lastShiftTapTime = now
            }
        } label: {
            Image(systemName: shiftState.icon)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .frame(width: width, height: keyH)
        }
        .buttonStyle(SpecialKeyStyle())
    }

    private func backspaceBtn(width: CGFloat) -> some View {
        RepeatingButton(action: onBackspace) { pressed in
            Image(systemName: "delete.left")
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .frame(width: width, height: keyH)
                .background(pressed ? KeyboardColors.specialKeyPressed : KeyboardColors.specialKey)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
        }
    }

    private func bottomRow(keyWidth: CGFloat, sideWidth: CGFloat, availableWidth: CGFloat) -> some View {
        let confirmW = keyWidth + ksp + sideWidth
        let spaceW = availableWidth - keyWidth * 2 - confirmW - ksp * 3

        return HStack(spacing: ksp) {
            Button(action: {
                if showKanaSwitch { onSwitchToKana?() }
                else { onToggleNumberKeyboard() }
            }) {
                Text(showKanaSwitch ? "かな" : "123")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .frame(width: keyWidth, height: keyH)
            }
            .buttonStyle(SpecialKeyStyle())

            Button {
                onToggleEmojiPicker?()
            } label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 18))
                    .frame(width: keyWidth, height: keyH)
            }
            .buttonStyle(SpecialKeyStyle())

            Button {
                onSpace()
            } label: {
                Text("")
                    .frame(width: spaceW, height: keyH)
            }
            .buttonStyle(KeyButtonStyle())

            Button(action: { onReturn() }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: confirmW, height: keyH)
            }
            .buttonStyle(ConfirmKeyStyle())
        }
    }
}

// MARK: - Adaptive Keyboard Colors

/// Colors matching Apple's native keyboard appearance in both light and dark mode.
enum KeyboardColors {
    /// Main keyboard tray background.
    static let background = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.05, alpha: 1)
            : UIColor(red: 0.867, green: 0.875, blue: 0.890, alpha: 1)  // #DDDFE3
    })

    /// Regular letter key background.
    static let key = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 145.0/255.0, green: 145.0/255.0, blue: 147.0/255.0, alpha: 0.4)  // #919193 半透明
            : .white
    })

    /// Pressed / dragging state for regular keys.
    static let keyPressed = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 145.0/255.0, green: 145.0/255.0, blue: 147.0/255.0, alpha: 0.25)  // #919193 pressed
            : UIColor(red: 0.75, green: 0.76, blue: 0.78, alpha: 1)
    })

    /// Special key background (shift, backspace, 123, return, etc.) — same as regular keys.
    static let specialKey = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 145.0/255.0, green: 145.0/255.0, blue: 147.0/255.0, alpha: 0.4)  // #919193 半透明
            : UIColor(red: 0.73, green: 0.75, blue: 0.78, alpha: 1)  // #BAC0C7
    })

    /// Pressed state for special keys — same as regular keys.
    static let specialKeyPressed = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 145.0/255.0, green: 145.0/255.0, blue: 147.0/255.0, alpha: 0.25)  // #919193 pressed
            : UIColor(red: 0.64, green: 0.66, blue: 0.69, alpha: 1)
    })

    /// Confirm button blue — Apple system blue #007AFF.
    static let confirm = Color(red: 0, green: 122.0/255.0, blue: 255.0/255.0)

    /// Pressed state for confirm button — slightly darker blue.
    static let confirmPressed = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0, green: 90.0/255.0, blue: 200.0/255.0, alpha: 1)
            : UIColor(red: 0, green: 100.0/255.0, blue: 210.0/255.0, alpha: 1)
    })
}

// MARK: - Key Styles

struct KeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 22))
            .frame(maxWidth: .infinity, minHeight: 43)
            .background(configuration.isPressed ? KeyboardColors.keyPressed : KeyboardColors.key)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct SpecialKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15))
            .foregroundStyle(.primary)
            .frame(minHeight: 43)
            .background(configuration.isPressed ? KeyboardColors.specialKeyPressed : KeyboardColors.specialKey)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct ConfirmKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minHeight: 43)
            .background(configuration.isPressed ? KeyboardColors.confirmPressed : KeyboardColors.confirm)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - QWERTY Key View (with key pop bubble)

struct QwertyKeyView: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Text(label)
            .font(.system(size: 22))
            .frame(width: width, height: height)
            .background(isPressed ? KeyboardColors.keyPressed : KeyboardColors.key)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: isPressed)
            .overlay(alignment: .top) {
                if isPressed {
                    Text(label)
                        .font(.system(size: 32, weight: .medium))
                        .frame(width: width + 12, height: height + 16)
                        .background(KeyboardColors.key)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: -2)
                        .offset(y: -(height + 12))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed { isPressed = true }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onTap()
                    }
            )
    }
}
