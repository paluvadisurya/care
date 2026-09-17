import SwiftUI
import CareCore
import CareDesign
import CareData

/// The visual half of a module. Keyed by the same `ModuleID` as its logic in CareCore.
public protocol ModuleUI {
    static var id: ModuleID { get }
    /// The bento tile. Default renders the logic's today state.
    @MainActor static func tile(person: PersonRecord, state: ModuleTodayState) -> AnyView
    /// The one-gesture log sheet. Nil when the module logs from its detail screen only.
    @MainActor static func quickLog(person: PersonRecord, prefill: String?) -> AnyView?
    /// The full screen.
    @MainActor static func detail(person: PersonRecord) -> AnyView
}

public extension ModuleUI {
    static var meta: ModuleMeta { ModuleCatalog.meta(id) }

    @MainActor static func tile(person: PersonRecord, state: ModuleTodayState) -> AnyView {
        AnyView(BentoTile(title: meta.name, symbol: meta.symbol, state: state, accent: ModuleAccent.color(for: id)))
    }

    @MainActor static func quickLog(person: PersonRecord, prefill: String?) -> AnyView? { nil }
}

/// One accent per module category, so tiles read as a system rather than a rainbow.
public enum ModuleAccent {
    public static func color(for module: ModuleID) -> Color {
        switch ModuleCatalog.meta(module).category {
        case .wellbeing: CareColor.mint
        case .moments: CareColor.amber
        case .together: CareColor.violet
        case .care: CareColor.coral
        case .taste: CareColor.sky
        }
    }
}

/// Every module UI the app knows. Adding a module: one logic type in CareCore, one UI type here.
public enum ModuleUIRegistry {
    public static let all: [any ModuleUI.Type] = [
        MoodUI.self, HealthUI.self, HydrationUI.self, MentionsUI.self, DatesUI.self, EventsUI.self,
        MedicationUI.self, AppointmentsUI.self, CallRhythmUI.self, TravelPlansUI.self,
        SharedChecklistUI.self, PromisesUI.self, WishlistUI.self, PetCareUI.self,
    ]

    public static func ui(for id: ModuleID) -> (any ModuleUI.Type)? {
        all.first { $0.id == id }
    }
}

/// Where a module screen is opened from. Drives the navigation destination in the app.
public struct ModuleRoute: Hashable, Identifiable {
    public var personID: UUID
    public var module: ModuleID
    public var id: String { "\(personID).\(module.rawValue)" }
    public init(personID: UUID, module: ModuleID) {
        self.personID = personID
        self.module = module
    }
}

/// A quick log request, presented as a sheet.
public struct QuickLogRequest: Hashable, Identifiable {
    public var personID: UUID
    public var module: ModuleID?
    public var prefill: String?
    public var id: String { "\(personID).\(module?.rawValue ?? "quick").\(prefill ?? "")" }
    public init(personID: UUID, module: ModuleID? = nil, prefill: String? = nil) {
        self.personID = personID
        self.module = module
        self.prefill = prefill
    }
}

/// Resolves a route to its detail view.
public struct ModuleDetailView: View {
    @Environment(CareStore.self) private var store
    public var route: ModuleRoute

    public init(route: ModuleRoute) { self.route = route }

    public var body: some View {
        if let person = store.person(route.personID), let ui = ModuleUIRegistry.ui(for: route.module) {
            ui.detail(person: person)
        } else {
            EmptyState(symbol: "questionmark.square.dashed", title: "Not here yet", message: "This module has a store card but no screen in this build.")
        }
    }
}

/// Resolves a quick log request to a sheet.
public struct QuickLogSheet: View {
    @Environment(CareStore.self) private var store
    public var request: QuickLogRequest

    public init(request: QuickLogRequest) { self.request = request }

    public var body: some View {
        if let person = store.person(request.personID) {
            if let module = request.module, let ui = ModuleUIRegistry.ui(for: module), let view = ui.quickLog(person: person, prefill: request.prefill) {
                view
            } else if let module = request.module, let ui = ModuleUIRegistry.ui(for: module) {
                NavigationStack { ui.detail(person: person) }
            } else {
                QuickSheetView(person: person)
            }
        }
    }
}
