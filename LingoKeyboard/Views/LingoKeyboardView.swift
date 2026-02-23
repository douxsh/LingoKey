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
                    composingText: lingoState.hiraganaBuffer
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
        .background(KeyboardColors.background)
    }

    @ViewBuilder
    private var keyboardContent: some View {
        if lingoState.showEmojiPicker {
            EmojiPickerView(
                onEmoji: { lingoState.handleEmojiInput($0) },
                onBackspace: { lingoState.handleBackspace() },
                onDismiss: { lingoState.dismissEmojiPicker() }
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
        } else if lingoState.currentMode.isJapaneseInput && !lingoState.useRomajiInput {
            FlickKeyboardView(
                onKana: { lingoState.handleKana($0) },
                onModifierToggle: { lingoState.handleModifierToggle() },
                onBackspace: { lingoState.handleBackspace() },
                onSpace: { lingoState.handleSpace() },
                onReturn: { lingoState.handleReturn() },
                onToggleNumberKeyboard: { lingoState.toggleNumberKeyboard() },
                onSwitchToRomaji: { lingoState.switchToRomajiInput() },
                onToggleEmojiPicker: { lingoState.toggleEmojiPicker() }
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

    @State private var isShifted = false

    private let row1 = ["q","w","e","r","t","y","u","i","o","p"]
    private let row2 = ["a","s","d","f","g","h","j","k","l"]
    private let row3 = ["z","x","c","v","b","n","m"]

    var body: some View {
        VStack(spacing: 8) {
            keyRow(row1)
            keyRow(row2)
            HStack(spacing: 4) {
                shiftButton
                keyRow(row3, spacing: 4)
                backspaceButton
            }
            bottomRow
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 6)
    }

    private func keyRow(_ keys: [String], spacing: CGFloat = 4) -> some View {
        HStack(spacing: spacing) {
            ForEach(keys, id: \.self) { key in
                let display = isShifted ? key.uppercased() : key
                Button(display) {
                    onChar(display)
                    if isShifted { isShifted = false }
                }
                .buttonStyle(KeyButtonStyle())
            }
        }
    }

    private var shiftButton: some View {
        Button {
            isShifted.toggle()
        } label: {
            Image(systemName: isShifted ? "shift.fill" : "shift")
                .frame(width: 36, height: 42)
        }
        .buttonStyle(SpecialKeyStyle())
    }

    private var backspaceButton: some View {
        RepeatingButton(action: onBackspace) {
            Image(systemName: "delete.left")
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 42)
                .background(KeyboardColors.specialKey)
                .cornerRadius(5)
                .shadow(color: .black.opacity(0.15), radius: 0.5, y: 1)
        }
    }

    private var bottomRow: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let sp: CGFloat = 4
            let bsW: CGFloat = 36
            let kw = (totalWidth - bsW * 2 - sp * 8) / 7
            let confirmW = kw + sp + bsW   // m + backspace
            let spaceW = totalWidth - kw * 2 - confirmW - sp * 3

            HStack(spacing: sp) {
                // 123 / かな — z width
                bottomSpecialKey(
                    label: showKanaSwitch ? "かな" : "123",
                    width: kw
                ) {
                    if showKanaSwitch { onSwitchToKana?() }
                    else { onToggleNumberKeyboard() }
                }

                // 😊 — x width
                Button {
                    onToggleEmojiPicker?()
                } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 18))
                        .frame(width: kw, height: 42)
                        .background(KeyboardColors.specialKey)
                        .cornerRadius(5)
                        .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
                }
                .buttonStyle(.plain)

                // space — x〜n
                Button {
                    onSpace()
                } label: {
                    Text("space")
                        .font(.system(size: 15))
                        .frame(width: spaceW, height: 42)
                        .background(KeyboardColors.key)
                        .cornerRadius(5)
                        .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
                }
                .buttonStyle(.plain)

                // 確定 — m + backspace
                bottomSpecialKey(label: "確定", width: confirmW) {
                    onReturn()
                }
            }
        }
        .frame(height: 42)
    }

    private func bottomSpecialKey(label: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15))
                .frame(width: width, height: 42)
                .background(KeyboardColors.specialKey)
                .cornerRadius(5)
                .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Adaptive Keyboard Colors

/// Colors matching Apple's native keyboard appearance in both light and dark mode.
enum KeyboardColors {
    /// Main keyboard tray background.
    static let background = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.05, alpha: 1)
            : UIColor(red: 0.84, green: 0.85, blue: 0.87, alpha: 1)  // #D6D9DE
    })

    /// Regular letter key background.
    static let key = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.31, alpha: 1)
            : .white
    })

    /// Pressed / dragging state for regular keys.
    static let keyPressed = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.42, alpha: 1)
            : UIColor(red: 0.75, green: 0.76, blue: 0.78, alpha: 1)
    })

    /// Special key background (shift, backspace, 123, return, etc.).
    static let specialKey = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.16, alpha: 1)
            : UIColor(red: 0.73, green: 0.75, blue: 0.78, alpha: 1)  // #BAC0C7
    })

    /// Pressed state for special keys.
    static let specialKeyPressed = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.28, alpha: 1)
            : UIColor(red: 0.64, green: 0.66, blue: 0.69, alpha: 1)
    })
}

// MARK: - Key Styles

struct KeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 22))
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(configuration.isPressed ? KeyboardColors.keyPressed : KeyboardColors.key)
            .cornerRadius(5)
            .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
    }
}

struct SpecialKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15))
            .foregroundStyle(.primary)
            .frame(minHeight: 42)
            .background(configuration.isPressed ? KeyboardColors.specialKeyPressed : KeyboardColors.specialKey)
            .cornerRadius(5)
            .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
    }
}
