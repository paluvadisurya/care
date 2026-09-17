import SwiftUI

/// The label above a group of cards. Sentence case, never all caps, with an optional count on the right
/// and an optional action. Every section in the app uses this, so vertical rhythm stays identical.
public struct SectionLabel: View {
    public var title: String
    public var trailing: String?
    public var actionTitle: String?
    public var action: (() -> Void)?

    public init(_ title: String, trailing: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.trailing = trailing
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CareSpace.xs) {
            Text(title)
                .careType(.labelEmphasis)
                .foregroundStyle(CareColor.textSecondary)
            Spacer(minLength: CareSpace.xs)
            if let trailing {
                Text(trailing)
                    .careType(.meta)
                    .foregroundStyle(CareColor.textMuted)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .careType(.labelEmphasis)
                    .foregroundStyle(CareColor.textPrimary)
                    .buttonStyle(.pressable(scale: 0.94))
            }
        }
        .padding(.horizontal, CareSpace.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A titled group of cards. Replaces the `VStack + SectionLabel` pair that screens used to assemble by hand,
/// so the gap between a label and its content is the same everywhere.
public struct CareSection<Content: View>: View {
    public var title: String?
    public var trailing: String?
    public var actionTitle: String?
    public var action: (() -> Void)?
    public var content: Content

    public init(_ title: String? = nil, trailing: String? = nil, actionTitle: String? = nil,
                action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.actionTitle = actionTitle
        self.action = action
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            if let title {
                SectionLabel(title, trailing: trailing, actionTitle: actionTitle, action: action)
            }
            content
        }
    }
}
