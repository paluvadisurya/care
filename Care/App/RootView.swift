import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules

/// The four tabs, the floating glass bar, and every sheet the app can present.
///
/// One namespace for zoom transitions lives here and is published into the environment, so any card on any
/// screen can grow into its detail view without threading a `Namespace.ID` through initialisers.
struct RootView: View {
    @Environment(CareStore.self) private var store
    @Environment(AppPreferences.self) private var prefs
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var zoomSpace
    @State private var previousTabIndex = 0

    private let tabs = [
        CareTab(id: AppRouter.Tab.today.rawValue, title: "Today", symbol: "sun.max", selectedSymbol: "sun.max.fill"),
        CareTab(id: AppRouter.Tab.people.rawValue, title: "People", symbol: "person.2", selectedSymbol: "person.2.fill"),
        CareTab(id: AppRouter.Tab.timeline.rawValue, title: "Timeline", symbol: "calendar.day.timeline.left", selectedSymbol: "calendar.day.timeline.left"),
        CareTab(id: AppRouter.Tab.you.rawValue, title: "You", symbol: "circle.hexagongrid", selectedSymbol: "circle.hexagongrid.fill"),
    ]

    private var tabIndex: Int { tabs.firstIndex { $0.id == router.tab.rawValue } ?? 0 }

    private var direction: CareDirection {
        if tabIndex == previousTabIndex { return .none }
        return tabIndex > previousTabIndex ? .forward : .backward
    }

    /// People carries a dot when somebody needs attention and you are not already looking at them.
    private var badgedTabs: Set<String> {
        HomeRanker.peopleNeedingAttention(store.signals()).isEmpty ? [] : [AppRouter.Tab.people.rawValue]
    }

    var body: some View {
        @Bindable var router = router
        Group {
            if !prefs.hasOnboarded {
                OnboardingView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                ZStack(alignment: .bottom) {
                    tabContent
                    GlassTabBar(tabs: tabs,
                                selection: Binding(
                                    get: { router.tab.rawValue },
                                    set: { router.tab = AppRouter.Tab(rawValue: $0) ?? .today }),
                                badged: badgedTabs)
                        .padding(.bottom, CareLayout.tabBarBottomInset)
                }
                .sheet(item: $router.sheet) { sheet in
                    sheetContent(sheet)
                }
            }
        }
        .environment(\.careZoomNamespace, zoomSpace)
        .animation(CareMotion.standard(reduced: reduceMotion), value: prefs.hasOnboarded)
        .onChange(of: tabIndex) { old, _ in previousTabIndex = old }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: AppRouter.Sheet) -> some View {
        switch sheet {
        case .addPerson: PersonEditorSheet(existing: nil)
        case .editPerson(let id): PersonEditorSheet(existing: store.person(id))
        case .store(let id): ModuleStoreView(initialPersonID: id)
        case .eveningWrap: EveningWrapView()
        case .quickLog(let request): QuickLogSheet(request: request)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        @Bindable var router = router
        switch router.tab {
        case .today:
            stack(path: $router.todayPath) { TodayView() }
        case .people:
            stack(path: $router.peoplePath) { PeopleView() }
        case .timeline:
            stack(path: $router.timelinePath) { TimelineScreen() }
        case .you:
            stack(path: $router.youPath) { YouView() }
        }
    }

    private func stack<Root: View>(path: Binding<[ModuleRoute]>, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: path) {
            root()
                .navigationDestination(for: ModuleRoute.self) { route in
                    ModuleDetailView(route: route)
                        .careZoomDestination(route.id)
                }
        }
        .careDirectionalTransition(direction, distance: 22)
    }
}
