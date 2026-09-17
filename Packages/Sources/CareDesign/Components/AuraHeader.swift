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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(role). \(status)")
    }
}

/// The colour a person casts over the top of their screen.
///
/// This is a screen layer, not a header background. It is drawn behind everything from the very top edge so
/// the wash meets the status bar and the rail without a seam, and it fades as the header collapses. Keeping
/// it separate is also what lets the rail sit outside the scroll view while still standing in the person's
/// colour.
public struct AuraWash: View {
    public var aura: Aura
    public var collapse: Double

    public init(aura: Aura, collapse: Double = 0) {
        self.aura = aura
        self.collapse = collapse
    }

    public var body: some View {
        let c = min(1, max(0, collapse))
        return LinearGradient(
            stops: [
                .init(color: aura.startColor.opacity(0.34), location: 0),
                .init(color: aura.startColor.opacity(0.30), location: 0.22),
                .init(color: aura.endColor.opacity(0.14), location: 0.58),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: CareLayout.auraWashHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(1 - c * 0.5)
        .animation(.linear(duration: 0.1), value: c)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
