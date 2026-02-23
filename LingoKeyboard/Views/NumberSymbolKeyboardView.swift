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
    private let page1Row2 = ["-","/",":",";","(",")","$","&","@","\""]
    private let page1Row3 = [".",",","?","!","'"]

    // Page 2: Additional symbols
    private let page2Row1 = ["[","]","{","}","#","%","^","*","+","="]
    private let page2Row2 = ["_","\\","|","~","<",">","€","£","¥","•"]
    private let page2Row3 = [".",",","?","!","'"]

    var body: some View {
        VStack(spacing: 8) {
            let rows = showPage2
                ? (page2Row1, page2Row2, page2Row3)
                : (page1Row1, page1Row2, page1Row3)

            charRow(rows.0)
            charRow(rows.1)

            HStack(spacing: 4) {
                togglePageButton
                charRow(rows.2, spacing: 4)
                backspaceButton
            }

            bottomRow
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 6)
    }

    private func charRow(_ keys: [String], spacing: CGFloat = 4) -> some View {
        HStack(spacing: spacing) {
            ForEach(keys, id: \.self) { key in
                Button(key) {
                    onChar(key)
                }
                .buttonStyle(KeyButtonStyle())
            }
        }
    }

    private var togglePageButton: some View {
        Button {
            showPage2.toggle()
        } label: {
            Text(showPage2 ? "123" : "#+=")
                .frame(width: 50, height: 42)
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
                Button(action: { onSwitchToLetters() }) {
                    Text("ABC")
                        .font(.system(size: 15))
                        .frame(width: kw, height: 42)
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

                Button(action: { onReturn() }) {
                    Text("確定")
                        .font(.system(size: 15))
                        .frame(width: confirmW, height: 42)
                        .background(KeyboardColors.specialKey)
                        .cornerRadius(5)
                        .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 42)
    }
}
