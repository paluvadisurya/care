import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules
import CareIntelligence

/// Home. One hero, one rail, a bento of what is due, and the insight, already written when you arrive.
///
/// The screen is a stack of named sections rather than one long body, so each is its own invalidation
/// boundary and each enters on its own beat.
struct TodayView: View {
    @Environment(CareStore.self) private var store
    @Environment(AppPreferences.self) private var prefs
    @Environment(AppRouter.self) private var router
    @Environment(InsightCoordinator.self) private var insights
    @State private var now = Date()

    private var ranked: [Signal] { store.signals(now: now) }
    private var hero: Signal? { HomeRanker.hero(from: ranked) }
    private var heroAura: Aura { hero.flatMap { store.person($0.personID)?.aura } ?? store.me?.aura ?? .violetLilac }
    private var attention: Set<UUID> { HomeRanker.peopleNeedingAttention(ranked) }

    var body: some View {
        ZStack {
            MeshBackground(aura: heroAura)
            ScrollView {
                VStack(alignment: .leading, spacing: CareLayout.sectionGap) {
                    TodayHeader(now: now, name: store.me?.shortName ?? prefs.userName, me: store.me) {
                        if let me = store.me { router.handle(.person(me.id)) }
                    }
                    .careGutter()
                    .staggeredEntrance(index: 0)

                    heroSection
                        .careGutter()
                        .staggeredEntrance(index: 1)

                    OrbRail(people: store.others, attention: attention, showsLabels: true, addLabel: "Add") { id in
                        router.sheet = .quickLog(QuickLogRequest(personID: id))
                    } onLongPress: { id in
                        router.handle(.person(id))
                    } onAdd: {
                        router.sheet = .addPerson
                    }
                    .staggeredEntrance(index: 2)

                    if !bento.isEmpty {
                        bentoSection
                            .careGutter()
                            .staggeredEntrance(index: 3)
                    }

                    insightSection
                        .careGutter()
                        .staggeredEntrance(index: 4)

                    if showsEveningWrap {
                        EveningWrapPrompt { router.sheet = .eveningWrap }
                            .careGutter()
                            .staggeredEntrance(index: 5)
                    }
                }
                .padding(.top, CareSpace.xs)
                .padding(.bottom, CareLayout.scrollBottomInset)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                now = .now
                await insights.refreshHome(force: true)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: store.isLoaded) { now = .now }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    // MARK: Hero

    @ViewBuilder
    private var heroSection: some View {
        if let hero {
            TodayHeroCard(signal: hero, person: store.person(hero.personID), now: now) { action in
                router.perform(action)
            }
            .careScrollTransition()
        } else {
            EmptyState(symbol: "checkmark.seal",
                       title: "Everyone is fine.",
                       message: "Nothing needs you today. That is a good day.",
                       aura: heroAura)
                .careSurface(.hero)
        }
    }

    // MARK: Bento

    /// Up to four person and module pairs from the ranked signals, one entry per pair, hero excluded.
    private var bento: [TodayTile] {
        var out: [TodayTile] = []
        var seen: Set<String> = []
        for signal in ranked where signal.id != hero?.id {
            let key = "\(signal.personID).\(signal.moduleID.rawValue)"
            guard !seen.contains(key), let person = store.person(signal.personID) else { continue }
            seen.insert(key)
            out.append(TodayTile(person: person, module: signal.moduleID,
                                 state: store.todayState(for: person, module: signal.moduleID, now: now)))
            if out.count == 4 { break }
        }
        if out.count < 2, let me = store.me, me.isEnabled(.hydration), !seen.contains("\(me.id).hydration") {
            out.append(TodayTile(person: me, module: .hydration,
                                 state: store.todayState(for: me, module: .hydration, now: now)))
        }
        return out
    }

    private var bentoSection: some View {
        CareSection("Also today") {
            BentoGrid {
                ForEach(bento) { entry in
                    Button {
                        router.open(entry.route)
                    } label: {
                        BentoTile(title: "\(entry.person.shortName) · \(ModuleCatalog.meta(entry.module).name)",
                                  symbol: ModuleCatalog.meta(entry.module).symbol,
                                  state: entry.state,
                                  accent: ModuleAccent.color(for: entry.module),
                                  aura: entry.person.aura)
                    }
                    .buttonStyle(.pressable(scale: 0.97))
                    .careZoomSource(entry.route.id)
                }
            }
        }
        .careScrollTransition()
    }

    // MARK: Insight

    private var insightSection: some View {
        InsightCardView(record: store.insight(scope: .home, scopeID: nil),
                        isGenerating: insights.isGenerating(.home, nil),
                        errorText: insights.lastError[InsightCoordinator.key(.home, nil)],
                        title: "Insight",
                        now: now,
                        onRefresh: { Task { await insights.refreshHome(force: true) } },
                        onAction: { router.handle($0) })
            .careScrollTransition()
    }

    private var showsEveningWrap: Bool {
        prefs.reminders.eveningWrapEnabled
            && Calendar.care.component(.hour, from: now) >= prefs.reminders.eveningWrapHour - 1
    }
}

/// One bento entry on Today: whose it is, which module, and that module's state right now.
private struct TodayTile: Identifiable {
    var person: PersonRecord
    var module: ModuleID
    var state: ModuleTodayState
    var route: ModuleRoute { ModuleRoute(personID: person.id, module: module) }
    var id: String { route.id }
}

// MARK: - Sections

private struct TodayHeader: View {
    var now: Date
    var name: String
    var me: PersonRecord?
    var openProfile: () -> Void

    private var greeting: String {
        switch Calendar.care.component(.hour, from: now) {
        case 5..<12: "Good morning,"
        case 12..<17: "Good afternoon,"
        case 17..<22: "Good evening,"
        default: "Still up,"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: CareSpace.sm) {
            ScreenTitle(eyebrow: now.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                        lead: greeting,
                        accent: name)
            Spacer(minLength: 0)
            if let me {
                Button(action: openProfile) {
                    PersonOrb(person: me, size: .small)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Your profile")
            }
        }
    }
}

private struct TodayHeroCard: View {
    var signal: Signal
    var person: PersonRecord?
    var now: Date
    var perform: (SignalAction) -> Void

    var body: some View {
        HeroCard(label: signal.title,
                 trailing: signal.at.map {
                     CareDates.isSameDay($0, now) ? CareDates.timeLabel($0) : CareDates.relativeDays(from: now, to: $0).capitalized
                 },
                 message: signal.body,
                 tone: signal.tone,
                 aura: person?.aura,
                 actions: signal.actions.prefix(2).map { action in
                     HeroCard.Action(title: action.title, isPrimary: action.isPrimary) { perform(action) }
                 }) {
            presentation
        }
    }

    @ViewBuilder
    private var presentation: some View {
        switch signal.hero {
        case .numeral(let value, let unit):
            BigNumeral(value: value, unit: unit, tone: signal.tone)
        case .countdown(let date):
            Countdown(to: date, now: now)
        case .word(let word):
            BigWord(word, tone: signal.tone)
        case .plain:
            Text(signal.body)
                .careType(.cardTitle)
                .foregroundStyle(CareColor.textPrimary)
        }
    }
}

private struct EveningWrapPrompt: View {
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: CareSpace.sm) {
                Image(systemName: "moon.stars.fill")
                    .careSymbol(.large)
                    .foregroundStyle(CareColor.inkText)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Evening wrap")
                        .careType(.bodyEmphasis)
                        .foregroundStyle(CareColor.inkText)
                    Text("One minute. Three questions about the people you saw.")
                        .careType(.caption)
                        .foregroundStyle(CareColor.inkText.opacity(0.68))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .careSymbol(.small, weight: .bold)
                    .foregroundStyle(CareColor.inkText.opacity(0.6))
            }
            .padding(CareSpace.md)
            .background(CareColor.ink, in: RoundedRectangle(cornerRadius: CareRadius.tile))
            .contentShape(RoundedRectangle(cornerRadius: CareRadius.tile))
        }
        .buttonStyle(.pressable)
    }
}
