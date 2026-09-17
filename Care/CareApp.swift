import SwiftUI
import SwiftData
import CareCore
import CareDesign
import CareData
import CareIntelligence

@main
struct CareApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var services: AppServices

    init() {
        CareFont.registerFonts()
        let s = AppServices()
        self.services = s
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services.store)
                .environment(services.prefs)
                .environment(services.insights)
                .environment(services.router)
                .preferredColorScheme(services.prefs.appearance == .system ? nil : (services.prefs.appearance == .night ? .dark : .light))
                .tint(CareColor.ink)
                .onOpenURL { url in
                    if let link = DeepLink(url: url) { services.router.handle(link) }
                }
                .task { services.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { services.foreground() }
        }
    }
}

/// Wires the store, preferences, intelligence and reminders together once per launch.
@Observable
final class AppServices {
    let store: CareStore
    let prefs: AppPreferences
    let insights: InsightCoordinator
    let router: AppRouter
    let secrets: any SecretStore
    let reminders = ReminderScheduler()

    init() {
        let container: ModelContainer
        do {
            container = try CareModelContainer.make()
        } catch {
            // A broken store should never brick the app. Fall back to memory and tell the user in You.
            container = (try? CareModelContainer.make(inMemory: true)) ?? { fatalError("SwiftData unavailable: \(error)") }()
        }
        let prefs = AppPreferences()
        let store = CareStore(container: container)
        let secrets: any SecretStore = KeychainSecretStore()
        self.prefs = prefs
        self.store = store
        self.secrets = secrets
        self.insights = InsightCoordinator(store: store, prefs: prefs, secrets: secrets)
        self.router = AppRouter()
    }

    func start() {
        guard !store.isLoaded else { return }
        store.load()
        reminders.registerCategories()
        foreground()
    }

    func foreground() {
        guard store.isLoaded, prefs.hasOnboarded else { return }
        Task {
            await insights.refreshOnForeground()
            await rescheduleReminders()
        }
    }

    func rescheduleReminders() async {
        let plan = ReminderPlannerFacade.plan(store: store, prefs: prefs)
        await reminders.schedule(plan, calendar: store.calendar)
    }
}
