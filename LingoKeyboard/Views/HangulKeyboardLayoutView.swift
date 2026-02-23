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

    var body: some View {
        VStack(spacing: 8) {
            keyRow(labels: isShifted ? row1Shift : row1,
                   keys: isShifted ? row1ShiftKeys : row1Keys)
            keyRow(labels: row2, keys: row2Keys)

            HStack(spacing: 4) {
                shiftButton
                keyRow(labels: row3, keys: row3Keys, spacing: 4)
                backspaceButton
            }

            bottomRow
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 6)
    }

    private func keyRow(labels: [String], keys: [String], spacing: CGFloat = 4) -> some View {
        HStack(spacing: spacing) {
            ForEach(Array(zip(labels, keys)), id: \.1) { label, key in
                Button(label) {
                    onChar(key)
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
                .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
        }
    }

    private var bottomRow: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let sp: CGFloat = 4
            let bsW: CGFloat = 36
            let kw = (totalWidth - bsW * 2 - sp * 8) / 7
            let confirmW = kw + sp + bsW
            let spaceW = totalWidth - kw * 2 - confirmW - sp * 3

            HStack(spacing: sp) {
                bottomSpecialKey(label: "123", width: kw) {
                    onToggleNumberKeyboard()
                }

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
