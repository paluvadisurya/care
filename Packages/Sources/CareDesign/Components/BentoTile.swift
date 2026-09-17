import SwiftUI
import CareCore

/// One module, as it appears on Today and on a person's profile.
///
/// The tile is a fixed three-zone grid: a label row, a value row, and an optional trail. Its minimum height
/// scales with Dynamic Type and it stretches to fill its grid row, so two tiles side by side always match
/// and a long value scales within one line instead of wrapping and pushing its neighbour out of alignment.
public struct BentoTile: View {
    @ScaledMetric(relativeTo: .headline) private var minHeight: CGFloat = 112

    public var title: String
    public var symbol: String
    public var state: ModuleTodayState
    public var accent: Color
    /// Shown as a small aura dot before the title, for tiles that belong to a person on a shared screen.
    public var aura: Aura?

    public init(title: String, symbol: String, state: ModuleTodayState, accent: Color = CareColor.violet, aura: Aura? = nil) {
        self.title = title
        self.symbol = symbol
        self.state = state
        self.accent = accent
        self.aura = aura
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            labelRow
            valueRow
            if !state.trail.isEmpty {
                MoodStrip(values: state.trail, height: 20)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
        .careSurface(.tile)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(state.headline). \(state.detail)")
    }

    private var labelRow: some View {
        HStack(spacing: 6) {
            if let aura {
                Circle()
                    .fill(aura.gradient)
                    .frame(width: 9, height: 9)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 11)
            }
            Text(title)
                .careType(.label)
                .foregroundStyle(CareColor.textSecondary)
            Spacer(minLength: 0)
            if state.needsAttention {
                AttentionDot(diameter: 9)
            }
        }
        .frame(height: 16)
    }

    private var valueRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: CareSpace.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(state.headline)
                    .careType(.tileValue)
                    .foregroundStyle(state.tone == .attention ? CareColor.attention : CareColor.textPrimary)
                    .rollingNumber()
                Text(state.detail)
                    .careType(.caption)
                    .foregroundStyle(CareColor.textMuted)
            }
            Spacer(minLength: 0)
            if let progress = state.progress {
                Ring(bare: progress, size: .tile, gradient: [accent, accent.opacity(0.55)])
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] * 0.72 }
            }
        }
    }
}

/// The dashed "add a module" tile that closes a bento grid. Matches tile metrics exactly so the grid stays even.
public struct AddTile: View {
    @ScaledMetric(relativeTo: .headline) private var minHeight: CGFloat = 112
    public var title: String
    public var action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .careType(.label)
            }
            .foregroundStyle(CareColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: CareRadius.tile)
                    .strokeBorder(CareColor.separator, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .contentShape(RoundedRectangle(cornerRadius: CareRadius.tile))
        }
        .buttonStyle(.pressable(scale: 0.97))
    }
}

/// The two column grid every bento uses. One definition, so column widths and gutters never drift.
public struct BentoGrid<Content: View>: View {
    public var content: Content

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public static var columns: [GridItem] {
        [GridItem(.flexible(), spacing: CareLayout.tileGap),
         GridItem(.flexible(), spacing: CareLayout.tileGap)]
    }

    public var body: some View {
        LazyVGrid(columns: Self.columns, spacing: CareLayout.tileGap) {
            content
        }
    }
}
