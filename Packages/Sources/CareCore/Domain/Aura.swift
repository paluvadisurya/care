import Foundation

/// A two-colour gradient that belongs to one person. Tints their orb, header, cards and notifications.
/// Colours are hex strings so the type stays pure Swift; CareDesign turns them into `Color`.
public struct Aura: Codable, Hashable, Sendable {
    public var name: String
    public var start: String
    public var end: String

    public init(name: String, start: String, end: String) {
        self.name = name
        self.start = start
        self.end = end
    }

    // MARK: Presets. Six hues, one pair each. Semantic roles stay fixed elsewhere.

    public static let coralRose = Aura(name: "Coral Rose", start: "#FF6B57", end: "#FF4F8B")
    public static let violetLilac = Aura(name: "Violet Lilac", start: "#8B5CF6", end: "#C4B5FD")
    public static let amberCoral = Aura(name: "Amber Coral", start: "#FFB347", end: "#FF6B57")
    public static let mintSky = Aura(name: "Mint Sky", start: "#34D399", end: "#38BDF8")
    public static let skyViolet = Aura(name: "Sky Violet", start: "#38BDF8", end: "#8B5CF6")
    public static let ink = Aura(name: "Ink", start: "#15131C", end: "#5C5A6B")
    public static let honeyMint = Aura(name: "Honey Mint", start: "#F5C453", end: "#34D399")
    public static let roseViolet = Aura(name: "Rose Violet", start: "#FF4F8B", end: "#8B5CF6")

    public static let presets: [Aura] = [
        .coralRose, .violetLilac, .amberCoral, .mintSky, .skyViolet, .honeyMint, .roseViolet, .ink,
    ]

    /// A sensible default for a relationship. Callers rotate through the presets when several people share one.
    public static func suggested(for relationship: Relationship, index: Int = 0) -> Aura {
        let ordered: [Aura]
        switch relationship {
        case .me: ordered = [.ink, .skyViolet]
        case .partner: ordered = [.coralRose, .roseViolet]
        case .parent: ordered = [.skyViolet, .amberCoral]
        case .child: ordered = [.mintSky, .honeyMint]
        case .sibling: ordered = [.violetLilac, .skyViolet]
        case .friend: ordered = [.honeyMint, .mintSky]
        case .pet: ordered = [.amberCoral, .honeyMint]
        case .client: ordered = [.ink, .violetLilac]
        case .other: ordered = [.violetLilac, .mintSky]
        }
        return ordered[index % ordered.count]
    }
}
