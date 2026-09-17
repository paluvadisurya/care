import SwiftUI

/// The one title per screen. An optional eyebrow above, and exactly one accent word set in serif italic.
///
/// The two runs are concatenated into a single `Text` rather than laid out in an HStack, so a long name wraps
/// as one paragraph instead of the accent being pushed onto its own orphaned line.
public struct ScreenTitle: View {
    @ScaledMetric private var typeScale: CGFloat = 1
    public var eyebrow: String?
    public var lead: String
    public var accent: String?
    public var role: CareType

    public init(eyebrow: String? = nil, lead: String, accent: String? = nil, role: CareType = .screenTitle) {
        self.eyebrow = eyebrow
        self.lead = lead
        self.accent = accent
        self.role = role
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let eyebrow {
                Text(eyebrow)
                    .careType(.labelEmphasis)
                    .foregroundStyle(CareColor.textSecondary)
            }
            title
                .foregroundStyle(CareColor.textPrimary)
                .lineLimit(role.lineLimit)
                .minimumScaleFactor(role.minimumScaleFactor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([eyebrow, lead, accent].compactMap { $0 }.joined(separator: ", "))
    }

    private var title: Text {
        let base = Text(lead)
            .font(role.font)
            .tracking(role.size * role.trackingRatio * typeScale)
        guard let accent, !accent.isEmpty else { return base }
        // The serif accent is set slightly larger so its lowercase x-height matches the display face.
        let accentText = Text(" " + accent)
            .font(CareFont.serifItalic(role.size * 1.1, relativeTo: role.textStyle))
            .tracking(role.size * -0.01 * typeScale)
        return base + accentText
    }
}
