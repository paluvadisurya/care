import SwiftUI

/// Semantic type roles. Every piece of text in Care picks a role, never a raw size, so tracking,
/// truncation and Dynamic Type behaviour stay consistent across the app.
///
/// Four families, each with one job:
/// - Bricolage Grotesque: headlines and numerals, tight tracking
/// - Geist: everything you read
/// - Geist Mono: metadata, times, counts that sit beside prose
/// - Instrument Serif italic: exactly one accent word per screen
public enum CareType: Sendable, Hashable, CaseIterable {
    // Numerals. Tabular figures, tightest tracking, they roll rather than blink.
    case heroNumeral        // the one big number on a screen
    case numeral            // countdowns and ring centres
    case numeralCompact     // inline counts

    // Display. Bricolage Grotesque.
    case screenTitle        // "Good morning, Surya"
    case sheetTitle         // sheet and module screen headers
    case cardTitle          // insight headline, hero card body
    case tileValue          // the state word on a bento tile
    case accent             // Instrument Serif italic, pairs with screenTitle

    // Text. Geist.
    case body
    case bodyEmphasis
    case callout            // supporting sentence under a title
    case label              // section and field labels
    case labelEmphasis
    case caption            // helper text under a value

    // Mono. Geist Mono.
    case meta               // timestamps, "refreshed 6h ago"
    case metaEmphasis       // times on the timeline rail

    // Controls.
    case buttonLabel
    case chipLabel
    case tabLabel

    /// Size in points at the default Dynamic Type setting.
    public var size: CGFloat {
        switch self {
        case .heroNumeral: 56
        case .numeral: 38
        case .numeralCompact: 20
        case .screenTitle: 33
        case .sheetTitle: 27
        case .cardTitle: 20
        case .tileValue: 19
        case .accent: 36
        case .body: 16
        case .bodyEmphasis: 16
        case .callout: 15
        case .label: 13
        case .labelEmphasis: 13
        case .caption: 12
        case .meta: 11
        case .metaEmphasis: 11
        case .buttonLabel: 16
        case .chipLabel: 13
        case .tabLabel: 11
        }
    }

    /// Tracking as a fraction of the size. Headlines run tight, numerals tighter, body stays neutral.
    public var trackingRatio: CGFloat {
        switch self {
        case .heroNumeral, .numeral: -0.05
        case .numeralCompact: -0.04
        case .screenTitle, .sheetTitle: -0.035
        case .cardTitle, .tileValue: -0.03
        case .accent: -0.01
        default: 0
        }
    }

    /// How many lines the role may occupy before it truncates or scales.
    public var lineLimit: Int? {
        switch self {
        case .heroNumeral, .numeral, .numeralCompact, .tileValue: 1
        case .screenTitle, .accent: 2
        case .sheetTitle, .cardTitle: 3
        case .label, .labelEmphasis, .chipLabel, .tabLabel, .meta, .metaEmphasis: 1
        case .caption: 2
        default: nil
        }
    }

    /// Single-line roles shrink to fit rather than truncate, so a long value still reads as one line.
    public var minimumScaleFactor: CGFloat {
        switch self {
        case .heroNumeral, .numeral, .numeralCompact: 0.6
        case .tileValue: 0.65
        case .screenTitle, .sheetTitle, .accent: 0.75
        case .cardTitle: 0.85
        default: 1
        }
    }

    public var isTabular: Bool {
        switch self {
        case .heroNumeral, .numeral, .numeralCompact, .metaEmphasis: true
        default: false
        }
    }

    /// The Dynamic Type style this role scales against.
    public var textStyle: Font.TextStyle {
        switch self {
        case .heroNumeral, .accent: .largeTitle
        case .numeral, .screenTitle: .title
        case .sheetTitle: .title2
        case .cardTitle, .numeralCompact: .title3
        case .tileValue: .headline
        case .body, .bodyEmphasis, .buttonLabel: .body
        case .callout: .callout
        case .label, .labelEmphasis, .chipLabel: .subheadline
        case .caption: .caption
        case .meta, .metaEmphasis, .tabLabel: .caption2
        }
    }

    public var font: Font {
        switch self {
        case .heroNumeral, .numeral, .numeralCompact:
            CareFont.display(size, relativeTo: textStyle)
        case .screenTitle:
            CareFont.display(size, relativeTo: textStyle)
        case .sheetTitle, .cardTitle, .tileValue:
            CareFont.displayBold(size, relativeTo: textStyle)
        case .accent:
            CareFont.serifItalic(size, relativeTo: textStyle)
        case .body, .callout, .caption:
            CareFont.text(size, relativeTo: textStyle)
        case .bodyEmphasis, .label, .chipLabel, .tabLabel:
            CareFont.textMedium(size, relativeTo: textStyle)
        case .labelEmphasis, .buttonLabel:
            CareFont.textSemi(size, relativeTo: textStyle)
        case .meta:
            CareFont.mono(size, relativeTo: textStyle)
        case .metaEmphasis:
            CareFont.monoMedium(size, relativeTo: textStyle)
        }
    }
}

/// Applies a type role: font, tracking that scales with Dynamic Type, line limit, scale floor and figure style.
public struct CareTypeModifier: ViewModifier {
    @ScaledMetric private var typeScale: CGFloat = 1
    public var role: CareType

    public init(role: CareType) { self.role = role }

    public func body(content: Content) -> some View {
        content
            .font(role.font)
            .tracking(role.size * role.trackingRatio * typeScale)
            .lineLimit(role.lineLimit)
            .minimumScaleFactor(role.minimumScaleFactor)
            .monospacedDigit(role.isTabular)
    }
}

public extension View {
    /// The only way text is styled in Care.
    func careType(_ role: CareType) -> some View {
        modifier(CareTypeModifier(role: role))
    }

    /// Tabular figures only when the role asks for them.
    @ViewBuilder
    func monospacedDigit(_ enabled: Bool) -> some View {
        if enabled { self.monospacedDigit() } else { self }
    }

    /// Numbers that change roll their digits instead of blinking.
    func rollingNumber() -> some View {
        contentTransition(.numericText())
    }
}
