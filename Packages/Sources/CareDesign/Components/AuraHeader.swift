import SwiftUI
import CareCore

/// The top of a person's profile. A wash of their aura fading into the content, their name at display size,
/// their role, and one line of status written by the app.
///
/// `collapse` runs 0 to 1 as the screen scrolls. Every value interpolates continuously, so the header
/// shrinks smoothly instead of snapping between two layouts.
public struct AuraHeader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var name: String
    public var role: String
    public var status: String
    public var aura: Aura
    public var initials: String
    public var symbol: String?
    public var collapse: Double

    public init(name: String, role: String, status: String, aura: Aura, initials: String,
                symbol: String? = nil, collapse: Double = 0) {
        self.name = name
        self.role = role
        self.status = status
        self.aura = aura
        self.initials = initials
        self.symbol = symbol
        self.collapse = collapse
    }

    private var c: Double { min(1, max(0, collapse)) }

    public var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            HStack(alignment: .center, spacing: CareSpace.sm) {
                PersonOrb(initials: initials, aura: aura, size: c > 0.5 ? .small : .header, symbol: symbol)
                    .animation(CareMotion.standard(reduced: reduceMotion), value: c > 0.5)

                VStack(alignment: .leading, spacing: 1) {
                    Text(role)
                        .careType(.labelEmphasis)
                        .foregroundStyle(CareColor.textSecondary)
                        .opacity(1 - c * 1.6)
                    Text(name)
                        .font(CareFont.display(CareType.screenTitle.size + 3 - c * 12, relativeTo: .title))
                        .tracking((CareType.screenTitle.size + 3) * CareType.screenTitle.trackingRatio)
                        .foregroundStyle(CareColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
            }

            Text(status)
                .careType(.callout)
                .foregroundStyle(CareColor.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(1 - c * 1.8)
                .frame(height: c > 0.55 ? 0 : nil, alignment: .top)
                .clipped()
        }
        .padding(.horizontal, CareSpace.gutter)
        .padding(.top, CareSpace.xs)
        .padding(.bottom, CareSpace.sm)
        .background(alignment: .top) { wash }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(role). \(status)")
    }

    private var wash: some View {
        LinearGradient(
            colors: [aura.startColor.opacity(0.38), aura.endColor.opacity(0.16), .clear],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: CareLayout.auraWashHeight)
        .opacity(1 - c * 0.45)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
