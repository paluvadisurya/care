import SwiftUI

/// "Good morning, Surya" with the name set in serif italic. One accent word per screen, no more.
public struct ScreenTitle: View {
    public var eyebrow: String?
    public var lead: String
    public var accent: String?
    public var size: CGFloat

    public init(eyebrow: String? = nil, lead: String, accent: String? = nil, size: CGFloat = 34) {
        self.eyebrow = eyebrow
        self.lead = lead
        self.accent = accent
        self.size = size
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let eyebrow {
                Text(eyebrow)
                    .font(CareFont.labelSemi)
                    .foregroundStyle(CareColor.textSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(lead)
                    .font(CareFont.display(size))
                    .displayTracking(size)
                if let accent {
                    Text(" " + accent)
                        .font(CareFont.serifItalic(size * 1.08))
                        .tracking(-size * 0.01)
                }
            }
            .foregroundStyle(CareColor.textPrimary)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}
