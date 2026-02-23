import SwiftUI

struct ModeTabBarView: View {
    let currentMode: KeyboardMode
    let onSelect: (KeyboardMode) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(KeyboardMode.allCases) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    Text(mode.displayName)
                        .font(.system(size: 14, weight: mode == currentMode ? .bold : .regular))
                        .foregroundStyle(mode == currentMode ? .white : .primary)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(
                            mode == currentMode
                                ? Color.accentColor
                                : KeyboardColors.specialKey
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
    }
}
