import SwiftUI
import CareCore

/// A row that wraps instead of squeezing.
///
/// An `HStack` of chips or badges has one answer when its children do not fit: compress them until the
/// text truncates. In a grid tile that also means the row's minimum width can push a column wider than
/// its share. This lays the children out left to right and starts a new line when the next one would not
/// fit, so a badge row, a tag list or a set of symptom chips stays readable at any Dynamic Type size, in
/// any language, on any screen width.
public nonisolated struct FlowLayout: Layout {
    public var spacing: CGFloat
    public var lineSpacing: CGFloat
    public var alignment: HorizontalAlignment

    public init(spacing: CGFloat = CareSpace.xs, lineSpacing: CGFloat? = nil,
                alignment: HorizontalAlignment = .leading) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing ?? spacing
        self.alignment = alignment
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let lines = wrap(subviews: subviews, in: width)
        let height = lines.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, lines.count - 1))
        let widest = lines.map(\.width).max() ?? 0
        return CGSize(width: min(width, max(widest, 0)), height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                              subviews: Subviews, cache: inout ()) {
        let lines = wrap(subviews: subviews, in: bounds.width)
        var y = bounds.minY
        for line in lines {
            var x = bounds.minX + leadingInset(for: line.width, in: bounds.width)
            for index in line.range {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private func leadingInset(for lineWidth: CGFloat, in total: CGFloat) -> CGFloat {
        switch alignment {
        case .center: max(0, (total - lineWidth) / 2)
        case .trailing: max(0, total - lineWidth)
        default: 0
        }
    }

    private struct Line {
        var range: Range<Int>
        var width: CGFloat
        var height: CGFloat
    }

    private func wrap(subviews: Subviews, in width: CGFloat) -> [Line] {
        var lines: [Line] = []
        var start = 0
        var x: CGFloat = 0
        var height: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = x == 0 ? size.width : x + spacing + size.width
            if needed > width, index > start {
                lines.append(Line(range: start..<index, width: x, height: height))
                start = index
                x = size.width
                height = size.height
            } else {
                x = needed
                height = max(height, size.height)
            }
        }
        if start < subviews.endIndex {
            lines.append(Line(range: start..<subviews.endIndex, width: x, height: height))
        }
        return lines
    }
}

/// A symbol in its rounded square. One definition, so a module reads the same in a list, in the store,
/// on an onboarding card and anywhere it appears next.
///
/// Two fills: tinted, where the square is a wash of the symbol's own colour, and aura, where the square
/// carries a person's gradient and the symbol goes white.
public struct GlyphTile: View {
    public enum Fill {
        case tint(Color)
        case aura(Aura)
    }

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 36
    public var symbol: String
    public var fill: Fill
    public var scale: CGFloat

    public init(symbol: String, fill: Fill, scale: CGFloat = 1) {
        self.symbol = symbol
        self.fill = fill
        self.scale = scale
    }

    public init(symbol: String, tint: Color, scale: CGFloat = 1) {
        self.init(symbol: symbol, fill: .tint(tint), scale: scale)
    }

    public init(symbol: String, aura: Aura, scale: CGFloat = 1) {
        self.init(symbol: symbol, fill: .aura(aura), scale: scale)
    }

    private var foreground: Color {
        if case .tint(let color) = fill { return color }
        return .white
    }

    public var body: some View {
        let size = side * scale
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        return Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background {
                switch fill {
                case .tint(let color): shape.fill(color.opacity(0.13))
                case .aura(let aura): shape.fill(aura.gradient)
                }
            }
            .accessibilityHidden(true)
    }
}
