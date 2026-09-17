import SwiftUI

/// Single or multi select chips. Selected fills ink.
///
/// A long list of options scrolls sideways; a short set that the reader should take in at a glance wraps
/// onto a second line instead, so nothing important hides off the right edge.
public struct ChipRow<Item: Hashable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var items: [Item]
    public var label: (Item) -> String
    public var selection: Set<Item>
    public var wraps: Bool
    public var onTap: (Item) -> Void

    public init(items: [Item], selection: Set<Item>, wraps: Bool = false,
                label: @escaping (Item) -> String, onTap: @escaping (Item) -> Void) {
        self.items = items
        self.selection = selection
        self.wraps = wraps
        self.label = label
        self.onTap = onTap
    }

    public var body: some View {
        Group {
            if wraps { wrapped } else { scrolling }
        }
        .animation(CareMotion.snappy(reduced: reduceMotion), value: selection)
    }

    private var chips: some View {
        ForEach(items, id: \.self) { item in
            Chip(text: label(item), isSelected: selection.contains(item)) { onTap(item) }
        }
    }

    private var wrapped: some View {
        FlowLayout(spacing: CareSpace.xs) { chips }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scrolling: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CareSpace.xs) { chips }
                .padding(.vertical, 2)
                .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

public struct Chip: View {
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 36
    public var text: String
    public var isSelected: Bool
    public var action: () -> Void

    public init(text: String, isSelected: Bool, action: @escaping () -> Void) {
        self.text = text
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(text)
                .careType(.chipLabel)
                .foregroundStyle(isSelected ? CareColor.inkText : CareColor.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: height)
                .background(isSelected ? CareColor.ink : CareColor.chip, in: Capsule())
                .frame(minHeight: CareLayout.touchTarget)
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable(scale: 0.94))
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
