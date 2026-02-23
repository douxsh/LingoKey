import SwiftUI

struct HangulKeyboardLayoutView: View {
    let onChar: (String) -> Void
    let onBackspace: () -> Void
    let onSpace: () -> Void
    let onReturn: () -> Void
    let onToggleNumberKeyboard: () -> Void
    var onToggleEmojiPicker: (() -> Void)? = nil

    @State private var isShifted = false

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
    private let hPad: CGFloat = 3
    private let keyH: CGFloat = 42

    var body: some View {
        GeometryReader { geo in
            let aw = geo.size.width - hPad * 2
            let kw = (aw - ksp * 9) / 10
            let sideW = (aw - kw * 7 - ksp * 8) / 2

            VStack(spacing: rsp) {
                keyRow(labels: isShifted ? row1Shift : row1,
                       keys: isShifted ? row1ShiftKeys : row1Keys,
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
            .padding(.vertical, 4)
        }
        .frame(height: keyH * 4 + rsp * 3 + 8)
    }

    private func keyRow(labels: [String], keys: [String], keyWidth: CGFloat) -> some View {
        HStack(spacing: ksp) {
            ForEach(Array(zip(labels, keys)), id: \.1) { label, key in
                Button(label) {
                    onChar(key)
                    if isShifted { isShifted = false }
                }
                .buttonStyle(KeyButtonStyle())
                .frame(width: keyWidth)
            }
        }
    }

    private func shiftButton(width: CGFloat) -> some View {
        Button {
            isShifted.toggle()
        } label: {
            Image(systemName: isShifted ? "shift.fill" : "shift")
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .frame(width: width, height: keyH)
                .background(KeyboardColors.specialKey)
                .cornerRadius(5)
                .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func backspaceBtn(width: CGFloat) -> some View {
        RepeatingButton(action: onBackspace) {
            Image(systemName: "delete.left")
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .frame(width: width, height: keyH)
                .background(KeyboardColors.specialKey)
                .cornerRadius(5)
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
                    .background(KeyboardColors.specialKey)
                    .cornerRadius(5)
                    .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
            }
            .buttonStyle(.plain)

            Button {
                onToggleEmojiPicker?()
            } label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 18))
                    .frame(width: keyWidth, height: keyH)
                    .background(KeyboardColors.specialKey)
                    .cornerRadius(5)
                    .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
            }
            .buttonStyle(.plain)

            Button {
                onSpace()
            } label: {
                Text("")
                    .frame(width: spaceW, height: keyH)
                    .background(KeyboardColors.key)
                    .cornerRadius(5)
                    .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
            }
            .buttonStyle(.plain)

            Button(action: { onReturn() }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: confirmW, height: keyH)
                    .background(KeyboardColors.confirm)
                    .cornerRadius(5)
                    .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
            }
            .buttonStyle(.plain)
        }
    }
}
