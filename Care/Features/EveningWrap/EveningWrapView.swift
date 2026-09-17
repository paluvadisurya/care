import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules

/// Full sheet. One card per person seen today, three at most. Each answer is one tap; skip is one tap.
struct EveningWrapView: View {
    @Environment(CareStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var values: [UUID: Int] = [:]
    @State private var done = false

    private var people: [PersonRecord] {
        let ranked = store.signals()
        var ids: [UUID] = []
        for s in ranked where !ids.contains(s.personID) { ids.append(s.personID) }
        let ordered = ids.compactMap { store.person($0) } + store.others.filter { !ids.contains($0.id) }
        return Array(ordered.filter { $0.isEnabled(.mood) && $0.relationship != .pet }.prefix(3))
    }

    var body: some View {
        let aura = people.indices.contains(index) ? people[index].aura : (store.me?.aura ?? .violetLilac)
        ZStack {
            MeshBackground(aura: aura)
            VStack(alignment: .leading, spacing: CareSpace.lg) {
                HStack {
                    ScreenTitle(eyebrow: "Evening wrap", lead: done ? "Thank you." : "One minute,", accent: done ? nil : "three questions", size: 30)
                    Spacer()
                    IconButton("xmark", label: "Close") { dismiss() }
                }
                if done || !people.indices.contains(index) {
                    VStack(alignment: .leading, spacing: CareSpace.sm) {
                        Text(people.isEmpty ? "Nobody to ask about tonight." : "You checked in on \(ModuleHelpers.plural(values.count, "person", "people")).")
                            .font(CareFont.cardTitle).foregroundStyle(CareColor.textPrimary)
                        Text(tomorrow).font(CareFont.callout).foregroundStyle(CareColor.textSecondary)
                        PillButton("Good night", style: .ink) { dismiss() }
                    }
                    .careCard(radius: CareRadius.hero, strong: true)
                } else {
                    let p = people[index]
                    VStack(alignment: .leading, spacing: CareSpace.sm) {
                        HStack(spacing: CareSpace.sm) {
                            PersonOrb(initials: p.initials, aura: p.aura, size: 44)
                            VStack(alignment: .leading) {
                                Text("\(index + 1) of \(people.count)").font(CareFont.meta).foregroundStyle(CareColor.textMuted)
                                Text("How was \(p.shortName) today?").font(CareFont.cardTitle).foregroundStyle(CareColor.textPrimary)
                            }
                        }
                        PulseControl(value: Binding(get: { values[p.id] ?? 4 }, set: { values[p.id] = $0 }))
                        HStack(spacing: CareSpace.xs) {
                            PillButton("Save", style: .ink) { answer(p) }
                            PillButton("Skip", style: .ghost) { advance() }
                        }
                    }
                    .careCard(radius: CareRadius.hero, padding: CareSpace.md + 2, strong: true)
                    .id(p.id)
                    .transition(.asymmetric(insertion: .offset(x: 16).combined(with: .opacity), removal: .opacity))
                }
                Spacer()
            }
            .padding(CareSpace.gutter)
            .animation(CareMotion.standard, value: index)
            .animation(CareMotion.standard, value: done)
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CareRadius.hero)
    }

    private var tomorrow: String {
        let items = store.timelineItems(day: CareDates.adding(days: 1, to: .now)).filter { !$0.isDone }
        guard let first = items.first else { return "Tomorrow looks clear." }
        return items.count == 1 ? "Tomorrow: \(first.title)." : "Tomorrow: \(first.title) and \(items.count - 1) more."
    }

    private func answer(_ p: PersonRecord) {
        let v = values[p.id] ?? 4
        values[p.id] = v
        store.addEntry(person: p.id, module: .mood, source: .manual, payload: MoodPayload(value: v))
        advance()
    }

    private func advance() {
        if index + 1 < people.count { index += 1 } else { done = true }
    }
}
