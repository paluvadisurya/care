import SwiftUI
import CareCore

/// The horizontal row of people that appears on Today, on People, in the module store and in onboarding.
///
/// Before this existed each screen built its own row, which is why one of them clipped the first name and
/// none of them agreed on spacing. Now there is one implementation: every item reserves the same width, the
/// label truncates instead of clipping, the rail carries its own gutters so the first and last orbs breathe,
/// and selection moves with a single shared animation.
public struct OrbRail: View {
    /// One person in the rail. Built from a record so screens never assemble the pieces themselves.
    public struct Item: Identifiable, Hashable {
        public var id: UUID
        public var name: String
        public var initials: String
        public var aura: Aura
        public var symbol: String?
        public var hasAttention: Bool

        public init(id: UUID, name: String, initials: String, aura: Aura, symbol: String? = nil, hasAttention: Bool = false) {
            self.id = id
            self.name = name
            self.initials = initials
            self.aura = aura
            self.symbol = symbol
            self.hasAttention = hasAttention
        }

        public init(person: PersonRecord, hasAttention: Bool = false) {
            self.init(id: person.id,
                      name: person.shortName,
                      initials: person.initials,
                      aura: person.aura,
                      symbol: person.relationship == .pet ? "pawprint.fill" : nil,
                      hasAttention: hasAttention)
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionSpace

    public var items: [Item]
    public var size: OrbSize
    public var selection: UUID?
    public var showsLabels: Bool
    public var addLabel: String?
    public var onSelect: (UUID) -> Void
    public var onLongPress: ((UUID) -> Void)?
    public var onAdd: (() -> Void)?

    public init(items: [Item], size: OrbSize = .rail, selection: UUID? = nil, showsLabels: Bool = false,
                addLabel: String? = nil, onSelect: @escaping (UUID) -> Void,
                onLongPress: ((UUID) -> Void)? = nil, onAdd: (() -> Void)? = nil) {
        self.items = items
        self.size = size
        self.selection = selection
        self.showsLabels = showsLabels
        self.addLabel = addLabel
        self.onSelect = onSelect
        self.onLongPress = onLongPress
        self.onAdd = onAdd
    }

    /// Convenience for the common case: a list of people plus the set that needs attention.
    public init(people: [PersonRecord], attention: Set<UUID> = [], size: OrbSize = .rail, selection: UUID? = nil,
                showsLabels: Bool = false, addLabel: String? = nil, onSelect: @escaping (UUID) -> Void,
                onLongPress: ((UUID) -> Void)? = nil, onAdd: (() -> Void)? = nil) {
        self.init(items: people.map { Item(person: $0, hasAttention: attention.contains($0.id)) },
                  size: size, selection: selection, showsLabels: showsLabels, addLabel: addLabel,
                  onSelect: onSelect, onLongPress: onLongPress, onAdd: onAdd)
    }

    /// Every item occupies the same width, so the rail keeps an even rhythm no matter how long a name is.
    private var itemWidth: CGFloat { size.reserved + CareSpace.sm }

    public var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CareLayout.railGap) {
                ForEach(items) { item in
                    orbButton(item)
                }
                if let addLabel, let onAdd {
                    addButton(addLabel, action: onAdd)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        // The gutters live inside the scroll content, which is what keeps the first and last items from
        // sitting against the screen edge and their labels from being clipped.
        .contentMargins(.horizontal, CareSpace.gutter, for: .scrollContent)
        .contentMargins(.vertical, CareSpace.xxs, for: .scrollContent)
        .animation(CareMotion.standard(reduced: reduceMotion), value: selection)
    }

    private func orbButton(_ item: Item) -> some View {
        Button {
            onSelect(item.id)
        } label: {
            VStack(spacing: CareSpace.xxs) {
                PersonOrb(initials: item.initials, aura: item.aura, size: size,
                          isSelected: item.id == selection, hasAttention: item.hasAttention,
                          symbol: item.symbol, accessibilityName: item.name)
                if showsLabels {
                    Text(item.name)
                        .careType(.itemLabel)
                        .foregroundStyle(item.id == selection ? CareColor.textPrimary : CareColor.textSecondary)
                        .frame(maxWidth: itemWidth)
                }
            }
            .frame(width: itemWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.93))
        .accessibilityLabel(item.hasAttention ? "\(item.name), needs attention" : item.name)
        .accessibilityAddTraits(item.id == selection ? [.isSelected, .isButton] : .isButton)
        .modifier(LongPressAction { onLongPress?(item.id) })
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: CareSpace.xxs) {
                ZStack {
                    Circle()
                        .strokeBorder(CareColor.separator, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    Image(systemName: "plus")
                        .font(.system(size: size.diameter * 0.34, weight: .semibold))
                        .foregroundStyle(CareColor.textSecondary)
                }
                .frame(width: size.diameter, height: size.diameter)
                .frame(width: size.reserved, height: size.reserved)
                if showsLabels {
                    Text(title)
                        .careType(.itemLabel)
                        .foregroundStyle(CareColor.textSecondary)
                        .frame(maxWidth: itemWidth)
                }
            }
            .frame(width: itemWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.93))
        .accessibilityLabel(title)
    }
}

/// A long press that does not swallow the button's tap.
struct LongPressAction: ViewModifier {
    var action: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in action() }
        )
    }
}
