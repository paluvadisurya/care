import Foundation

/// Stable identifier for a module. The raw value is stored on every entry, so never rename a case.
public enum ModuleID: String, Codable, CaseIterable, Sendable, Hashable, Comparable {
    // Wellbeing
    case mood, health, hydration, sleep, cycle
    // Moments
    case events, dates, travelPlans, travelLog, countdowns
    // Together
    case sharedChecklist, promises, mentions, callRhythm, intimacy
    // Care
    case medication, appointments, documents, school, notes, petCare
    // Taste
    case wishlist, favoriteBrands, foodAndPlaces, giftsAndBudget

    public static func < (lhs: ModuleID, rhs: ModuleID) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum ModuleCategory: String, Codable, CaseIterable, Sendable {
    case wellbeing, moments, together, care, taste

    public var displayName: String {
        switch self {
        case .wellbeing: "Wellbeing"
        case .moments: "Moments"
        case .together: "Together"
        case .care: "Care"
        case .taste: "Taste"
        }
    }
}

/// Paywall tier. Everything is unlocked in Phase 0; the label is rendered so the UI is ready for the switch.
public enum Tier: String, Codable, CaseIterable, Sendable {
    case core, plus, pro, later

    public var label: String {
        switch self {
        case .core: "Included"
        case .plus: "Plus"
        case .pro: "Pro"
        case .later: "Later"
        }
    }
}

/// Everything the store, Today and the insight engine need to know about a module without loading its code.
public struct ModuleMeta: Hashable, Sendable, Identifiable {
    public var id: ModuleID
    public var name: String
    public var symbol: String          // SF Symbol name
    public var emoji: String
    public var tagline: String         // one line for the store card
    public var category: ModuleCategory
    public var tier: Tier
    public var defaultFor: [Relationship]
    public var autoFills: Bool         // fills itself from Apple data when integrations arrive
    public var isImplemented: Bool     // false for modules that exist only as store cards today
    public var reminds: String         // human line: what reminders it can send
    public var insight: String         // human line: what the AI looks for

    public init(
        id: ModuleID, name: String, symbol: String, emoji: String, tagline: String,
        category: ModuleCategory, tier: Tier, defaultFor: [Relationship] = [],
        autoFills: Bool = false, isImplemented: Bool = true, reminds: String = "", insight: String = ""
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.emoji = emoji
        self.tagline = tagline
        self.category = category
        self.tier = tier
        self.defaultFor = defaultFor
        self.autoFills = autoFills
        self.isImplemented = isImplemented
        self.reminds = reminds
        self.insight = insight
    }
}

/// The full catalogue, including modules that are not built yet. The store renders every card.
public enum ModuleCatalog {
    public static let all: [ModuleMeta] = [
        // Wellbeing
        ModuleMeta(id: .mood, name: "Mood", symbol: "face.smiling", emoji: "🙂",
                   tagline: "Five states on the Pulse control, optional reason tag. A 14 day trail on the tile.",
                   category: .wellbeing, tier: .core, defaultFor: [.me, .partner, .child],
                   autoFills: true, reminds: "Three low days in a row, quiet week without a check-in",
                   insight: "Trend, dips by weekday, tag correlation, one suggestion"),
        ModuleMeta(id: .health, name: "Health", symbol: "heart.text.square", emoji: "💚",
                   tagline: "All good, neutral, not good. Symptom chips, BP and sugar readings, notes. Private by default.",
                   category: .wellbeing, tier: .core, defaultFor: [.me, .partner, .parent],
                   reminds: "Symptom past 3 days, follow-up on a noted worry",
                   insight: "Symptom streaks, reading ranges, a gentle doctor nudge"),
        ModuleMeta(id: .hydration, name: "Hydration", symbol: "drop.fill", emoji: "💧",
                   tagline: "Cup taps and a target ring. Logged for yourself or on behalf of kids and parents.",
                   category: .wellbeing, tier: .core, defaultFor: [.me, .child], autoFills: true,
                   reminds: "Adaptive to usual drinking times, quiet at night",
                   insight: "Hit rate, weak hours, best days"),
        ModuleMeta(id: .sleep, name: "Sleep and energy", symbol: "moon.zzz", emoji: "🌙",
                   tagline: "Self from Apple Health. Observed for others as an energy word.",
                   category: .wellbeing, tier: .plus, autoFills: true, isImplemented: false,
                   insight: "Sleep to mood correlation"),
        ModuleMeta(id: .cycle, name: "Cycle", symbol: "circle.dotted", emoji: "🌸",
                   tagline: "Self tracked, private by design, shareable only by explicit choice.",
                   category: .wellbeing, tier: .later, isImplemented: false),

        // Moments
        ModuleMeta(id: .events, name: "Events", symbol: "calendar", emoji: "🗓️",
                   tagline: "Anything happening in a person's life, classified into seven categories with the right nudges.",
                   category: .moments, tier: .core, defaultFor: [.partner, .child, .sibling], autoFills: true,
                   reminds: "Before, day of, and the after nudge: how did it go?",
                   insight: "Busy weeks ahead, support opportunities"),
        ModuleMeta(id: .dates, name: "Milestones and dates", symbol: "birthday.cake", emoji: "🎂",
                   tagline: "Birthdays, anniversaries, memorials. Countdown hero. Gift history so nothing repeats.",
                   category: .moments, tier: .core,
                   defaultFor: [.me, .partner, .parent, .child, .sibling, .friend, .pet], autoFills: true,
                   reminds: "14 days, 3 days, day of",
                   insight: "Connects mentions and wishlist to the next date"),
        ModuleMeta(id: .travelPlans, name: "Travel plans", symbol: "airplane.departure", emoji: "✈️",
                   tagline: "Upcoming trips, packing list, who is going, an away state that pauses other nudges.",
                   category: .moments, tier: .core, defaultFor: [.me], autoFills: true,
                   reminds: "7 days pack, day before, safe arrival, welcome home",
                   insight: "Packing gaps, things they mentioned wanting to do there"),
        ModuleMeta(id: .travelLog, name: "Travel log", symbol: "map", emoji: "🗺️",
                   tagline: "Where you have been, together or apart. Built from Photos, confirmed with one tap.",
                   category: .moments, tier: .plus, autoFills: true, isImplemented: false,
                   insight: "Two years since Goa, places you both loved"),
        ModuleMeta(id: .countdowns, name: "Countdowns", symbol: "timer", emoji: "⏳",
                   tagline: "A pinned big numeral for the one thing that matters most right now.",
                   category: .moments, tier: .core, isImplemented: false),

        // Together
        ModuleMeta(id: .sharedChecklist, name: "Shared checklist", symbol: "checklist", emoji: "✅",
                   tagline: "A list between you and this person: errands, chores, party prep.",
                   category: .together, tier: .core, defaultFor: [.partner], autoFills: true,
                   reminds: "Due items, stale items after 14 days",
                   insight: "Who did what this month, what is stuck"),
        ModuleMeta(id: .promises, name: "Promises", symbol: "hand.raised.fingers.spread", emoji: "🤞",
                   tagline: "Things you said you would do. Gentle follow-up, never nagging.",
                   category: .together, tier: .core, defaultFor: [.client],
                   reminds: "Due date, then a soft weekly nudge",
                   insight: "Open promises by age"),
        ModuleMeta(id: .mentions, name: "Mentions", symbol: "quote.bubble", emoji: "📝",
                   tagline: "Tiny notes of what they said, want, like, dislike or worry about. Resurfaced when useful.",
                   category: .together, tier: .core, defaultFor: [.partner, .sibling, .friend, .client],
                   autoFills: true, reminds: "A worry not followed up in 7 days",
                   insight: "Gift ideas, talking points, unresolved worries"),
        ModuleMeta(id: .callRhythm, name: "Call rhythm", symbol: "phone.arrow.up.right", emoji: "📞",
                   tagline: "Every Sunday for Mom. Nudges before the rhythm slips, with talking points ready.",
                   category: .together, tier: .core, defaultFor: [.parent],
                   reminds: "Rhythm day at the preferred time",
                   insight: "Gaps, best times"),
        ModuleMeta(id: .intimacy, name: "Intimacy", symbol: "lock.heart", emoji: "🔒",
                   tagline: "Adult partners only, both opt in. Face ID locked. Never in previews.",
                   category: .together, tier: .plus, isImplemented: false),

        // Care
        ModuleMeta(id: .medication, name: "Medication", symbol: "pills", emoji: "💊",
                   tagline: "Medicines, doses, schedule, taken or missed, refill date. Adherence ring.",
                   category: .care, tier: .core, defaultFor: [.parent],
                   reminds: "Dose time, refill 5 days ahead",
                   insight: "Missed-dose patterns by day"),
        ModuleMeta(id: .appointments, name: "Appointments", symbol: "stethoscope", emoji: "🩺",
                   tagline: "Doctors, next visit, questions to ask, what was said. A brief before each visit.",
                   category: .care, tier: .core, defaultFor: [.parent, .pet, .client], autoFills: true,
                   reminds: "Day before, follow-up booking",
                   insight: "Visit prep from Health and Medication"),
        ModuleMeta(id: .petCare, name: "Pet care", symbol: "pawprint", emoji: "🐾",
                   tagline: "Vet checks, vaccines, deworming, grooming, food orders and medicines for the furry one.",
                   category: .care, tier: .core, defaultFor: [.pet],
                   reminds: "Vet check due, food running low, deworming day",
                   insight: "Weight trend, what is due this month"),
        ModuleMeta(id: .documents, name: "Documents", symbol: "doc.text", emoji: "📄",
                   tagline: "Insurance, IDs, prescriptions per person. Encrypted, Face ID locked.",
                   category: .care, tier: .plus, isImplemented: false),
        ModuleMeta(id: .school, name: "School", symbol: "backpack", emoji: "🎒",
                   tagline: "Exams, subjects, results, teacher meetings. Night-before and after nudges.",
                   category: .care, tier: .plus, isImplemented: false),
        ModuleMeta(id: .notes, name: "Notes", symbol: "note.text", emoji: "🗂️",
                   tagline: "Longer notes with templates for visits and handovers. Strict per-person separation.",
                   category: .care, tier: .pro, isImplemented: false),

        // Taste
        ModuleMeta(id: .wishlist, name: "Wishlist", symbol: "gift", emoji: "🎁",
                   tagline: "Share any product link. Sizes, colours, a please-do-not-buy list. Claim items so gifts never double up.",
                   category: .taste, tier: .core, defaultFor: [.friend], autoFills: true,
                   insight: "Items in budget before the next date"),
        ModuleMeta(id: .favoriteBrands, name: "Favourite brands", symbol: "bag", emoji: "🛍️",
                   tagline: "Brands, sizes and styles per person. Builds a simple style profile.",
                   category: .taste, tier: .plus, isImplemented: false),
        ModuleMeta(id: .foodAndPlaces, name: "Food and places", symbol: "fork.knife", emoji: "🍜",
                   tagline: "Favourite dishes, allergies, restaurants they love, places to try.",
                   category: .taste, tier: .plus, isImplemented: false),
        ModuleMeta(id: .giftsAndBudget, name: "Gifts and budget", symbol: "creditcard", emoji: "💸",
                   tagline: "Yearly gift budget per person and a history of what was given.",
                   category: .taste, tier: .later, isImplemented: false),
    ]

    public static func meta(_ id: ModuleID) -> ModuleMeta {
        all.first { $0.id == id } ?? ModuleMeta(id: id, name: id.rawValue, symbol: "square", emoji: "▫️",
                                                 tagline: "", category: .care, tier: .later, isImplemented: false)
    }

    public static func modules(in category: ModuleCategory) -> [ModuleMeta] {
        all.filter { $0.category == category }
    }
}
