import SwiftUI
import CareCore

/// Primary action. Ink fill, 52 pt, scale 0.96 on press. Ghost and aura variants for secondary actions.
public struct PillButton: View {
    public enum Style { case ink, ghost, aura(Aura), glass }

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

    public var body: some View {
        Button(action: action) {
            HStack(spacing: CareSpace.xs) {
                if let symbol { Image(systemName: symbol).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(isCompact ? CareFont.chip : CareFont.button)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, isCompact ? CareSpace.sm : CareSpace.lg)
            .frame(maxWidth: isCompact ? nil : .infinity)
            .frame(height: isCompact ? 36 : 52)
            .background(background, in: Capsule())
            .overlay {
                if case .ghost = style { Capsule().strokeBorder(CareColor.separator, lineWidth: 1) }
            }
        }
        .buttonStyle(.pressable)
        .modifier(GlassIfNeeded(isGlass: { if case .glass = style { return true } else { return false } }()))
    }

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
        case .glass: AnyShapeStyle(.clear)
        case .aura(let aura): AnyShapeStyle(aura.gradient)
        }
    }
}

struct GlassIfNeeded: ViewModifier {
    var isGlass: Bool
    func body(content: Content) -> some View {
        if isGlass {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
        }
    }
}

/// Small round icon button, used in headers and rows.
public struct IconButton: View {
    public var symbol: String
    public var label: String
    public var action: () -> Void

    public init(_ symbol: String, label: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CareColor.textPrimary)
                .frame(width: 44, height: 44)
                .background(CareColor.chip, in: Circle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }
}
