import SwiftUI

/// The small capsule that annotates a row: a tier, a status, a time.
///
/// Three screens had drawn their own version of this with the same seven and three point insets, which is
/// how two of them drifted a point apart. One component, one set of tones.
public struct CareTag: View {
    public enum Tone: Sendable, Hashable {
        case quiet, attention, positive, upcoming, intelligence

        var foreground: Color {
            switch self {
            case .quiet: CareColor.textMuted
            case .attention: CareColor.attention
            case .positive: CareColor.positive
            case .upcoming: CareColor.upcoming
            case .intelligence: CareColor.intelligence
            }
        }

        var background: Color {
            switch self {
            case .quiet: CareColor.chip
            default: foreground.opacity(0.12)
            }
        }
    }

    public var text: String
    public var tone: Tone

    public init(_ text: String, tone: Tone = .quiet) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .careType(.meta)
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tone.background, in: Capsule())
            .fixedSize()
    }
}

public extension View {
    /// The chip surface: one height, one inset, one background. Used by `Chip` and by anything that has to
    /// look like a chip without being one, such as a `ShareLink` label.
    func careChipSurface(isSelected: Bool = false) -> some View {
        modifier(CareChipSurface(isSelected: isSelected))
    }
}

public struct CareChipSurface: ViewModifier {
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 36
    public var isSelected: Bool

    public func body(content: Content) -> some View {
        content
            .foregroundStyle(isSelected ? CareColor.inkText : CareColor.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: height)
            .background(isSelected ? CareColor.ink : CareColor.chip, in: Capsule())
            .frame(minHeight: CareLayout.touchTarget)
            .contentShape(Capsule())
    }
}
