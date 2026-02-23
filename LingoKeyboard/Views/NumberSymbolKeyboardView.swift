import SwiftUI

struct NumberSymbolKeyboardView: View {
    let onChar: (String) -> Void
    let onBackspace: () -> Void
    let onSpace: () -> Void
    let onReturn: () -> Void
    let onSwitchToLetters: () -> Void
    var onToggleEmojiPicker: (() -> Void)? = nil

    @State private var showPage2 = false

    // Page 1: Numbers + common symbols
    private let page1Row1 = ["1","2","3","4","5","6","7","8","9","0"]
    private let page1Row2 = ["-","/",":",";","(",")","\u{0024}","&","@","\""]
    private let page1Row3 = [".",",","?","!","'"]

    // Page 2: Additional symbols
    private let page2Row1 = ["[","]","{","}","#","%","^","*","+","="]
    private let page2Row2 = ["_","\\","|","~","<",">","€","£","¥","•"]
    private let page2Row3 = [".",",","?","!","'"]

    private let ksp: CGFloat = 6
    private let rsp: CGFloat = 11
    private let hPad: CGFloat = 3
    private let keyH: CGFloat = 42

    var body: some View {
        GeometryReader { geo in
            let aw = geo.size.width - hPad * 2
            let kw = (aw - ksp * 9) / 10
            let sideW = (aw - kw * 5 - ksp * 6) / 2

            let rows = showPage2
                ? (page2Row1, page2Row2, page2Row3)
                : (page1Row1, page1Row2, page1Row3)

            VStack(spacing: rsp) {
                charRow(rows.0, keyWidth: kw)
                charRow(rows.1, keyWidth: kw)

                HStack(spacing: ksp) {
                    togglePageButton(width: sideW)
                    charRow(rows.2, keyWidth: kw)
                    backspaceBtn(width: sideW)
                }

                bottomRow(keyWidth: kw, sideWidth: sideW, availableWidth: aw)
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, 4)
        }
        .frame(height: keyH * 4 + rsp * 3 + 8)
    }

    private func charRow(_ keys: [String], keyWidth: CGFloat) -> some View {
        HStack(spacing: ksp) {
            ForEach(keys, id: \.self) { key in
                Button(key) {
                    onChar(key)
                }
                .buttonStyle(KeyButtonStyle())
                .frame(width: keyWidth)
            }
        }
    }

    private func togglePageButton(width: CGFloat) -> some View {
        Button {
            showPage2.toggle()
        } label: {
            Text(showPage2 ? "123" : "#+=")
                .font(.system(size: 15))
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
            Button(action: { onSwitchToLetters() }) {
                Text("ABC")
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
                    .background(Color.accentColor)
                    .cornerRadius(5)
                    .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
            }
            .buttonStyle(.plain)
        }
    }
}
