import SwiftUI

struct SuggestionBarView: View {
    let suggestions: [Suggestion]
    let isLoading: Bool
    let onTap: (Suggestion) -> Void

    @State private var isExpanded = false

    private var conversions: [Suggestion] {
        suggestions.filter { $0.kind == .conversion }
    }

    private var translations: [Suggestion] {
        suggestions.filter { $0.kind == .translation }
    }

    var body: some View {
        if suggestions.isEmpty && !isLoading {
            EmptyView()
        } else if isExpanded {
            expandedView
        } else {
            compactBar
        }
    }

    // MARK: - Compact bar (Apple native style)

    private var compactBar: some View {
        HStack(spacing: 0) {
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

            // Chevron button to expand
            if !suggestions.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = true
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 36)
    }

    // MARK: - Expanded grid view

    private var expandedView: some View {
        VStack(spacing: 0) {
            // Top row with collapse chevron
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(conversions.prefix(5).enumerated()), id: \.element.id) { index, suggestion in
                            if index > 0 {
                                separator
                            }
                            candidateButton(suggestion)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 36)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 36)

            // Grid of remaining candidates
            let allCandidates = conversions + translations
            let remaining = Array(allCandidates.dropFirst(5))
            if !remaining.isEmpty {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 6)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(remaining) { suggestion in
                            Button {
                                onTap(suggestion)
                            } label: {
                                Text(suggestion.text)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 160)
            }
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
