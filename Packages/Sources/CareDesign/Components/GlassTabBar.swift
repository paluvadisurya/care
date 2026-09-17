import SwiftUI

/// A tab in the floating bar.
public struct CareTab: Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var symbol: String
    public var selectedSymbol: String

    public init(id: String, title: String, symbol: String, selectedSymbol: String? = nil) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.selectedSymbol = selectedSymbol ?? symbol + ".fill"
    }
}

/// Today, People, Timeline, You in a Liquid Glass pill that floats over the content.
///
/// The selection highlight is one shape that moves between items rather than four that fade, so switching
/// tabs reads as a single object travelling rather than a cross dissolve.
public struct GlassTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionSpace

    public var tabs: [CareTab]
    @Binding public var selection: String
    /// Tabs that carry something needing attention get a small coral dot.
    public var badged: Set<String>

    public init(tabs: [CareTab], selection: Binding<String>, badged: Set<String> = []) {
        self.tabs = tabs
        _selection = selection
        self.badged = badged
    }

    public var body: some View {
        GlassEffectContainer(spacing: CareSpace.xs) {
            HStack(spacing: 2) {
                ForEach(tabs) { tab in
                    item(tab)
                }
            }
            .padding(5)
            .glassEffect(.regular, in: .capsule)
        }
        .sensoryFeedback(.selection, trigger: selection)
        .padding(.horizontal, CareSpace.lg)
        .accessibilityElement(children: .contain)
    }

    private func item(_ tab: CareTab) -> some View {
        let isOn = tab.id == selection
        return Button {
            guard !isOn else { return }
            withAnimation(CareMotion.standard(reduced: reduceMotion)) { selection = tab.id }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isOn ? tab.selectedSymbol : tab.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolEffect(.bounce, value: isOn)
                    .overlay(alignment: .topTrailing) {
                        if badged.contains(tab.id), !isOn {
                            Circle()
                                .fill(CareColor.attention)
                                .frame(width: 6, height: 6)
                                .offset(x: 4, y: -2)
                        }
                    }
                Text(tab.title)
                    .careType(.tabLabel)
            }
            .foregroundStyle(isOn ? CareColor.textPrimary : CareColor.textMuted)
            .frame(maxWidth: .infinity)
            .frame(height: CareLayout.tabBarHeight - 10)
            .background {
                if isOn {
                    Capsule()
                        .fill(CareColor.chip)
                        .matchedGeometryEffect(id: "tab.selection", in: selectionSpace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable(scale: 0.94))
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}
