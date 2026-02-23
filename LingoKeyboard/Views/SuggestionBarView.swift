import SwiftUI

struct SuggestionBarView: View {
    let suggestions: [Suggestion]
    let isLoading: Bool
    let onTap: (Suggestion) -> Void

    private var conversions: [Suggestion] {
        suggestions.filter { $0.kind == .conversion }
    }

    private var translations: [Suggestion] {
        suggestions.filter { $0.kind == .translation }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.horizontal)
                }

                ForEach(conversions) { suggestion in
                    suggestionPill(suggestion)
                }

                if !conversions.isEmpty && !translations.isEmpty {
                    Divider()
                        .frame(height: 20)
                }

                ForEach(translations) { suggestion in
                    suggestionPill(suggestion)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: suggestions.isEmpty && !isLoading ? 0 : 36)
        .animation(.easeInOut(duration: 0.2), value: suggestions.count)
    }

    private func suggestionPill(_ suggestion: Suggestion) -> some View {
        Button {
            onTap(suggestion)
        } label: {
            Text(suggestion.text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(KeyboardColors.key)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
