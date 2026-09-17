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

}

/// Process-wide flag. Registration only ever runs on the main actor, so a plain static is enough
/// under MainActor default isolation.
enum FontRegistration {
    static var done = false
}
