import Foundation

/// How a person relates to the user. Drives default modules, aura suggestions and copy.
public enum Relationship: String, Codable, CaseIterable, Sendable, Hashable {
    case me
    case partner
    case parent
    case child
    case sibling
    case friend
    case pet
    case client
    case other

    public var displayName: String {
        switch self {
        case .me: "Me"
        case .partner: "Partner"
        case .parent: "Parent"
        case .child: "Child"
        case .sibling: "Sibling"
        case .friend: "Friend"
        case .pet: "Pet"
        case .client: "Client"
        case .other: "Someone"
        }
    }

    /// A short line used under the name on a profile header.
    public var roleLine: String {
        switch self {
        case .me: "You"
        case .partner: "Partner"
        case .parent: "Parent"
        case .child: "Kid"
        case .sibling: "Sibling"
        case .friend: "Friend"
        case .pet: "Family, four legs"
        case .client: "Client"
        case .other: "Close to you"
        }
    }

    /// Modules switched on when a person of this relationship is created.
    public var defaultModules: [ModuleID] {
        switch self {
        case .me: [.mood, .health, .hydration, .dates, .travelPlans]
        case .partner: [.mood, .health, .mentions, .dates, .events, .sharedChecklist]
        case .parent: [.health, .dates, .callRhythm, .appointments, .medication]
        case .child: [.mood, .hydration, .events, .dates]
        case .sibling: [.dates, .events, .mentions]
        case .friend: [.dates, .mentions, .wishlist]
        case .pet: [.petCare, .dates, .appointments]
        case .client: [.appointments, .promises, .mentions]
        case .other: [.dates, .mentions]
        }
    }

    /// Modules the store suggests next for this relationship.
    public var suggestedModules: [ModuleID] {
        switch self {
        case .me: [.wishlist, .mentions]
        case .partner: [.travelPlans, .wishlist, .promises]
        case .parent: [.mentions, .travelPlans, .promises]
        case .child: [.wishlist, .health, .mentions]
        case .sibling: [.sharedChecklist, .travelPlans, .wishlist]
        case .friend: [.events, .travelPlans]
        case .pet: [.medication, .health]
        case .client: [.medication, .health]
        case .other: [.events, .wishlist]
        }
    }

    /// The pronoun set used in generated copy. Neutral by default.
    public var isHuman: Bool { self != .pet }
}
