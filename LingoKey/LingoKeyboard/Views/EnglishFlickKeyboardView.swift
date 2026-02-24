import SwiftUI

/// English ABC flick keyboard matching Apple's native layout:
///
/// ```
/// [→]    [@#/&_] [ABC]  [DEF]   [⌫]
/// [↩]    [GHI]   [JKL]  [MNO]   [空白]
/// [☆123] [PQRS]  [TUV]  [WXYZ]  ┌──────┐
/// [😊]   [a/A]   ['"()] [.,?!]  │  →   │
///                                └──────┘
/// ```
struct EnglishFlickKeyboardView: View {
    let onChar: (String) -> Void
    let onBackspace: () -> Void
    let onSpace: () -> Void
    let onReturn: () -> Void
    let onSwitchToNumberFlick: () -> Void
    let onSwitchToKana: () -> Void
    var onToggleEmojiPicker: (() -> Void)? = nil

    @State private var shiftState: ShiftState = .off
    @State private var lastShiftTapTime: Date? = nil

    private let rowHeight: CGFloat = 46
    private let keySpacing: CGFloat = 6
    private let rowSpacing: CGFloat = 7

    @State private var columnWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 10
            let cols: CGFloat = 5
            let calcWidth = (totalWidth - keySpacing * (cols - 1)) / cols

            VStack(spacing: rowSpacing) {
                row0
                row1
                bottomRows
            }
            .padding(.horizontal, 5)
            .padding(.top, 4)
            .padding(.bottom, 0)
            .onAppear { columnWidth = calcWidth }
            .onChange(of: geo.size.width) { _, _ in columnWidth = calcWidth }
        }
        .frame(height: rowHeight * 4 + rowSpacing * 3 + 4)
    }

    // MARK: - Rows

    private var row0: some View {
        HStack(spacing: keySpacing) {
            flickSideButton(systemImage: "arrow.right") { /* advance cursor - no-op for English */ }
            flickCells(for: FlickKeyMap.englishGrid[0])
            flickRepeatingBackspace
        }
    }

    private var row1: some View {
        HStack(spacing: keySpacing) {
            flickSideButton(systemImage: "arrow.counterclockwise") { /* undo - no-op for English */ }
            flickCells(for: FlickKeyMap.englishGrid[1])
            Button {
                onSpace()
            } label: {
                Text("空白")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, minHeight: rowHeight)
            }
            .buttonStyle(FlickSpecialKeyStyle())
        }
    }

    private var bottomRows: some View {
        HStack(spacing: keySpacing) {
            VStack(spacing: rowSpacing) {
                // Row 2: ☆123 | PQRS TUV WXYZ
                HStack(spacing: keySpacing) {
                    flickSideButton(label: "☆123", fontSize: 11) { onSwitchToNumberFlick() }
                    flickCells(for: FlickKeyMap.englishGrid[2])
                }
                // Row 3: 😊 | a/A | '"() | .,?!
                HStack(spacing: keySpacing) {
                    flickSideButton(systemImage: "face.smiling") { onToggleEmojiPicker?() }
                    // Shift toggle button
                    Button {
                        HapticManager.specialKeyTap()
                        let now = Date()
                        if let last = lastShiftTapTime, now.timeIntervalSince(last) < 0.3 {
                            shiftState = .capsLock
                            lastShiftTapTime = nil
                        } else if shiftState == .capsLock {
                            shiftState = .off
                            lastShiftTapTime = nil
                        } else {
                            shiftState = shiftState == .off ? .shift : .off
                            lastShiftTapTime = now
                        }
                    } label: {
                        Text(shiftState == .capsLock ? "A" : (shiftState == .shift ? "A/a" : "a/A"))
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, minHeight: rowHeight)
                    }
                    .buttonStyle(FlickSpecialKeyStyle())
                    // Quote/Paren key
                    EnglishFlickKeyCell(
                        flickKey: FlickKeyMap.englishQuote,
                        onChar: onChar,
                        height: rowHeight
                    )
                    // Punctuation key with cycling
                    PunctuationFlickKeyCellGeneric(
                        flickKey: FlickKeyMap.englishPunctuation,
                        onChar: onChar,
                        height: rowHeight,
                        cycleChars: [".", ",", "?", "!"]
                    )
                }
            }

            // Column 5: tall confirm button
            Button {
                onReturn()
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: columnWidth, height: rowHeight * 2 + rowSpacing)
            }
            .buttonStyle(ConfirmKeyStyle())
        }
    }

    // MARK: - Repeating Backspace

    private var flickRepeatingBackspace: some View {
        RepeatingButton(action: onBackspace) { pressed in
            Image(systemName: "delete.left")
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: rowHeight)
                .background(pressed ? KeyboardColors.keyPressed : KeyboardColors.key)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
        }
    }

    // MARK: - Helpers

    private func flickCells(for keys: [FlickKeyMap.FlickKey]) -> some View {
        ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
            EnglishFlickKeyCell(
                flickKey: key,
                onChar: { char in
                    let output = shiftState.isUppercase ? char : char.lowercased()
                    onChar(output)
                    if shiftState == .shift { shiftState = .off }
                },
                height: rowHeight
            )
        }
    }

    private func flickSideButton(
        label: String? = nil,
        systemImage: String? = nil,
        fontSize: CGFloat = 13,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18))
                } else if let label {
                    Text(label)
                        .font(.system(size: fontSize))
                }
            }
            .frame(maxWidth: .infinity, minHeight: rowHeight)
        }
        .buttonStyle(FlickSpecialKeyStyle())
    }
}

// MARK: - English Flick Key Cell

private struct EnglishFlickKeyCell: View {
    let flickKey: FlickKeyMap.FlickKey
    let onChar: (String) -> Void
    let height: CGFloat

    @State private var activeDirection: FlickKeyMap.Direction? = nil
    @State private var isDragging = false

    private let flickThreshold: CGFloat = 20

    /// Display label: shows all non-empty characters
    private var displayLabel: String {
        let chars = [flickKey.center, flickKey.left, flickKey.up, flickKey.right, flickKey.down]
            .filter { !$0.isEmpty }
        return chars.joined()
    }

    var body: some View {
        Text(displayLabel)
            .font(.system(size: displayLabel.count > 3 ? 16 : 20))
            .frame(maxWidth: .infinity, minHeight: height)
            .background(isDragging ? KeyboardColors.keyPressed : KeyboardColors.key)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
            .overlay(alignment: .top) {
                if isDragging {
                    flickPreview
                        .offset(y: -80)
                        .zIndex(100)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        activeDirection = direction(from: value.translation)
                    }
                    .onEnded { value in
                        let dir = direction(from: value.translation)
                        let char = flickKey.kana(for: dir)
                        if !char.isEmpty {
                            onChar(char)
                        }
                        isDragging = false
                        activeDirection = nil
                    }
            )
    }

    private func direction(from translation: CGSize) -> FlickKeyMap.Direction {
        let dx = translation.width
        let dy = translation.height
        guard max(abs(dx), abs(dy)) >= flickThreshold else { return .center }
        if abs(dx) > abs(dy) {
            return dx < 0 ? .left : .right
        } else {
            return dy < 0 ? .up : .down
        }
    }

    private var flickPreview: some View {
        let highlight = activeDirection ?? .center
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(KeyboardColors.key)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

            VStack(spacing: 2) {
                previewLabel(flickKey.up, active: highlight == .up)
                HStack(spacing: 2) {
                    previewLabel(flickKey.left, active: highlight == .left)
                    previewLabel(flickKey.center, active: highlight == .center)
                        .fontWeight(.bold)
                    previewLabel(flickKey.right, active: highlight == .right)
                }
                previewLabel(flickKey.down, active: highlight == .down)
            }
            .padding(4)
        }
        .frame(width: 90, height: 90)
    }

    private func previewLabel(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(.system(size: 16))
            .frame(width: 26, height: 26)
            .background(active ? Color.accentColor : Color.clear)
            .foregroundStyle(active ? .white : .primary)
            .cornerRadius(4)
    }
}

// MARK: - Generic Punctuation Flick Key Cell (with repeated-tap cycling)

struct PunctuationFlickKeyCellGeneric: View {
    let flickKey: FlickKeyMap.FlickKey
    let onChar: (String) -> Void
    let height: CGFloat
    let cycleChars: [String]

    @State private var activeDirection: FlickKeyMap.Direction? = nil
    @State private var isDragging = false
    @State private var cycleIndex: Int = 0
    @State private var lastTapTime: Date = .distantPast

    private let flickThreshold: CGFloat = 20
    private let cycleTimeout: TimeInterval = 1.0

    private var displayLabel: String {
        let chars = [flickKey.center, flickKey.left, flickKey.up, flickKey.right, flickKey.down]
            .filter { !$0.isEmpty }
        return chars.joined()
    }

    var body: some View {
        Text(displayLabel)
            .font(.system(size: 16))
            .frame(maxWidth: .infinity, minHeight: height)
            .background(isDragging ? KeyboardColors.keyPressed : KeyboardColors.key)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
            .overlay(alignment: .top) {
                if isDragging {
                    flickPreview
                        .offset(y: -80)
                        .zIndex(100)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let dir = direction(from: value.translation)
                        activeDirection = dir
                    }
                    .onEnded { value in
                        let dir = direction(from: value.translation)
                        if dir != .center {
                            onChar(flickKey.kana(for: dir))
                            resetCycle()
                        } else {
                            handleCycleTap()
                        }
                        isDragging = false
                        activeDirection = nil
                    }
            )
    }

    private func handleCycleTap() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTapTime)

        if elapsed < cycleTimeout {
            cycleIndex = (cycleIndex + 1) % cycleChars.count
            onChar("\u{0008}" + cycleChars[cycleIndex])
        } else {
            cycleIndex = 0
            onChar(cycleChars[0])
        }
        lastTapTime = now
    }

    private func resetCycle() {
        cycleIndex = 0
        lastTapTime = .distantPast
    }

    private func direction(from translation: CGSize) -> FlickKeyMap.Direction {
        let dx = translation.width
        let dy = translation.height
        guard max(abs(dx), abs(dy)) >= flickThreshold else { return .center }
        if abs(dx) > abs(dy) {
            return dx < 0 ? .left : .right
        } else {
            return dy < 0 ? .up : .down
        }
    }

    private var flickPreview: some View {
        let highlight = activeDirection ?? .center
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(KeyboardColors.key)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

            VStack(spacing: 2) {
                previewLabel(flickKey.up, active: highlight == .up)
                HStack(spacing: 2) {
                    previewLabel(flickKey.left, active: highlight == .left)
                    previewLabel(flickKey.center, active: highlight == .center)
                        .fontWeight(.bold)
                    previewLabel(flickKey.right, active: highlight == .right)
                }
                previewLabel(flickKey.down, active: highlight == .down)
            }
            .padding(4)
        }
        .frame(width: 90, height: 90)
    }

    private func previewLabel(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(.system(size: 16))
            .frame(width: 26, height: 26)
            .background(active ? Color.accentColor : Color.clear)
            .foregroundStyle(active ? .white : .primary)
            .cornerRadius(4)
    }
}
