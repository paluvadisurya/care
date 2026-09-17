import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules
import CareIntelligence

/// Home. One hero, orbs for quick check-ins, a bento of what is due, and the insight, already rendered.
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
    private var greeting: String {
        let h = Calendar.care.component(.hour, from: now)
        switch h {
        case 5..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<22: return "Good evening,"
        default: return "Still up,"
        }
    }

    /// Up to four (person, module) tiles from the ranked signals, after the hero, one per person.
    private var bento: [(PersonRecord, ModuleID, ModuleTodayState)] {
        var out: [(PersonRecord, ModuleID, ModuleTodayState)] = []
        var seen: Set<String> = []
        for s in ranked where s.id != hero?.id {
            let key = "\(s.personID).\(s.moduleID.rawValue)"
            guard !seen.contains(key), let p = store.person(s.personID) else { continue }
            seen.insert(key)
            out.append((p, s.moduleID, store.todayState(for: p, module: s.moduleID, now: now)))
            if out.count == 4 { break }
        }
        if out.count < 2, let me = store.me, me.isEnabled(.hydration), !seen.contains("\(me.id).hydration") {
            out.append((me, .hydration, store.todayState(for: me, module: .hydration, now: now)))
        }
        return out
    }

    var body: some View {
        ZStack {
            MeshBackground(aura: heroAura)
            ScrollView {
                VStack(alignment: .leading, spacing: CareSpace.md) {
                    header
                    if let hero {
                        heroCard(hero)
                            .careScrollTransition()
                    } else {
                        EmptyState(symbol: "sparkles", title: "Everyone is fine.", message: "Nothing needs you today. That is a good day.")
                            .careCard(radius: CareRadius.hero, strong: true)
                    }
                    orbs
                    if !bento.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: CareSpace.sm), GridItem(.flexible(), spacing: CareSpace.sm)], spacing: CareSpace.sm) {
                            ForEach(Array(bento.enumerated()), id: \.offset) { _, item in
                                Button {
                                    router.open(ModuleRoute(personID: item.0.id, module: item.1))
                                } label: {
                                    BentoTile(title: "\(item.0.shortName) · \(ModuleCatalog.meta(item.1).name)", symbol: ModuleCatalog.meta(item.1).symbol,
                                              state: item.2, accent: ModuleAccent.color(for: item.1))
                                }
                                .buttonStyle(.pressable(scale: 0.97))
                            }
                        }
                        .careScrollTransition()
                    }
                    InsightCardView(record: store.insight(scope: .home, scopeID: nil), isGenerating: insights.isGenerating(.home, nil),
                                    errorText: insights.lastError[InsightCoordinator.key(.home, nil)], title: "Insight", now: now,
                                    onRefresh: { Task { await insights.refreshHome(force: true) } },
                                    onAction: { router.handle($0) })
                        .careScrollTransition()
                    if Calendar.care.component(.hour, from: now) >= prefs.reminders.eveningWrapHour - 1, prefs.reminders.eveningWrapEnabled {
                        Button { router.sheet = .eveningWrap } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Evening wrap").font(CareFont.textSemi(15, relativeTo: .body)).foregroundStyle(CareColor.inkText)
                                    Text("One minute. Three questions about the people you saw.").font(CareFont.caption).foregroundStyle(CareColor.inkText.opacity(0.65))
                                }
                                Spacer()
                                Image(systemName: "moon.stars.fill").foregroundStyle(CareColor.inkText)
                            }
                            .padding(CareSpace.md)
                            .background(CareColor.ink, in: RoundedRectangle(cornerRadius: CareRadius.tile))
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, CareSpace.gutter)
                .padding(.bottom, CareSpace.tabBarClearance)
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

    private var header: some View {
        HStack(alignment: .center) {
            ScreenTitle(eyebrow: now.formatted(.dateTime.weekday(.wide).day().month(.wide)), lead: greeting, accent: store.me?.shortName ?? prefs.userName)
            Spacer()
            if let me = store.me {
                Button { router.tab = .people; router.selectedPersonID = me.id } label: {
                    PersonOrb(initials: me.initials, aura: me.aura, size: 40)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Your profile")
            }
        }
        .padding(.top, CareSpace.xs)
    }

    private func heroCard(_ s: Signal) -> some View {
        let person = store.person(s.personID)
        let phone = person?.settings(PetCareSettings.self, for: .petCare)?.vetPhone
        return HeroCard(label: s.title, trailing: s.at.map { CareDates.isSameDay($0, now) ? CareDates.timeLabel($0) : CareDates.relativeDays(from: now, to: $0).capitalized },
                        body: s.body, tone: s.tone,
                        actions: s.actions.prefix(2).map { a in (a.title, a.isPrimary, { router.perform(a, personPhone: phone) }) }) {
            switch s.hero {
            case .numeral(let value, let unit): BigNumeral(value: value, unit: unit, size: 60)
            case .countdown(let date): Countdown(to: date, now: now, size: 60)
            case .word(let word): Text(word).font(CareFont.display(40)).displayTracking(40).foregroundStyle(s.tone == .attention ? CareColor.attention : CareColor.textPrimary)
            case .plain: Text(s.body).font(CareFont.cardTitle).foregroundStyle(CareColor.textPrimary)
            }
        }
    }

    private var orbs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CareSpace.sm) {
                ForEach(store.others) { p in
                    Button { router.sheet = .quickLog(QuickLogRequest(personID: p.id)) } label: {
                        VStack(spacing: 4) {
                            PersonOrb(initials: p.initials, aura: p.aura, hasAttention: attention.contains(p.id), symbol: p.relationship == .pet ? "pawprint.fill" : nil)
                            Text(p.shortName).font(CareFont.meta).foregroundStyle(CareColor.textSecondary).lineLimit(1)
                        }
                    }
                    .buttonStyle(.pressable)
                    .contextMenu {
                        Button("Open profile", systemImage: "person") { router.handle(.person(p.id)) }
                    }
                }
                Button { router.sheet = .addPerson } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(CareColor.textSecondary)
                            .frame(width: 44, height: 44).background(CareColor.chip, in: Circle()).frame(width: 52, height: 52)
                        Text("Add").font(CareFont.meta).foregroundStyle(CareColor.textSecondary)
                    }
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Add a person")
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }
}
