import SwiftUI
import CareCore

/// The primary action. One height, one radius, one press behaviour, four fills.
public struct PillButton: View {
    public enum Style: Sendable {
        /// Ink fill. The single primary action on a screen or sheet.
        case ink
        /// Quiet fill. Secondary actions.
        case ghost
        /// The person's aura. Used when the action is about one person.
        case aura(Aura)
        /// Liquid Glass. Floating actions over content.
        case glass
    }

    @ScaledMetric(relativeTo: .body) private var fullHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .subheadline) private var compactHeight: CGFloat = 38

    public var title: String
    public var symbol: String?
    public var style: Style
    public var isCompact: Bool
    public var action: () -> Void

    public init(_ title: String, symbol: String? = nil, style: Style = .ink, compact: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.style = style
        self.isCompact = compact
        self.action = action
    }

    private var height: CGFloat { isCompact ? compactHeight : fullHeight }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: CareSpace.xs) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                }
                Text(title)
                    .careType(isCompact ? .chipLabel : .buttonLabel)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, isCompact ? CareSpace.sm + 2 : CareSpace.lg)
            .frame(maxWidth: isCompact ? nil : .infinity)
            .frame(height: height)
            .background(background, in: Capsule())
            .overlay {
                if case .ghost = style { Capsule().strokeBorder(CareColor.separator, lineWidth: 1) }
            }
            // Reserve the minimum target even when the pill draws shorter.
            .frame(minHeight: CareLayout.touchTarget)
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .modifier(GlassIfNeeded(isGlass: isGlass))
    }

    private var isGlass: Bool { if case .glass = style { true } else { false } }

    private var foreground: Color {
        switch style {
        case .ink: CareColor.inkText
        case .ghost, .glass: CareColor.textPrimary
        case .aura: .white
        }
    }

    private var background: AnyShapeStyle {
        switch style {
        case .ink: AnyShapeStyle(CareColor.ink)
        case .ghost: AnyShapeStyle(CareColor.chip)
        case .glass: AnyShapeStyle(Color.clear)
        case .aura(let aura): AnyShapeStyle(aura.gradient)
        }
    }
}

struct GlassIfNeeded: ViewModifier {
    var isGlass: Bool

    func body(content: Content) -> some View {
        content.glassEffect(isGlass ? .regular.interactive() : .identity, in: .capsule)
    }
}

/// A round icon control. Always 44 pt, always labelled.
public struct IconButton: View {
    public var symbol: String
    public var label: String
    public var isProminent: Bool
    public var action: () -> Void

    public init(_ symbol: String, label: String, isProminent: Bool = false, action: @escaping () -> Void) {
        self.symbol = symbol
        self.label = label
        self.isProminent = isProminent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isProminent ? CareColor.inkText : CareColor.textPrimary)
                .frame(width: CareLayout.touchTarget, height: CareLayout.touchTarget)
                .background(isProminent ? CareColor.ink : CareColor.chip, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.pressable(scale: 0.9))
        .accessibilityLabel(label)
    }
}
