import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules

/// Under three minutes to a first check-in. One headline, two buttons, then a name, then the people.
struct OnboardingView: View {
    @Environment(CareStore.self) private var store
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step = .welcome
    @State private var name = ""
    @State private var drafts: [Draft] = [Draft(relationship: .partner), Draft(relationship: .parent), Draft(relationship: .pet)]
    @State private var auraIndex = 0

    enum Step: Int { case welcome, name, people }

    struct Draft: Identifiable {
        var id = UUID()
        var name = ""
        var relationship: Relationship
    }

    private let auras: [Aura] = [.coralRose, .skyViolet, .honeyMint, .violetLilac]
    private var aura: Aura { auras[auraIndex % auras.count] }

    var body: some View {
        ZStack {
            MeshBackground(aura: aura, intensity: 1.15)
            Group {
                switch step {
                case .welcome: WelcomeStep(onLocal: { advance(.name) }, onDemo: loadDemo)
                case .name: NameStep(name: $name, onNext: saveName)
                case .people: PeopleStep(drafts: $drafts, onFinish: finish)
                }
            }
            .careDirectionalTransition(.forward, distance: 26)
        }
        .animation(CareMotion.standard(reduced: reduceMotion), value: step)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7))
                withAnimation(.easeInOut(duration: 1.4)) { auraIndex += 1 }
            }
        }
    }

    private func advance(_ next: Step) {
        step = next
    }

    private func loadDemo() {
        store.seedDemo()
        prefs.userName = store.me?.shortName ?? "you"
        prefs.demoMode = true
        prefs.hasOnboarded = true
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        prefs.userName = trimmed
        if store.me == nil {
            store.addPerson(PersonRecord(name: trimmed.isEmpty ? "You" : trimmed, relationship: .me, aura: .ink))
        }
        advance(.people)
    }

    private func finish() {
        for (index, draft) in drafts.enumerated() {
            let trimmed = draft.name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            store.addPerson(PersonRecord(name: trimmed,
                                         relationship: draft.relationship,
                                         aura: Aura.suggested(for: draft.relationship, index: index)))
        }
        prefs.hasOnboarded = true
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    var onLocal: () -> Void
    var onDemo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CareLayout.sectionGap) {
            Spacer(minLength: 0)
            FloatingCards()
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: CareSpace.sm) {
                Text("care")
                    .careType(.meta)
                    .foregroundStyle(CareColor.textSecondary)
                Headline()
                Text("Modules for every person. Insights every morning. Ten seconds a day.")
                    .careType(.callout)
                    .foregroundStyle(CareColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .staggeredEntrance(index: 5)

            VStack(spacing: CareSpace.xs) {
                PillButton("Start on this device", style: .ink, action: onLocal)
                PillButton("Try it with a demo circle", style: .ghost, action: onDemo)
            }
            .staggeredEntrance(index: 6)

            Text("Everything stays on this phone. No account, no cloud. You can bring a model key later.")
                .careType(.meta)
                .foregroundStyle(CareColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .staggeredEntrance(index: 7)
        }
        .careGutter()
        .padding(.bottom, CareSpace.lg)
    }
}

/// The headline sets "finally" in serif italic. Built as one concatenated `Text` so it wraps as a paragraph.
private struct Headline: View {
    @ScaledMetric private var typeScale: CGFloat = 1
    private let size: CGFloat = 38

    var body: some View {
        (
            Text("The people you love, ")
                .font(CareFont.display(size, relativeTo: .largeTitle))
                .tracking(size * -0.035 * typeScale)
            + Text("finally")
                .font(CareFont.serifItalic(size * 1.12, relativeTo: .largeTitle))
            + Text(" in one place.")
                .font(CareFont.display(size, relativeTo: .largeTitle))
                .tracking(size * -0.035 * typeScale)
        )
        .foregroundStyle(CareColor.textPrimary)
        .lineLimit(3)
        .minimumScaleFactor(0.7)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("The people you love, finally in one place.")
    }
}

private struct NameStep: View {
    @Binding var name: String
    var onNext: () -> Void
    @FocusState private var focused: Bool

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: CareLayout.sectionGap) {
            Spacer(minLength: 0)
            ScreenTitle(eyebrow: "First, you", lead: "What should Care", accent: "call you?", role: .sheetTitle)
            CareField("Your name", placeholder: "Surya", text: $name)
                .textContentType(.givenName)
                .focused($focused)
                .onSubmit { if isValid { onNext() } }
            Spacer(minLength: 0)
            PillButton("Next", style: .ink, action: onNext)
                .disabled(!isValid)
        }
        .careGutter()
        .padding(.bottom, CareSpace.lg)
        .task { focused = true }
    }
}

private struct PeopleStep: View {
    @Binding var drafts: [OnboardingView.Draft]
    var onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CareLayout.stackGap) {
            ScreenTitle(eyebrow: "Your circle", lead: "Who do you", accent: "look after?", role: .sheetTitle)
                .padding(.top, CareSpace.xl)

            Text("A first name and who they are is enough. Modules switch on by themselves.")
                .careType(.callout)
                .foregroundStyle(CareColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(spacing: CareSpace.xs) {
                    ForEach($drafts) { $draft in
                        DraftRow(draft: $draft)
                    }
                    Button {
                        withAnimation(CareMotion.standard) {
                            drafts.append(OnboardingView.Draft(relationship: .friend))
                        }
                    } label: {
                        Label("Another person", systemImage: "plus")
                            .careType(.chipLabel)
                            .foregroundStyle(CareColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: CareLayout.touchTarget)
                    }
                    .buttonStyle(.pressable)
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            PillButton("Open Care", style: .ink, action: onFinish)
        }
        .careGutter()
        .padding(.bottom, CareSpace.lg)
    }
}

private struct DraftRow: View {
    @Binding var draft: OnboardingView.Draft

    private var initials: String {
        draft.name.isEmpty ? "?" : PersonRecord(name: draft.name, relationship: draft.relationship, aura: .ink).initials
    }

    var body: some View {
        HStack(spacing: CareSpace.sm) {
            PersonOrb(initials: initials,
                      aura: Aura.suggested(for: draft.relationship),
                      size: .small,
                      symbol: draft.relationship == .pet ? "pawprint.fill" : nil)

            TextField(draft.relationship == .pet ? "Oreo" : draft.relationship.displayName, text: $draft.name)
                .careType(.body)
                .frame(minHeight: CareLayout.touchTarget)

            Menu {
                ForEach(Relationship.allCases.filter { $0 != .me }, id: \.self) { relationship in
                    Button(relationship.displayName) { draft.relationship = relationship }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(draft.relationship.displayName)
                        .careType(.chipLabel)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(CareColor.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(CareColor.chip, in: Capsule())
            }
            .accessibilityLabel("Relationship, \(draft.relationship.displayName)")
        }
        .careSurface(.row, padding: CareSpace.xs + 2)
    }
}

/// Module cards drifting in with the auras of people you will add. Still under Reduce Motion.
struct FloatingCards: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Card: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
        let aura: Aura
        let x: CGFloat
        let y: CGFloat
        let rotation: Double
    }

    private let cards: [Card] = [
        Card(symbol: "face.smiling", title: "Mood", detail: "Good, 7 day trail", aura: .coralRose, x: -72, y: 6, rotation: -7),
        Card(symbol: "pills", title: "Medication", detail: "2 of 2 today", aura: .skyViolet, x: 76, y: 60, rotation: 6),
        Card(symbol: "birthday.cake", title: "Anniversary", detail: "in 12 days", aura: .amberCoral, x: -56, y: 116, rotation: 4),
        Card(symbol: "pawprint", title: "Pet care", detail: "vet in 18 days", aura: .honeyMint, x: 82, y: 170, rotation: -5),
        Card(symbol: "phone.arrow.up.right", title: "Sunday call", detail: "2 talking points", aura: .violetLilac, x: -14, y: 222, rotation: 1),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                row(card)
                    .offset(x: card.x, y: card.y)
                    .rotationEffect(.degrees(card.rotation))
                    .modifier(Drift(seed: Double(index), enabled: !reduceMotion))
                    .staggeredEntrance(index: index)
            }
        }
    }

    private func row(_ card: Card) -> some View {
        HStack(spacing: 10) {
            Image(systemName: card.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(card.aura.gradient, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(card.title)
                    .careType(.labelEmphasis)
                    .foregroundStyle(CareColor.textPrimary)
                Text(card.detail)
                    .careType(.caption)
                    .foregroundStyle(CareColor.textMuted)
            }
            Spacer(minLength: 0)
        }
        .frame(width: 196)
        .careSurface(.row, padding: CareSpace.xs + 2)
    }

    private struct Drift: ViewModifier {
        var seed: Double
        var enabled: Bool

        func body(content: Content) -> some View {
            if enabled {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    content.offset(y: sin(t * 0.7 + seed * 1.7) * 6)
                }
            } else {
                content
            }
        }
    }
}
