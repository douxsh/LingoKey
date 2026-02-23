import SwiftUI

/// A space bar that doubles as a trackpad when long-pressed.
/// Short tap → normal space. Long-press (0.4s) with buffer content → trackpad mode.
struct TrackpadSpaceBar<Label: View>: View {
    let onSpace: () -> Void
    let onCursorMove: (LingoKeyboardState.CursorDirection) -> Void
    let onTrackpadActivated: () -> Void
    let onTrackpadDeactivated: () -> Void
    let hasBufferContent: Bool
    let isTrackpadActive: Bool
    @ViewBuilder let label: () -> Label

    @State private var longPressTimer: Timer?
    @State private var isLongPressing = false
    @State private var trackpadAnchorX: CGFloat = 0
    @State private var accumulatedOffset: CGFloat = 0

    private let longPressThreshold: TimeInterval = 0.4
    private let cursorStepPt: CGFloat = 12

    var body: some View {
        label()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isLongPressing && longPressTimer == nil {
                            // Touch just started
                            if hasBufferContent {
                                trackpadAnchorX = value.location.x
                                accumulatedOffset = 0
                                longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressThreshold, repeats: false) { _ in
                                    DispatchQueue.main.async {
                                        isLongPressing = true
                                        onTrackpadActivated()
                                    }
                                }
                            }
                        } else if isLongPressing {
                            // In trackpad mode — track horizontal movement
                            let dx = value.location.x - trackpadAnchorX
                            let totalSteps = Int(dx / cursorStepPt)
                            let previousSteps = Int(accumulatedOffset / cursorStepPt)
                            let delta = totalSteps - previousSteps
                            if delta != 0 {
                                let direction: LingoKeyboardState.CursorDirection = delta > 0 ? .right : .left
                                for _ in 0..<abs(delta) {
                                    onCursorMove(direction)
                                }
                                accumulatedOffset = dx
                            }
                        }
                    }
                    .onEnded { _ in
                        if isLongPressing {
                            // Was in trackpad mode — deactivate
                            isLongPressing = false
                            onTrackpadDeactivated()
                        } else {
                            // Short tap — normal space
                            onSpace()
                        }
                        longPressTimer?.invalidate()
                        longPressTimer = nil
                        accumulatedOffset = 0
                    }
            )
    }
}
