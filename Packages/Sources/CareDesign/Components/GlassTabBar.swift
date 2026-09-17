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

/// Today, People, Timeline, You in a Liquid Glass pill. The selection highlight morphs between items.
public struct GlassTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassSpace
    public var tabs: [CareTab]
    @Binding public var selection: String

    public init(tabs: [CareTab], selection: Binding<String>) {
        self.tabs = tabs
        _selection = selection
    }

    public var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(tabs) { tab in
                    let isOn = tab.id == selection
                    Button {
                        withAnimation(CareMotion.standard(reduced: reduceMotion)) { selection = tab.id }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: isOn ? tab.selectedSymbol : tab.symbol)
                                .font(.system(size: 17, weight: .semibold))
                                .symbolEffect(.bounce, value: isOn)
                            Text(tab.title)
                                .font(CareFont.tab)
                        }
                        .foregroundStyle(isOn ? CareColor.textPrimary : CareColor.textMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background {
                            if isOn {
                                Capsule()
                                    .fill(CareColor.chip)
                                    .matchedGeometryEffect(id: "tab.selection", in: glassSpace)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.pressable(scale: 0.94))
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
                }
            }
            .padding(5)
            .glassEffect(.regular, in: .capsule)
        }
        .sensoryFeedback(.selection, trigger: selection)
        .padding(.horizontal, CareSpace.lg)
    }
}
