import SwiftUI
import CareCore

/// Care's signature control. One drag sets mood across five stops, with a haptic tick at each.
///
/// The knob follows the finger continuously and settles onto the nearest stop with a spring when released,
/// so the gesture feels physical rather than like five buttons pretending to be a slider.
public struct PulseControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var trackHeight: CGFloat = 46
    @Binding public var value: Int
    public var showsLabels: Bool
    @State private var isDragging = false
    @State private var dragFraction: Double?

    public init(value: Binding<Int>, showsLabels: Bool = true) {
        _value = value
        self.showsLabels = showsLabels
    }

    public static let words = ["Low", "Meh", "Okay", "Good", "Great"]

    private var knobDiameter: CGFloat { trackHeight - 10 }

    public var body: some View {
        VStack(spacing: CareSpace.xs) {
            track
            if showsLabels { labels }
        }
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mood")
        .accessibilityValue(Text(Self.words[clampedIndex]))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(5, value + 1)
            case .decrement: value = max(1, value - 1)
            @unknown default: break
            }
        }
    }

    private var clampedIndex: Int { max(0, min(Self.words.count - 1, value - 1)) }

    private var track: some View {
        GeometryReader { geo in
            let usable = max(1, geo.size.width - knobDiameter - 10)
            let settled = Double(clampedIndex) / 4
            let fraction = dragFraction ?? settled
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: [CareColor.coral, CareColor.amber, CareColor.mint],
                                         startPoint: .leading, endPoint: .trailing))
                    .overlay { Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1) }
                    .careElevation(.resting)

                // Stop markers, hidden under the knob as it passes.
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(.white.opacity(i == clampedIndex ? 0 : 0.5))
                            .frame(width: 5, height: 5)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, knobDiameter / 2)

                knob
                    .offset(x: 5 + usable * fraction)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        isDragging = true
                        let x = min(max(0, g.location.x - knobDiameter / 2 - 5), usable)
                        dragFraction = x / usable
                        value = Int((x / usable * 4).rounded()) + 1
                    }
                    .onEnded { _ in
                        isDragging = false
                        withAnimation(reduceMotion ? CareMotion.reduced : .spring(duration: 0.4, bounce: 0.35)) {
                            dragFraction = nil
                        }
                    }
            )
            .animation(isDragging ? nil : CareMotion.snappy(reduced: reduceMotion), value: value)
        }
        .frame(height: trackHeight)
    }

    private var knob: some View {
        Circle()
            .fill(.white)
            .overlay {
                Text(ModuleHelpers.moodEmoji(value))
                    .font(.system(size: knobDiameter * 0.58))
            }
            .frame(width: knobDiameter, height: knobDiameter)
            .shadow(color: .black.opacity(0.24), radius: 8, y: 4)
            .scaleEffect(isDragging ? 1.14 : 1)
            .animation(CareMotion.snappy(reduced: reduceMotion), value: isDragging)
    }

    private var labels: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.words.enumerated()), id: \.offset) { i, word in
                Text(word)
                    .careType(.meta)
                    .foregroundStyle(i == clampedIndex ? CareColor.textPrimary : CareColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .animation(CareMotion.snappy(reduced: reduceMotion), value: clampedIndex)
            }
        }
    }
}
