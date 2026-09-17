import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules
import CareIntelligence

/// Orbs at the top, an aura header that fades into content, the Pulse, then the person's module bento.
struct PeopleView: View {
    @Environment(CareStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(InsightCoordinator.self) private var insights
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var orbSpace
    @State private var collapse: Double = 0
    @State private var pulse = 4
    @State private var pulseSaved = false
    @State private var slide: CGFloat = 0
    @State private var now = Date()

    private var people: [PersonRecord] { store.people }
    private var selected: PersonRecord? {
        if let id = router.selectedPersonID, let p = store.person(id) { return p }
        return store.others.first ?? store.me
    }

    var body: some View {
        ZStack {
            MeshBackground(aura: selected?.aura ?? .violetLilac)
            if let person = selected {
                content(person)
                    .id(person.id)
                    .transition(.asymmetric(insertion: .offset(x: slide).combined(with: .opacity), removal: .opacity))
            } else {
                EmptyState(symbol: "person.2", title: "Nobody here yet", message: "Add the people you look after.", buttonTitle: "Add a person") { router.sheet = .addPerson }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(CareMotion.standard(reduced: reduceMotion), value: selected?.id)
        .task(id: selected?.id) {
            now = .now
            if let p = selected { await insights.refresh(person: p, force: false) }
        }
    }

    private func content(_ person: PersonRecord) -> some View {
        VStack(spacing: 0) {
            orbStrip(person)
            ScrollView {
                VStack(alignment: .leading, spacing: CareSpace.md) {
                    AuraHeader(name: person.name, role: person.relationship.roleLine + (person.note.map { " · \($0)" } ?? ""),
                               status: store.statusLine(for: person, now: now), aura: person.aura, initials: person.initials, collapse: collapse)
                        .padding(.horizontal, -CareSpace.gutter)
                    if person.isEnabled(.mood), person.relationship != .pet {
                        pulseCard(person)
                    }
                    bento(person)
                    InsightCardView(record: store.insight(scope: .person, scopeID: person.id), isGenerating: insights.isGenerating(.person, person.id),
                                    errorText: insights.lastError[InsightCoordinator.key(.person, person.id)], title: "Insight · 30 days", now: now,
                                    onRefresh: { Task { await insights.refresh(person: person, force: true) } },
                                    onAction: { router.handle($0) })
                    HStack(spacing: CareSpace.xs) {
                        PillButton("Modules", symbol: "square.grid.2x2", style: .ghost, compact: true) { router.sheet = .store(person.id) }
                        PillButton("Edit", symbol: "pencil", style: .ghost, compact: true) { router.sheet = .editPerson(person.id) }
                        Spacer()
                    }
                }
                .padding(.horizontal, CareSpace.gutter)
                .padding(.bottom, CareSpace.tabBarClearance)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: Double.self) { geo in
                min(1, max(0, geo.contentOffset.y / 120))
            } action: { _, new in
                collapse = new
            }
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { g in
                        guard abs(g.translation.width) > abs(g.translation.height) else { return }
                        step(g.translation.width < 0 ? 1 : -1)
                    }
            )
        }
    }

    private func step(_ delta: Int) {
        guard let current = selected, let idx = people.firstIndex(where: { $0.id == current.id }) else { return }
        let next = idx + delta
        guard people.indices.contains(next) else { return }
        slide = delta > 0 ? 16 : -16
        router.selectedPersonID = people[next].id
    }

    private func orbStrip(_ person: PersonRecord) -> some View {
        let attention = HomeRanker.peopleNeedingAttention(store.signals(now: now))
        return ScrollView(.horizontal) {
            HStack(spacing: CareSpace.xs) {
                ForEach(people) { p in
                    Button {
                        slide = 0
                        router.selectedPersonID = p.id
                    } label: {
                        PersonOrb(initials: p.initials, aura: p.aura, isSelected: p.id == person.id, hasAttention: attention.contains(p.id), symbol: p.relationship == .pet ? "pawprint.fill" : nil)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(p.name)
                    .simultaneousGesture(LongPressGesture().onEnded { _ in router.sheet = .quickLog(QuickLogRequest(personID: p.id)) })
                }
                Button { router.sheet = .addPerson } label: {
                    Image(systemName: "plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(CareColor.textSecondary)
                        .frame(width: 44, height: 44).background(CareColor.chip, in: Circle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Add a person")
            }
            .padding(.horizontal, CareSpace.gutter)
            .padding(.vertical, CareSpace.xs)
        }
        .scrollIndicators(.hidden)
    }

    private func pulseCard(_ person: PersonRecord) -> some View {
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            HStack {
                Text("How is \(person.relationship == .me ? "it going" : person.shortName) today?").font(CareFont.labelSemi).foregroundStyle(CareColor.textSecondary)
                Spacer()
                if let last = store.entries(for: person.id, module: .mood).first {
                    Text("last \(CareDates.relativeShort(from: now, to: last.occurredAt))").font(CareFont.meta).foregroundStyle(CareColor.textMuted)
                }
            }
            PulseControl(value: $pulse)
            PillButton("Save \(PulseControl.words[max(0, min(4, pulse - 1))].lowercased())", style: .ghost, compact: true) {
                store.addEntry(person: person.id, module: .mood, payload: MoodPayload(value: pulse))
                pulseSaved.toggle()
            }
        }
        .careCard(padding: CareSpace.sm + 2)
        .sensoryFeedback(.success, trigger: pulseSaved)
    }

    private func bento(_ person: PersonRecord) -> some View {
        let modules = person.enabledModules.filter { store.registry.isImplemented($0) }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: CareSpace.sm), GridItem(.flexible(), spacing: CareSpace.sm)], spacing: CareSpace.sm) {
            ForEach(modules, id: \.self) { m in
                NavigationLink(value: ModuleRoute(personID: person.id, module: m)) {
                    if let ui = ModuleUIRegistry.ui(for: m) {
                        ui.tile(person: person, state: store.todayState(for: person, module: m, now: now))
                    }
                }
                .buttonStyle(.pressable(scale: 0.97))
                .contextMenu {
                    if let ui = ModuleUIRegistry.ui(for: m), ui.quickLog(person: person, prefill: nil) != nil {
                        Button("Quick log", systemImage: "plus") { router.sheet = .quickLog(QuickLogRequest(personID: person.id, module: m)) }
                    }
                    Button("Switch off", systemImage: "minus.circle") { store.setModule(m, enabled: false, for: person.id) }
                }
            }
            Button { router.sheet = .store(person.id) } label: {
                VStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
                    Text("Add a module").font(CareFont.label)
                }
                .foregroundStyle(CareColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 108)
                .background { RoundedRectangle(cornerRadius: CareRadius.tile).strokeBorder(CareColor.separator, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])) }
            }
            .buttonStyle(.pressable(scale: 0.97))
        }
    }
}
