import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules

struct RootView: View {
    @Environment(CareStore.self) private var store
    @Environment(AppPreferences.self) private var prefs
    @Environment(AppRouter.self) private var router

    private let tabs = [
        CareTab(id: AppRouter.Tab.today.rawValue, title: "Today", symbol: "sun.max", selectedSymbol: "sun.max.fill"),
        CareTab(id: AppRouter.Tab.people.rawValue, title: "People", symbol: "person.2", selectedSymbol: "person.2.fill"),
        CareTab(id: AppRouter.Tab.timeline.rawValue, title: "Timeline", symbol: "calendar.day.timeline.left", selectedSymbol: "calendar.day.timeline.left"),
        CareTab(id: AppRouter.Tab.you.rawValue, title: "You", symbol: "circle.hexagongrid", selectedSymbol: "circle.hexagongrid.fill"),
    ]

    var body: some View {
        @Bindable var router = router
        Group {
            if !prefs.hasOnboarded {
                OnboardingView()
            } else {
                ZStack(alignment: .bottom) {
                    tabContent
                    GlassTabBar(tabs: tabs, selection: Binding(
                        get: { router.tab.rawValue },
                        set: { router.tab = AppRouter.Tab(rawValue: $0) ?? .today }))
                        .padding(.bottom, CareSpace.xs)
                }
                .sheet(item: $router.sheet) { sheet in
                    switch sheet {
                    case .addPerson: PersonEditorSheet(existing: nil)
                    case .editPerson(let id): PersonEditorSheet(existing: store.person(id))
                    case .store(let id): ModuleStoreView(initialPersonID: id)
                    case .eveningWrap: EveningWrapView()
                    case .quickLog(let request): QuickLogSheet(request: request)
                    }
                }
            }
        }
        .animation(CareMotion.standard, value: prefs.hasOnboarded)
    }

    @ViewBuilder
    private var tabContent: some View {
        @Bindable var router = router
        switch router.tab {
        case .today:
            NavigationStack(path: $router.todayPath) {
                TodayView().navigationDestination(for: ModuleRoute.self) { ModuleDetailView(route: $0) }
            }
            .transition(.opacity)
        case .people:
            NavigationStack(path: $router.peoplePath) {
                PeopleView().navigationDestination(for: ModuleRoute.self) { ModuleDetailView(route: $0) }
            }
            .transition(.opacity)
        case .timeline:
            NavigationStack(path: $router.timelinePath) {
                TimelineView().navigationDestination(for: ModuleRoute.self) { ModuleDetailView(route: $0) }
            }
            .transition(.opacity)
        case .you:
            NavigationStack(path: $router.youPath) {
                YouView().navigationDestination(for: ModuleRoute.self) { ModuleDetailView(route: $0) }
            }
            .transition(.opacity)
        }
    }
}
