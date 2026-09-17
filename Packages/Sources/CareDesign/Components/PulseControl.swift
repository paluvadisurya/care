import SwiftUI
import CareCore

/// The signature control: one drag sets mood across five stops with a haptic tick at each.
/// Track is a coral to amber to mint gradient; the knob is white glass.
public struct PulseControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding public var value: Int          // 1...5
    public var showLabels: Bool
    @State private var dragging = false

    public init(value: Binding<Int>, showLabels: Bool = true) {
        _value = value
        self.showLabels = showLabels
    }

    public static let words = ["Low", "Meh", "Okay", "Good", "Great"]

    public var body: some View {
        VStack(spacing: CareSpace.xs) {
            GeometryReader { geo in
                let width = geo.size.width
                let knob: CGFloat = 40
                let usable = width - knob
                let x = usable * CGFloat(value - 1) / 4
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [CareColor.coral, CareColor.amber, CareColor.mint], startPoint: .leading, endPoint: .trailing))
                        .overlay { Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1) }
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                    HStack {
                        ForEach(0..<5, id: \.self) { i in
                            Circle().fill(.white.opacity(i + 1 == value ? 0 : 0.5)).frame(width: 5, height: 5)
                            if i < 4 { Spacer() }
                        }
                    }
                    .padding(.horizontal, knob / 2 - 2)
                    Circle()
                        .fill(.white)
                        .overlay { Text(ModuleHelpers.moodEmoji(value)).font(.system(size: 20)) }
                        .frame(width: knob - 6, height: knob - 6)
                        .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
                        .scaleEffect(dragging ? 1.12 : 1)
                        .offset(x: x + 3)
                        .animation(CareMotion.snappy(reduced: reduceMotion), value: value)
                        .animation(CareMotion.snappy(reduced: reduceMotion), value: dragging)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            dragging = true
                            let clamped = min(max(0, g.location.x - knob / 2), usable)
                            value = Int((clamped / usable * 4).rounded()) + 1
                        }
                        .onEnded { _ in dragging = false }
                )
            }
            .frame(height: 44)
            .sensoryFeedback(.selection, trigger: value)

            if showLabels {
                HStack {
                    ForEach(Array(Self.words.enumerated()), id: \.offset) { i, w in
                        Text(w)
                            .font(CareFont.meta)
                            .foregroundStyle(i + 1 == value ? CareColor.textPrimary : CareColor.textMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mood")
        .accessibilityValue(Text(Self.words[max(0, min(4, value - 1))]))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(5, value + 1)
            case .decrement: value = max(1, value - 1)
            @unknown default: break
            }
        }
    }
}
