import SwiftUI
import CareCore

/// The one thing on Today. Max one per screen. A label line, a big presentation, a body line and up to two chips.
public struct HeroCard<Presentation: View>: View {
    public var label: String
    public var trailing: String?
    public var body_: String
    public var tone: Tone
    public var presentation: Presentation
    public var actions: [(title: String, primary: Bool, action: () -> Void)]

    public init(label: String, trailing: String? = nil, body: String, tone: Tone = .neutral,
                actions: [(title: String, primary: Bool, action: () -> Void)] = [], @ViewBuilder presentation: () -> Presentation) {
        self.label = label
        self.trailing = trailing
        self.body_ = body
        self.tone = tone
        self.actions = actions
        self.presentation = presentation()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(CareFont.labelSemi)
                    .foregroundStyle(tone == .attention ? CareColor.attention : CareColor.textSecondary)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(CareFont.meta)
                        .foregroundStyle(CareColor.textMuted)
                }
            }
            presentation
                .padding(.vertical, CareSpace.xxs)
            Text(body_)
                .font(CareFont.callout)
                .foregroundStyle(CareColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !actions.isEmpty {
                HStack(spacing: CareSpace.xs) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { _, a in
                        PillButton(a.title, style: a.primary ? .ink : .ghost, compact: true, action: a.action)
                    }
                }
                .padding(.top, CareSpace.xxs)
            }
        }
        .careCard(radius: CareRadius.hero, padding: CareSpace.md + 2, attention: tone == .attention, strong: true)
    }
}
