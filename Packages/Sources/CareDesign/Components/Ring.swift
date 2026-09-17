import SwiftUI

/// Hydration and adherence ring. Fills with a slight overshoot; the centre uses numeric text transitions.
public struct Ring<Center: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var progress: Double
    public var lineWidth: CGFloat
    public var gradient: [Color]
    public var size: CGFloat
    public var center: Center

    public init(progress: Double, size: CGFloat = 56, lineWidth: CGFloat = 7, gradient: [Color] = [CareColor.sky, CareColor.violet], @ViewBuilder center: () -> Center) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.gradient = gradient
        self.center = center()
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(CareColor.chip, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(AngularGradient(colors: gradient + [gradient.first ?? .clear], center: .center), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? CareMotion.reduced : .spring(duration: 0.6, bounce: 0.25), value: progress)
            center
                .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text("\(Int(progress * 100)) percent"))
    }
}

public extension Ring where Center == Text {
    init(progress: Double, size: CGFloat = 56, lineWidth: CGFloat = 7, gradient: [Color] = [CareColor.sky, CareColor.violet]) {
        self.init(progress: progress, size: size, lineWidth: lineWidth, gradient: gradient) {
            Text("\(Int((progress * 100).rounded()))%")
                .font(CareFont.textSemi(size * 0.22, relativeTo: .caption))
                .foregroundStyle(CareColor.textPrimary)
                .monospacedDigit()
        }
    }
}
