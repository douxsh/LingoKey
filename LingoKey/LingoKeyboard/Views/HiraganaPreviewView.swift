import SwiftUI

struct HiraganaPreviewView: View {
    let confirmedText: String
    let composingText: String
    var cursorPosition: Int? = nil
    var isTrackpadActive: Bool = false
    var onCursorMove: ((LingoKeyboardState.CursorDirection) -> Void)? = nil
    var onTrackpadActivated: (() -> Void)? = nil
    var onTrackpadDeactivated: (() -> Void)? = nil

    @State private var cursorVisible: Bool = true
    @State private var blinkTimer: Timer?
    @State private var longPressTimer: Timer?
    @State private var isLongPressing = false
    @State private var trackpadAnchorX: CGFloat = 0
    @State private var accumulatedOffset: CGFloat = 0

    private let longPressThreshold: TimeInterval = 0.4
    private let cursorStepPt: CGFloat = 12

    var body: some View {
        HStack(spacing: 0) {
            if isTrackpadActive, let pos = cursorPosition {
                cursorTextView(pos: pos)
            } else {
                defaultTextView
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(KeyboardColors.specialKey.opacity(0.6))
        .cornerRadius(8)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isLongPressing && longPressTimer == nil {
                        trackpadAnchorX = value.location.x
                        accumulatedOffset = 0
                        longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressThreshold, repeats: false) { _ in
                            DispatchQueue.main.async {
                                isLongPressing = true
                                onTrackpadActivated?()
                            }
                        }
                    } else if isLongPressing {
                        let dx = value.location.x - trackpadAnchorX
                        let totalSteps = Int(dx / cursorStepPt)
                        let previousSteps = Int(accumulatedOffset / cursorStepPt)
                        let delta = totalSteps - previousSteps
                        if delta != 0 {
                            let direction: LingoKeyboardState.CursorDirection = delta > 0 ? .right : .left
                            for _ in 0..<abs(delta) {
                                onCursorMove?(direction)
                            }
                            accumulatedOffset = dx
                        }
                    }
                }
                .onEnded { _ in
                    if isLongPressing {
                        isLongPressing = false
                        onTrackpadDeactivated?()
                    }
                    longPressTimer?.invalidate()
                    longPressTimer = nil
                    accumulatedOffset = 0
                }
        )
        .onChange(of: isTrackpadActive) { _, active in
            if active { startBlinking() } else { stopBlinking() }
        }
        .onDisappear { stopBlinking() }
    }

    // MARK: - Default (no cursor)

    private var defaultTextView: some View {
        Group {
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
        }
    }

    // MARK: - Cursor view

    private func cursorTextView(pos: Int) -> some View {
        let combined = confirmedText + composingText
        let clampedPos = min(pos, combined.count)
        let beforeIdx = combined.index(combined.startIndex, offsetBy: clampedPos)
        let before = String(combined[combined.startIndex..<beforeIdx])
        let after = String(combined[beforeIdx..<combined.endIndex])

        return HStack(spacing: 0) {
            styledText(before, startingAt: 0)
            Text("|")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .opacity(cursorVisible ? 1 : 0)
            styledText(after, startingAt: clampedPos)
        }
    }

    /// Renders a substring with confirmed/composing styles.
    private func styledText(_ text: String, startingAt: Int) -> some View {
        let confirmedLen = confirmedText.count
        return ForEach(Array(text.enumerated()), id: \.offset) { offset, char in
            let globalPos = startingAt + offset
            if globalPos < confirmedLen {
                Text(String(char))
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
            } else {
                Text(String(char))
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .underline()
            }
        }
    }

    // MARK: - Blink

    private func startBlinking() {
        cursorVisible = true
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async { cursorVisible.toggle() }
        }
    }

    private func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        cursorVisible = true
    }
}
