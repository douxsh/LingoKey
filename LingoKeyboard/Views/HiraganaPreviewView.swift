import SwiftUI

struct HiraganaPreviewView: View {
    let confirmedText: String
    let composingText: String

    var body: some View {
        HStack(spacing: 0) {
            if !confirmedText.isEmpty {
                Text(confirmedText)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
            }
            if !composingText.isEmpty {
                Text(composingText)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .underline()
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(KeyboardColors.specialKey.opacity(0.6))
        .cornerRadius(8)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}
