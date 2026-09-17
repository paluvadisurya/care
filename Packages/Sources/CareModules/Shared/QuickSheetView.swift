import SwiftUI
import CareCore
import CareDesign
import CareData

/// Half sheet from an orb tap: Pulse, health chips, one mention line, Done. Success haptic on done.
public struct QuickSheetView: View {
    @Environment(CareStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    public var person: PersonRecord

    @State private var mood = 4
    @State private var health: HealthState?
    @State private var symptoms: Set<String> = []
    @State private var mention = ""
    @State private var saved = false

    public init(person: PersonRecord) { self.person = person }

    public var body: some View {
        ZStack(alignment: .bottom) {
            MeshBackground(aura: person.aura, intensity: 0.9)
            ScrollView {
                VStack(alignment: .leading, spacing: CareSpace.md) {
                    HStack(spacing: CareSpace.sm) {
                        PersonOrb(initials: person.initials, aura: person.aura, size: 40)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Quick check-in").font(CareFont.labelSemi).foregroundStyle(CareColor.textSecondary)
                            Text(person.relationship == .pet ? "How is \(person.shortName)?" : "How is \(person.shortName) today?")
                                .font(CareFont.display(26)).displayTracking(26).foregroundStyle(CareColor.textPrimary)
                        }
                        Spacer()
                        IconButton("xmark", label: "Close") { dismiss() }
                    }
                    if person.isEnabled(.mood) {
                        VStack(alignment: .leading, spacing: CareSpace.xs) {
                            SectionLabel("Mood")
                            PulseControl(value: $mood)
                        }
                        .careCard(padding: CareSpace.sm + 2)
                    }
                    if person.isEnabled(.health) {
                        VStack(alignment: .leading, spacing: CareSpace.xs) {
                            SectionLabel("Health")
                            ChipRow(items: HealthState.allCases, selection: health.map { [$0] } ?? [], label: { $0.label }) { health = health == $0 ? nil : $0 }
                            ChipRow(items: HealthPayload.symptomChips, selection: symptoms, label: { $0 }) { s in
                                if symptoms.contains(s) { symptoms.remove(s) } else { symptoms.insert(s) }
                            }
                        }
                        .careCard(padding: CareSpace.sm + 2)
                    }
                    if person.isEnabled(.mentions) {
                        VStack(alignment: .leading, spacing: CareSpace.xs) {
                            SectionLabel("Something they said")
                            HStack {
                                TextField("Wants to try the pottery class…", text: $mention, axis: .vertical)
                                    .font(CareFont.body)
                                Image(systemName: "mic.fill").foregroundStyle(CareColor.textMuted)
                                    .accessibilityLabel("Use dictation from the keyboard")
                            }
                            .padding(.horizontal, CareSpace.sm).frame(minHeight: 46)
                            .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.inner))
                        }
                        .careCard(padding: CareSpace.sm + 2)
                    }
                }
                .padding(CareSpace.gutter)
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)
            PillButton("Done", style: .ink) { save() }
                .padding(.horizontal, CareSpace.gutter)
                .padding(.bottom, CareSpace.sm)
        }
        .sensoryFeedback(.success, trigger: saved)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CareRadius.hero)
    }

    private func save() {
        if person.isEnabled(.mood) {
            store.addEntry(person: person.id, module: .mood, payload: MoodPayload(value: mood))
        }
        if person.isEnabled(.health), health != nil || !symptoms.isEmpty {
            store.addEntry(person: person.id, module: .health, payload: HealthPayload(state: health ?? .neutral, symptoms: Array(symptoms)))
        }
        let text = mention.trimmingCharacters(in: .whitespacesAndNewlines)
        if person.isEnabled(.mentions), !text.isEmpty {
            store.addEntry(person: person.id, module: .mentions, payload: MentionPayload(text: text))
        }
        saved = true
        dismiss()
    }
}
