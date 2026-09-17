import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules

/// Three questions about the people you saw today. Each answer is one tap, skipping is one tap, and the
/// queue is fixed when the sheet opens so answering never reshuffles what is left.
struct EveningWrapView: View {
    @Environment(CareStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var queue: [PersonRecord] = []
    @State private var index = 0
    @State private var value = 4
    @State private var answered = 0
    @State private var finished = false

    private var current: PersonRecord? {
        queue.indices.contains(index) ? queue[index] : nil
    }

    private var aura: Aura { current?.aura ?? store.me?.aura ?? .violetLilac }

    var body: some View {
        ZStack {
            MeshBackground(aura: aura, intensity: 1.05)
            VStack(alignment: .leading, spacing: CareLayout.sectionGap) {
                header
                content
                Spacer(minLength: 0)
                if !finished, !queue.isEmpty {
                    progress
                }
            }
            .careGutter()
            .padding(.top, CareSpace.md)
            .padding(.bottom, CareSpace.lg)
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CareRadius.hero)
        .task { buildQueue() }
        .animation(CareMotion.standard(reduced: reduceMotion), value: index)
        .animation(CareMotion.standard(reduced: reduceMotion), value: finished)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: CareSpace.sm) {
            ScreenTitle(eyebrow: "Evening wrap",
                        lead: finished ? "Thank you." : "One minute,",
                        accent: finished ? nil : "three questions",
                        role: .sheetTitle)
            Spacer(minLength: 0)
            IconButton("xmark", label: "Close") { dismiss() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if finished || queue.isEmpty {
            summary
        } else if let person = current {
            question(person)
                .id(person.id)
                .transition(.asymmetric(
                    insertion: .offset(x: 24).combined(with: .opacity),
                    removal: .offset(x: -24).combined(with: .opacity)
                ))
        }
    }

    private func question(_ person: PersonRecord) -> some View {
        VStack(alignment: .leading, spacing: CareSpace.sm) {
            HStack(spacing: CareSpace.sm) {
                PersonOrb(person: person, size: .rail)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(index + 1) of \(queue.count)")
                        .careType(.meta)
                        .foregroundStyle(CareColor.textMuted)
                    Text("How was \(person.shortName) today?")
                        .careType(.cardTitle)
                        .foregroundStyle(CareColor.textPrimary)
                }
                Spacer(minLength: 0)
            }
            PulseControl(value: $value)
            HStack(spacing: CareSpace.xs) {
                PillButton("Save", style: .ink) { answer(person) }
                PillButton("Skip", style: .ghost) { advance() }
            }
        }
        .careSurface(.hero)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: CareSpace.sm) {
            Text(queue.isEmpty ? "Nobody to ask about tonight." : "You checked in on \(ModuleHelpers.plural(answered, "person", "people")).")
                .careType(.cardTitle)
                .foregroundStyle(CareColor.textPrimary)
            Text(tomorrow)
                .careType(.callout)
                .foregroundStyle(CareColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            PillButton("Good night", style: .ink) { dismiss() }
                .padding(.top, CareSpace.xxs)
        }
        .careSurface(.hero)
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }

    private var progress: some View {
        HStack(spacing: 4) {
            ForEach(0..<queue.count, id: \.self) { step in
                Capsule()
                    .fill(step <= index ? CareColor.ink : CareColor.chip)
                    .frame(height: 3)
            }
        }
        .accessibilityLabel("Question \(index + 1) of \(queue.count)")
    }

    private var tomorrow: String {
        let items = store.timelineItems(day: CareDates.adding(days: 1, to: .now)).filter { !$0.isDone }
        guard let first = items.first else { return "Tomorrow looks clear." }
        return items.count == 1 ? "Tomorrow: \(first.title)." : "Tomorrow: \(first.title), and \(items.count - 1) more."
    }

    /// Built once so answering never reshuffles the remaining questions underneath you.
    private func buildQueue() {
        guard queue.isEmpty else { return }
        var ordered: [UUID] = []
        for signal in store.signals() where !ordered.contains(signal.personID) {
            ordered.append(signal.personID)
        }
        let ranked = ordered.compactMap { store.person($0) }
        let rest = store.others.filter { person in !ordered.contains(person.id) }
        queue = Array((ranked + rest).filter { $0.isEnabled(.mood) && $0.relationship != .pet }.prefix(3))
        loadValue()
    }

    private func loadValue() {
        guard let person = current,
              let payload = store.entries(for: person.id, module: .mood).first?.decode(MoodPayload.self) else {
            value = 4
            return
        }
        value = payload.value
    }

    private func answer(_ person: PersonRecord) {
        store.addEntry(person: person.id, module: .mood, source: .manual, payload: MoodPayload(value: value))
        answered += 1
        advance()
    }

    private func advance() {
        if index + 1 < queue.count {
            index += 1
            loadValue()
        } else {
            finished = true
        }
    }
}
