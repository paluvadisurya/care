import SwiftUI
import CareCore

/// The one thing on Today. Never more than one per screen.
///
/// Fixed rhythm: a label row that names the person and the moment, the presentation, a supporting sentence,
/// then up to two actions. Everything else on the screen is quiet by comparison.
public struct HeroCard<Presentation: View>: View {
    public struct Action: Identifiable {
        public var id: String { title }
        public var title: String
        public var isPrimary: Bool
        public var perform: () -> Void

        public init(title: String, isPrimary: Bool = false, perform: @escaping () -> Void) {
            self.title = title
            self.isPrimary = isPrimary
            self.perform = perform
        }
    }

    public var label: String
    public var trailing: String?
    public var message: String
    public var tone: Tone
    public var aura: Aura?
    public var actions: [Action]
    public var presentation: Presentation

    public init(label: String, trailing: String? = nil, message: String, tone: Tone = .neutral,
                aura: Aura? = nil, actions: [Action] = [], @ViewBuilder presentation: () -> Presentation) {
        self.label = label
        self.trailing = trailing
        self.message = message
        self.tone = tone
        self.aura = aura
        self.actions = actions
        self.presentation = presentation()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            HStack(alignment: .firstTextBaseline, spacing: CareSpace.xs) {
                if let aura {
                    Circle().fill(aura.gradient).frame(width: 9, height: 9)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                }
                Text(label)
                    .careType(.labelEmphasis)
                    .foregroundStyle(tone == .attention ? CareColor.attention : CareColor.textSecondary)
                Spacer(minLength: CareSpace.xs)
                if let trailing {
                    Text(trailing)
                        .careType(.meta)
                        .foregroundStyle(CareColor.textMuted)
                }
            }

            presentation
                .padding(.vertical, 2)

            Text(message)
                .careType(.callout)
                .foregroundStyle(CareColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !actions.isEmpty {
                HStack(spacing: CareSpace.xs) {
                    ForEach(actions.prefix(2)) { action in
                        PillButton(action.title, style: action.isPrimary ? .ink : .ghost, compact: true, action: action.perform)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
        }
        .careSurface(tone == .attention ? .attention : .hero)
    }
}
