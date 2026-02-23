import SwiftUI

/// Japanese flick keyboard matching Apple's native layout:
///
/// ```
/// [数字]   [あ]    [か]    [さ]    [⌫]
/// [ABC]    [た]    [な]    [は]    [空白]
/// [あいう] [ま]    [や]    [ら]    ┌──────┐
/// [^_^]    [小゛゜] [わ]   [、]    │ 確定  │
///                                  └──────┘
/// ```
struct FlickKeyboardView: View {
    let onKana: (String) -> Void
    let onModifierToggle: () -> Void
    let onBackspace: () -> Void
    let onSpace: () -> Void
    let onReturn: () -> Void
    let onToggleNumberKeyboard: () -> Void
    let onSwitchToRomaji: () -> Void
    var onToggleEmojiPicker: (() -> Void)? = nil

    private let rowHeight: CGFloat = 46
    private let keySpacing: CGFloat = 6

    /// Width of a single column, calculated from available space
    @State private var columnWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 8 // subtract horizontal padding
            let cols: CGFloat = 5
            let calcWidth = (totalWidth - keySpacing * (cols - 1)) / cols

            VStack(spacing: keySpacing) {
                // Row 0: 数字 | あ か さ | ⌫
                row0
                // Row 1: ABC | た な は | 空白
                row1
                // Rows 2-3: left 4 columns + tall 確定 button on right
                bottomRows
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .onAppear { columnWidth = calcWidth }
            .onChange(of: geo.size.width) { _, _ in columnWidth = calcWidth }
        }
        .frame(height: rowHeight * 4 + keySpacing * 3 + 8) // 4 rows + spacing + vertical padding
    }

    // MARK: - Rows

    private var row0: some View {
        HStack(spacing: keySpacing) {
            flickSideButton(label: "数字") { onToggleNumberKeyboard() }
            flickCells(for: FlickKeyMap.kanaGrid[0])
            flickRepeatingBackspace
        }
    }

    private var row1: some View {
        HStack(spacing: keySpacing) {
            flickSideButton(label: "ABC") { onSwitchToRomaji() }
            flickCells(for: FlickKeyMap.kanaGrid[1])
            flickSideButton(label: "空白") { onSpace() }
        }
    }

    /// Rows 2-3 combined: 5 columns, with 確定 button spanning 2 rows in column 5
    private var bottomRows: some View {
        HStack(spacing: keySpacing) {
            // Columns 1-4: two rows stacked
            VStack(spacing: keySpacing) {
                // Row 2: あいう | ま や ら
                HStack(spacing: keySpacing) {
                    flickSideButton(label: "あいう", fontSize: 10, isActive: true) { }
                    flickCells(for: FlickKeyMap.kanaGrid[2])
                }
                // Row 3: ^_^ | 小゛゜ わ 、
                HStack(spacing: keySpacing) {
                    flickSideButton(label: "^_^") { onToggleEmojiPicker?() }
                    // 小゛゜ key
                    Button {
                        onModifierToggle()
                    } label: {
                        Text("小゛゜")
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, minHeight: rowHeight)
                    }
                    .buttonStyle(FlickSpecialKeyStyle())
                    // わ key (flick)
                    FlickKeyCell(flickKey: FlickKeyMap.kanaWa, onKana: onKana, height: rowHeight)
                    // 、 key (flick + repeated-tap cycling: 、→。→？→！)
                    PunctuationFlickKeyCell(flickKey: FlickKeyMap.punctuation, onKana: onKana, height: rowHeight)
                }
            }

            // Column 5: tall 確定/改行 button spanning 2 rows, same width as one column
            Button {
                onReturn()
            } label: {
                Text("確定")
                    .font(.system(size: 13))
                    .frame(width: columnWidth, height: rowHeight * 2 + keySpacing)
            }
            .buttonStyle(FlickSpecialKeyStyle())
        }
    }

    // MARK: - Repeating Backspace

    private var flickRepeatingBackspace: some View {
        RepeatingButton(action: onBackspace) {
            Image(systemName: "delete.left")
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: rowHeight)
                .background(KeyboardColors.specialKey)
                .cornerRadius(5)
                .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
        }
    }

    // MARK: - Helpers

    private func flickCells(for keys: [FlickKeyMap.FlickKey]) -> some View {
        ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
            FlickKeyCell(flickKey: key, onKana: onKana, height: rowHeight)
        }
    }

    private func flickSideButton(
        label: String? = nil,
        systemImage: String? = nil,
        fontSize: CGFloat = 13,
        isActive: Bool = false,
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
        .buttonStyle(FlickSpecialKeyStyle(isActive: isActive))
    }
}

// MARK: - Flick Key Cell

private struct FlickKeyCell: View {
    let flickKey: FlickKeyMap.FlickKey
    let onKana: (String) -> Void
    let height: CGFloat

    @State private var activeDirection: FlickKeyMap.Direction? = nil
    @State private var isDragging = false

    private let flickThreshold: CGFloat = 20

    var body: some View {
        Text(flickKey.center)
            .font(.system(size: 22))
            .frame(maxWidth: .infinity, minHeight: height)
            .background(isDragging ? KeyboardColors.keyPressed : KeyboardColors.key)
            .cornerRadius(5)
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
                        let kana = flickKey.kana(for: dir)
                        onKana(kana)
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

    // MARK: - Cross-shaped Preview Popup

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

// MARK: - Punctuation Flick Key Cell (with repeated-tap cycling)

/// Like FlickKeyCell but adds Apple-style repeated-tap cycling: 、→。→？→！→、…
/// Flick (drag) still works for directional input.
private struct PunctuationFlickKeyCell: View {
    let flickKey: FlickKeyMap.FlickKey
    let onKana: (String) -> Void
    let height: CGFloat

    @State private var activeDirection: FlickKeyMap.Direction? = nil
    @State private var isDragging = false
    @State private var cycleIndex: Int = 0
    @State private var lastTapTime: Date = .distantPast
    @State private var didFlick = false

    private let flickThreshold: CGFloat = 20
    private static let cycleChars = ["、", "。", "？", "！"]
    private static let cycleTimeout: TimeInterval = 1.0

    var body: some View {
        Text(flickKey.center)
            .font(.system(size: 22))
            .frame(maxWidth: .infinity, minHeight: height)
            .background(isDragging ? KeyboardColors.keyPressed : KeyboardColors.key)
            .cornerRadius(5)
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
                        didFlick = dir != .center
                    }
                    .onEnded { value in
                        let dir = direction(from: value.translation)

                        if dir != .center {
                            // Flick → emit directional character
                            onKana(flickKey.kana(for: dir))
                            resetCycle()
                        } else {
                            // Center tap → cycling behavior
                            handleCycleTap()
                        }

                        isDragging = false
                        activeDirection = nil
                        didFlick = false
                    }
            )
    }

    private func handleCycleTap() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTapTime)

        if elapsed < Self.cycleTimeout {
            // Rapid tap → cycle to next punctuation
            cycleIndex = (cycleIndex + 1) % Self.cycleChars.count
            // Signal replacement: delete previous char, then insert new one
            onKana("\u{0008}" + Self.cycleChars[cycleIndex])
        } else {
            // Fresh tap → start cycle from 、
            cycleIndex = 0
            onKana(Self.cycleChars[0])
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

// MARK: - Flick Key Style

struct FlickSpecialKeyStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                configuration.isPressed
                    ? KeyboardColors.specialKeyPressed
                    : isActive ? KeyboardColors.keyPressed : KeyboardColors.specialKey
            )
            .cornerRadius(5)
            .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
    }
}
