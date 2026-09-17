import SwiftUI
import CareCore

/// Person profile top. Aura wash fading into content, name at 36 pt heavy, role and a status line.
/// The parent drives `collapse` (0 expanded, 1 collapsed) from scroll geometry.
public struct AuraHeader: View {
    public var name: String
    public var role: String
    public var status: String
    public var aura: Aura
    public var initials: String
    public var collapse: Double

    public init(name: String, role: String, status: String, aura: Aura, initials: String, collapse: Double = 0) {
        self.name = name
        self.role = role
        self.status = status
        self.aura = aura
        self.initials = initials
        self.collapse = collapse
    }

    public var body: some View {
        let c = min(1, max(0, collapse))
        VStack(alignment: .leading, spacing: CareSpace.xxs) {
            HStack(alignment: .center, spacing: CareSpace.sm) {
                PersonOrb(initials: initials, aura: aura, size: 44 + (1 - c) * 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(role)
                        .font(CareFont.labelSemi)
                        .foregroundStyle(CareColor.textSecondary)
                        .opacity(1 - c)
                        .frame(height: c > 0.9 ? 0 : nil)
                    Text(name)
                        .font(CareFont.display(36 - c * 14))
                        .displayTracking(36)
                        .foregroundStyle(CareColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer()
            }
            Text(status)
                .font(CareFont.callout)
                .foregroundStyle(CareColor.textSecondary)
                .lineLimit(2)
                .opacity(1 - c)
                .frame(height: c > 0.9 ? 0 : nil)
        }
        .padding(.horizontal, CareSpace.gutter)
        .padding(.top, CareSpace.xs)
        .padding(.bottom, CareSpace.sm)
        .background(alignment: .top) {
            LinearGradient(colors: [aura.startColor.opacity(0.35), aura.endColor.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 260)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.2), value: c > 0.9)
    }
}
