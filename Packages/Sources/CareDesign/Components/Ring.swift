import SwiftUI

/// Progress rings, at the three sizes the app uses. A ring fills with a slight overshoot so completing
/// something feels like it lands, and the centre number rolls rather than blinking.
public enum RingSize: Sendable, Hashable {
    case tile, row, hero, jumbo

    var diameter: CGFloat {
        switch self {
        case .tile: 44
        case .row: 52
        case .hero: 64
        case .jumbo: 168
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .tile: 6
        case .row: 7
        case .hero: 8
        case .jumbo: 16
        }
    }

    var labelSize: CGFloat {
        switch self {
        case .tile: 11
        case .row: 12
        case .hero: 15
        case .jumbo: 34
        }
    }
}

public struct Ring<Center: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var progress: Double
    public var size: RingSize
    public var gradient: [Color]
    public var center: Center

    public init(progress: Double, size: RingSize = .tile, gradient: [Color] = [CareColor.sky, CareColor.violet],
                @ViewBuilder center: () -> Center) {
        self.progress = progress
        self.size = size
        self.gradient = gradient
        self.center = center()
    }

    private var clamped: Double { min(1, max(0, progress)) }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(CareColor.chip, lineWidth: size.lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(colors: gradient + [gradient.first ?? .clear], center: .center),
                    style: StrokeStyle(lineWidth: size.lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? CareMotion.reduced : .spring(duration: 0.65, bounce: 0.28), value: clamped)
            center
                .rollingNumber()
        }
        .frame(width: size.diameter, height: size.diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text("\(Int(clamped * 100)) percent"))
    }
}

/// The default centre: a percentage that rolls as the ring fills.
public struct RingLabel: View {
    public var progress: Double
    public var size: RingSize

    public init(progress: Double, size: RingSize) {
        self.progress = progress
        self.size = size
    }

    public var body: some View {
        Text("\(Int((min(1, max(0, progress)) * 100).rounded()))%")
            .font(CareFont.textSemi(size.labelSize, relativeTo: .caption))
            .foregroundStyle(CareColor.textPrimary)
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .lineLimit(1)
    }
}

public extension Ring where Center == RingLabel {
    init(progress: Double, size: RingSize = .tile, gradient: [Color] = [CareColor.sky, CareColor.violet]) {
        self.init(progress: progress, size: size, gradient: gradient) {
            RingLabel(progress: progress, size: size)
        }
    }
}
