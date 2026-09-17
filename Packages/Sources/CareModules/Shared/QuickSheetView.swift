import SwiftUI
import CareCore
import CareDesign
import CareData

/// The half sheet that opens from an orb: the Pulse, health chips, one line of what they said, done.
/// Everything is optional, so a person with three modules sees three cards and nothing else.
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

    private var hasSomethingToSave: Bool {
        person.isEnabled(.mood) || health != nil || !symptoms.isEmpty || !mention.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            MeshBackground(aura: person.aura, intensity: 0.95)
            ScrollView {
                VStack(alignment: .leading, spacing: CareLayout.stackGap) {
                    header
                    if person.isEnabled(.mood) { moodCard }
                    if person.isEnabled(.health) { healthCard }
                    if person.isEnabled(.mentions) { mentionCard }
                }
                .careGutter()
                .padding(.top, CareSpace.md)
                .padding(.bottom, CareLayout.actionBottomInset)
            }
            .scrollIndicators(.hidden)

            PillButton("Done", style: .ink) { save() }
                .disabled(!hasSomethingToSave)
                .careGutter()
                .padding(.bottom, CareSpace.sm)
                .background {
                    LinearGradient(colors: [CareColor.background.opacity(0), CareColor.background.opacity(0.94)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }
        }
        .sensoryFeedback(.success, trigger: saved)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CareRadius.hero)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: CareSpace.sm) {
            PersonOrb(person: person, size: .rail)
            VStack(alignment: .leading, spacing: 1) {
                Text("Quick check-in")
                    .careType(.labelEmphasis)
                    .foregroundStyle(CareColor.textSecondary)
                Text(person.relationship == .pet ? "How is \(person.shortName)?" : "How is \(person.shortName) today?")
                    .careType(.sheetTitle)
                    .foregroundStyle(CareColor.textPrimary)
            }
            Spacer(minLength: CareSpace.xs)
            IconButton("xmark", label: "Close") { dismiss() }
        }
    }

    private var moodCard: some View {
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            SectionLabel("Mood")
            PulseControl(value: $mood)
        }
        .careSurface(.card, padding: CareSpace.sm + 2)
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            SectionLabel("Health", trailing: "private to you")
            ChipRow(items: HealthState.allCases, selection: health.map { [$0] } ?? [], label: \.label) { state in
                health = health == state ? nil : state
            }
            ChipRow(items: HealthPayload.symptomChips, selection: symptoms, label: { $0.capitalized }) { symptom in
                if symptoms.contains(symptom) { symptoms.remove(symptom) } else { symptoms.insert(symptom) }
            }
        }
        .careSurface(.card, padding: CareSpace.sm + 2)
    }

    private var mentionCard: some View {
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            SectionLabel("Something they said")
            HStack(alignment: .top, spacing: CareSpace.xs) {
                TextField("Wants to try the pottery class…", text: $mention, axis: .vertical)
                    .careType(.body)
                    .lineLimit(1...4)
                Image(systemName: "microphone.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CareColor.textMuted)
                    .padding(.top, 3)
                    .accessibilityLabel("Use dictation from the keyboard")
            }
            .padding(.horizontal, CareSpace.sm)
            .padding(.vertical, CareSpace.xs + 2)
            .careSurface(.field, padding: 0)
        }
        .careSurface(.card, padding: CareSpace.sm + 2)
    }

    private func save() {
        if person.isEnabled(.mood) {
            store.addEntry(person: person.id, module: .mood, payload: MoodPayload(value: mood))
        }
        if person.isEnabled(.health), health != nil || !symptoms.isEmpty {
            store.addEntry(person: person.id, module: .health,
                           payload: HealthPayload(state: health ?? .neutral, symptoms: Array(symptoms)))
        }
        let text = mention.trimmingCharacters(in: .whitespacesAndNewlines)
        if person.isEnabled(.mentions), !text.isEmpty {
            store.addEntry(person: person.id, module: .mentions, payload: MentionPayload(text: text))
        }
        saved = true
        dismiss()
    }
}
