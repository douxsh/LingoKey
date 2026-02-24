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
        if suggestions.isEmpty && !isLoading {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.horizontal, 12)
                    }

                    ForEach(Array(conversions.enumerated()), id: \.element.id) { index, suggestion in
                        if index > 0 {
                            separator
                        }
                        candidateButton(suggestion)
                    }

                    if !conversions.isEmpty && !translations.isEmpty {
                        separator
                    }

                    ForEach(Array(translations.enumerated()), id: \.element.id) { index, suggestion in
                        if index > 0 || !conversions.isEmpty {
                            separator
                        }
                        candidateButton(suggestion)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 36)
        }
    }

    // MARK: - Components

    private func candidateButton(_ suggestion: Suggestion) -> some View {
        Button {
            onTap(suggestion)
        } label: {
            Text(suggestion.text)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.2))
            .frame(width: 0.5, height: 18)
    }
}
