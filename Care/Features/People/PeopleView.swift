import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules
import CareIntelligence

/// One person at a time. A rail to move between them, a header washed in their aura, the Pulse, their
/// modules as a bento, and the insight written about the last thirty days.
///
/// Swiping left or right moves to the next person and the content enters from the side it came from, so the
/// rail and the body always agree about which direction you are travelling.
struct PeopleView: View {
    @Environment(CareStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(InsightCoordinator.self) private var insights
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var collapse: Double = 0
    @State private var direction: CareDirection = .none
    @State private var now = Date()

    private var people: [PersonRecord] { store.people }

    private var selected: PersonRecord? {
        if let id = router.selectedPersonID, let person = store.person(id) { return person }
        return store.others.first ?? store.me
    }

    private var attention: Set<UUID> { HomeRanker.peopleNeedingAttention(store.signals(now: now)) }

    var body: some View {
        ZStack {
            MeshBackground(aura: selected?.aura ?? .violetLilac)
            // The wash is a screen layer, not a header background, so the person's colour reaches the
            // status bar and runs behind the rail without a visible seam where the header begins.
            if let person = selected {
                AuraWash(aura: person.aura, collapse: collapse)
                    .transition(.opacity)
                    .id(person.id)
            }
            if let person = selected {
                VStack(spacing: 0) {
                    OrbRail(people: people, attention: attention, selection: person.id) { id in
                        move(to: id)
                    } onLongPress: { id in
                        router.sheet = .quickLog(QuickLogRequest(personID: id))
                    } onAdd: {
                        router.sheet = .addPerson
                    }
                    .padding(.top, CareSpace.xxs)

                    profile(person)
                }
            } else {
                EmptyState(symbol: "person.2",
                           title: "Nobody here yet",
                           message: "Add the people you look after and Care starts keeping track.",
                           buttonTitle: "Add a person") { router.sheet = .addPerson }
                    .careGutter()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: selected?.id) {
            now = .now
            if let person = selected { await insights.refresh(person: person, force: false) }
        }
    }

    private func profile(_ person: PersonRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CareLayout.sectionGap) {
                AuraHeader(name: person.name,
                           role: roleLine(person),
                           status: store.statusLine(for: person, now: now),
                           aura: person.aura,
                           initials: person.initials,
                           symbol: person.relationship == .pet ? "pawprint.fill" : nil,
                           collapse: collapse)
                    .padding(.horizontal, -CareSpace.gutter)

                if person.isEnabled(.mood), person.relationship != .pet {
                    PulseCard(person: person)
                }

                bento(person)

                InsightCardView(record: store.insight(scope: .person, scopeID: person.id),
                                isGenerating: insights.isGenerating(.person, person.id),
                                errorText: insights.lastError[InsightCoordinator.key(.person, person.id)],
                                title: "Insight · 30 days",
                                now: now,
                                onRefresh: { Task { await insights.refresh(person: person, force: true) } },
                                onAction: { router.handle($0) })
                    .careScrollTransition()

                HStack(spacing: CareSpace.xs) {
                    PillButton("Modules", symbol: "square.grid.2x2", style: .ghost, compact: true) {
                        router.sheet = .store(person.id)
                    }
                    PillButton("Edit", symbol: "pencil", style: .ghost, compact: true) {
                        router.sheet = .editPerson(person.id)
                    }
                    Spacer(minLength: 0)
                }
            }
            .careGutter()
            .padding(.bottom, CareLayout.scrollBottomInset)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Double.self) { geometry in
            min(1, max(0, geometry.contentOffset.y / 110))
        } action: { _, value in
            collapse = value
        }
        .id(person.id)
        .careDirectionalTransition(direction)
        .animation(CareMotion.standard(reduced: reduceMotion), value: person.id)
        .gesture(
            DragGesture(minimumDistance: 44)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                    step(value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private func roleLine(_ person: PersonRecord) -> String {
        guard let note = person.note, !note.isEmpty else { return person.relationship.roleLine }
        return "\(person.relationship.roleLine) · \(note)"
    }

    private func bento(_ person: PersonRecord) -> some View {
        let modules = person.enabledModules.filter { store.registry.isImplemented($0) }
        return CareSection("Modules", trailing: "\(modules.count) on") {
            BentoGrid {
                ForEach(modules, id: \.self) { module in
                    let route = ModuleRoute(personID: person.id, module: module)
                    NavigationLink(value: route) {
                        if let ui = ModuleUIRegistry.ui(for: module) {
                            ui.tile(person: person, state: store.todayState(for: person, module: module, now: now))
                        }
                    }
                    .buttonStyle(.pressable(scale: 0.97))
                    .careZoomSource(route.id)
                    .contextMenu {
                        if let ui = ModuleUIRegistry.ui(for: module), ui.quickLog(person: person, prefill: nil) != nil {
                            Button("Quick log", systemImage: "plus") {
                                router.sheet = .quickLog(QuickLogRequest(personID: person.id, module: module))
                            }
                        }
                        Button("Switch off", systemImage: "minus.circle") {
                            store.setModule(module, enabled: false, for: person.id)
                        }
                    }
                }
                AddTile(title: "Add a module") { router.sheet = .store(person.id) }
            }
        }
    }

    // MARK: Navigation between people

    private func move(to id: UUID) {
        guard let current = router.selectedPersonID ?? selected?.id,
              let from = people.firstIndex(where: { $0.id == current }),
              let to = people.firstIndex(where: { $0.id == id }) else {
            router.selectedPersonID = id
            return
        }
        direction = to > from ? .forward : .backward
        router.selectedPersonID = id
    }

    private func step(_ delta: Int) {
        guard let current = selected, let index = people.firstIndex(where: { $0.id == current.id }) else { return }
        let next = index + delta
        guard people.indices.contains(next) else { return }
        direction = delta > 0 ? .forward : .backward
        router.selectedPersonID = people[next].id
    }
}

/// The Pulse, with the last check-in beside it so a drag has context.
private struct PulseCard: View {
    @Environment(CareStore.self) private var store
    var person: PersonRecord
    @State private var value = 4
    @State private var saved = false

    private var lastEntry: EntryRecord? { store.entries(for: person.id, module: .mood).first }

    var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(person.relationship == .me ? "How is it going?" : "How is \(person.shortName) today?")
                    .careType(.labelEmphasis)
                    .foregroundStyle(CareColor.textSecondary)
                Spacer(minLength: CareSpace.xs)
                if let lastEntry {
                    Text("last \(CareDates.relativeShort(from: .now, to: lastEntry.occurredAt))")
                        .careType(.meta)
                        .foregroundStyle(CareColor.textMuted)
                }
            }
            PulseControl(value: $value)
            PillButton("Save \(PulseControl.words[max(0, min(4, value - 1))].lowercased())", style: .ghost, compact: true) {
                store.addEntry(person: person.id, module: .mood, payload: MoodPayload(value: value))
                saved.toggle()
            }
        }
        .careSurface(.card)
        .sensoryFeedback(.success, trigger: saved)
        .task(id: person.id) {
            if let payload = lastEntry?.decode(MoodPayload.self) { value = payload.value }
        }
    }
}
