import SwiftUI

/// A button that fires its action repeatedly while held down.
/// Behavior: immediate fire → 0.5s wait → 0.1s interval → accelerate to 0.05s after 20 repeats.
struct RepeatingButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: (_ isPressed: Bool) -> Label

    @State private var timer: Timer?
    @State private var repeatCount = 0
    @State private var isPressed = false

    var body: some View {
        label(isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        action()
                        startRepeating()
                    }
                    .onEnded { _ in
                        stopRepeating()
                    }
            )
    }

    private func startRepeating() {
        repeatCount = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            action()
            repeatCount += 1
            startFastRepeat()
        }
    }

    private func startFastRepeat() {
        let interval: TimeInterval = repeatCount > 20 ? 0.05 : 0.1
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            action()
            repeatCount += 1
            if repeatCount == 21 {
                // Switch to faster interval
                timer?.invalidate()
                startFastRepeat()
            }
        }
    }

    private func stopRepeating() {
        isPressed = false
        timer?.invalidate()
        timer = nil
        repeatCount = 0
    }
}
