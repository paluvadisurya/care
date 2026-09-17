import SwiftUI
import CoreText

/// Care's type system. Four families, each with one job:
/// Bricolage Grotesque for headlines and big numerals, Geist for everything you read, Geist Mono for tiny metadata,
/// Instrument Serif italic for the one accent word per screen. All scale with Dynamic Type.
public enum CareFont {
    public static let displayName = "BricolageGrotesque-ExtraBold"
    public static let displayBoldName = "BricolageGrotesque-Bold"
    public static let displaySemiBoldName = "BricolageGrotesque-SemiBold"
    public static let textName = "Geist-Regular"
    public static let textMediumName = "Geist-Medium"
    public static let textSemiBoldName = "Geist-SemiBold"
    public static let textBoldName = "Geist-Bold"
    public static let monoName = "GeistMono-Regular"
    public static let monoMediumName = "GeistMono-Medium"
    public static let serifItalicName = "InstrumentSerif-Italic"
    public static let serifName = "InstrumentSerif-Regular"

    private static let fileNames = [
        "BricolageGrotesque-ExtraBold", "BricolageGrotesque-Bold", "BricolageGrotesque-SemiBold",
        "Geist-Regular", "Geist-Medium", "Geist-SemiBold", "Geist-Bold",
        "GeistMono-Regular", "GeistMono-Medium", "InstrumentSerif-Italic", "InstrumentSerif-Regular",
    ]

    /// Registers the bundled fonts once. Safe to call repeatedly; the app calls it at launch and previews call it lazily.
    public static func registerFonts() {
        guard !FontRegistration.done else { return }
        FontRegistration.done = true
        for name in fileNames {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    // MARK: Display (headlines, numerals)

    public static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        registerFonts()
        return .custom(displayName, size: size, relativeTo: style)
    }

    public static func displayBold(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        registerFonts()
        return .custom(displayBoldName, size: size, relativeTo: style)
    }

    public static func displaySemi(_ size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        registerFonts()
        return .custom(displaySemiBoldName, size: size, relativeTo: style)
    }

    // MARK: Text

    public static func text(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        registerFonts()
        return .custom(textName, size: size, relativeTo: style)
    }

    public static func textMedium(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        registerFonts()
        return .custom(textMediumName, size: size, relativeTo: style)
    }

    public static func textSemi(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        registerFonts()
        return .custom(textSemiBoldName, size: size, relativeTo: style)
    }

    public static func textBold(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        registerFonts()
        return .custom(textBoldName, size: size, relativeTo: style)
    }

    // MARK: Mono and serif accents

    public static func mono(_ size: CGFloat, relativeTo style: Font.TextStyle = .caption) -> Font {
        registerFonts()
        return .custom(monoName, size: size, relativeTo: style)
    }

    public static func monoMedium(_ size: CGFloat, relativeTo style: Font.TextStyle = .caption) -> Font {
        registerFonts()
        return .custom(monoMediumName, size: size, relativeTo: style)
    }

    public static func serifItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        registerFonts()
        return .custom(serifItalicName, size: size, relativeTo: style)
    }

    // MARK: Presets. Sizes in points at the default Dynamic Type size.

    public static let screenTitle = display(34)                      // "Good morning, Surya"
    public static let personName = display(36)                       // aura header
    public static let heroNumeral = display(64, relativeTo: .largeTitle)
    public static let cardTitle = displayBold(20, relativeTo: .title3)
    public static let tileValue = displayBold(22, relativeTo: .title2)
    public static let body = text(16)
    public static let bodyMedium = textMedium(16)
    public static let callout = text(15, relativeTo: .callout)
    public static let label = textMedium(13, relativeTo: .subheadline)
    public static let labelSemi = textSemi(13, relativeTo: .subheadline)
    public static let caption = text(12, relativeTo: .caption)
    public static let meta = mono(11, relativeTo: .caption2)
    public static let button = textSemi(16, relativeTo: .body)
    public static let chip = textMedium(13, relativeTo: .subheadline)
    public static let tab = textMedium(11, relativeTo: .caption)
}

/// Process-wide flag. Registration only ever runs on the main actor, so a plain static is enough under MainActor default isolation.
enum FontRegistration {
    static var done = false
}

public extension View {
    /// Tight tracking for headlines, minus 3 to 4 percent, as the spec asks.
    func displayTracking(_ size: CGFloat) -> some View {
        tracking(-size * 0.035)
    }

    /// Numerals track tighter still and always use tabular figures.
    func numeralStyle(_ size: CGFloat) -> some View {
        tracking(-size * 0.05).monospacedDigit()
    }
}
