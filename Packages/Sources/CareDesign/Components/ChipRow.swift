import SwiftUI

/// Single or multi select chips. Selected fills ink; spring 0.25.
public struct ChipRow<Item: Hashable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var items: [Item]
    public var label: (Item) -> String
    public var selection: Set<Item>
    public var onTap: (Item) -> Void

    public init(items: [Item], selection: Set<Item>, label: @escaping (Item) -> String, onTap: @escaping (Item) -> Void) {
        self.items = items
        self.selection = selection
        self.label = label
        self.onTap = onTap
    }

    public var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CareSpace.xs) {
                ForEach(items, id: \.self) { item in
                    Chip(text: label(item), isSelected: selection.contains(item)) { onTap(item) }
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
        .animation(CareMotion.snappy(reduced: reduceMotion), value: selection)
    }
}

public struct Chip: View {
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
                .font(CareFont.chip)
                .foregroundStyle(isSelected ? CareColor.inkText : CareColor.textPrimary)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(isSelected ? CareColor.ink : CareColor.chip, in: Capsule())
        }
        .buttonStyle(.pressable(scale: 0.94))
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
