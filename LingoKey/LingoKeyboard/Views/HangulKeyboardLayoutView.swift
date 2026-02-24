import SwiftUI

struct HangulKeyboardLayoutView: View {
    let onChar: (String) -> Void
    let onBackspace: () -> Void
    let onSpace: () -> Void
    let onReturn: () -> Void
    let onToggleNumberKeyboard: () -> Void
    var onToggleEmojiPicker: (() -> Void)? = nil

    @State private var shiftState: ShiftState = .off
    @State private var lastShiftTapTime: Date? = nil

    // Standard 2벌식 layout
    private let row1      = ["ㅂ","ㅈ","ㄷ","ㄱ","ㅅ","ㅛ","ㅕ","ㅑ","ㅐ","ㅔ"]
    private let row1Keys  = ["q","w","e","r","t","y","u","i","o","p"]
    private let row1Shift = ["ㅃ","ㅉ","ㄸ","ㄲ","ㅆ","ㅛ","ㅕ","ㅑ","ㅒ","ㅖ"]
    private let row1ShiftKeys = ["Q","W","E","R","T","y","u","i","O","P"]

    private let row2      = ["ㅁ","ㄴ","ㅇ","ㄹ","ㅎ","ㅗ","ㅓ","ㅏ","ㅣ"]
    private let row2Keys  = ["a","s","d","f","g","h","j","k","l"]

    private let row3      = ["ㅋ","ㅌ","ㅊ","ㅍ","ㅠ","ㅜ","ㅡ"]
    private let row3Keys  = ["z","x","c","v","b","n","m"]

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
                keyRow(labels: shiftState.isUppercase ? row1Shift : row1,
                       keys: shiftState.isUppercase ? row1ShiftKeys : row1Keys,
                       keyWidth: kw)
                keyRow(labels: row2, keys: row2Keys, keyWidth: kw)

                HStack(spacing: ksp) {
                    shiftButton(width: sideW)
                    keyRow(labels: row3, keys: row3Keys, keyWidth: kw)
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

    private func keyRow(labels: [String], keys: [String], keyWidth: CGFloat) -> some View {
        HStack(spacing: ksp) {
            ForEach(Array(zip(labels, keys)), id: \.1) { label, key in
                HangulKeyView(label: label, width: keyWidth, height: keyH) {
                    onChar(key)
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
            Button(action: { onToggleNumberKeyboard() }) {
                Text("123")
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

// MARK: - Hangul Key View (with key pop bubble)

private struct HangulKeyView: View {
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
