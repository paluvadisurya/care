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

    enum Step { case welcome, name, people }

    struct Draft: Identifiable {
        var id = UUID()
        var name = ""
        var relationship: Relationship
    }

    private let auras: [Aura] = [.coralRose, .skyViolet, .honeyMint, .violetLilac]

    var body: some View {
        ZStack {
            MeshBackground(aura: auras[auraIndex % auras.count], intensity: 1.2)
            switch step {
            case .welcome: welcome.transition(.opacity)
            case .name: nameStep.transition(.asymmetric(insertion: .offset(x: 24).combined(with: .opacity), removal: .opacity))
            case .people: peopleStep.transition(.asymmetric(insertion: .offset(x: 24).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(CareMotion.standard(reduced: reduceMotion), value: step)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                withAnimation(.easeInOut(duration: 1.2)) { auraIndex += 1 }
            }
        }
    }

    // MARK: Welcome

    private var welcome: some View {
        VStack(alignment: .leading, spacing: CareSpace.lg) {
            Spacer()
            FloatingCards()
                .frame(height: 260)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CareSpace.sm) {
                Text("care").font(CareFont.mono(13)).foregroundStyle(CareColor.textSecondary)
                VStack(alignment: .leading, spacing: 0) {
                    Text("The people you love,").font(CareFont.display(40)).displayTracking(40)
                    HStack(spacing: 0) {
                        Text("finally ").font(CareFont.serifItalic(44))
                        Text("in one place.").font(CareFont.display(40)).displayTracking(40)
                    }
                }
                .foregroundStyle(CareColor.textPrimary)
                .lineLimit(2).minimumScaleFactor(0.7)
                Text("Modules for every person. Insights every morning. Ten seconds a day.")
                    .font(CareFont.callout).foregroundStyle(CareColor.textSecondary)
            }
            VStack(spacing: CareSpace.xs) {
                PillButton("Start on this device", style: .ink) { step = .name }
                PillButton("Try it with a demo circle", style: .ghost) {
                    store.seedDemo()
                    prefs.userName = "Surya"
                    prefs.demoMode = true
                    prefs.hasOnboarded = true
                }
            }
            Text("Everything stays on this phone. No account, no cloud. You can bring a model key later.")
                .font(CareFont.meta).foregroundStyle(CareColor.textMuted)
        }
        .padding(CareSpace.gutter)
        .padding(.bottom, CareSpace.md)
    }

    // MARK: Name

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: CareSpace.lg) {
            Spacer()
            ScreenTitle(eyebrow: "First, you", lead: "What should Care", accent: "call you?", size: 32)
            CareField("Your name", placeholder: "Surya", text: $name)
                .textContentType(.givenName)
            Spacer()
            PillButton("Next", style: .ink) {
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                prefs.userName = trimmed
                if store.me == nil {
                    store.addPerson(PersonRecord(name: trimmed.isEmpty ? "You" : trimmed, relationship: .me, aura: .ink))
                }
                step = .people
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(CareSpace.gutter)
        .padding(.bottom, CareSpace.md)
    }

    // MARK: People

    private var peopleStep: some View {
        VStack(alignment: .leading, spacing: CareSpace.md) {
            ScreenTitle(eyebrow: "Your circle", lead: "Who do you", accent: "look after?", size: 32).padding(.top, CareSpace.xl)
            Text("A first name and who they are is enough. Modules switch on by themselves. Contacts import comes with Phase 1.")
                .font(CareFont.callout).foregroundStyle(CareColor.textSecondary)
            ScrollView {
                VStack(spacing: CareSpace.xs) {
                    ForEach($drafts) { $draft in
                        HStack(spacing: CareSpace.xs) {
                            PersonOrb(initials: draft.name.isEmpty ? "?" : PersonRecord(name: draft.name, relationship: draft.relationship, aura: .ink).initials,
                                      aura: Aura.suggested(for: draft.relationship), size: 36, symbol: draft.relationship == .pet ? "pawprint.fill" : nil)
                            TextField(draft.relationship == .pet ? "Oreo" : draft.relationship.displayName, text: $draft.name)
                                .font(CareFont.body).frame(minHeight: 40)
                            Menu {
                                ForEach(Relationship.allCases.filter { $0 != .me }, id: \.self) { r in
                                    Button(r.displayName) { draft.relationship = r }
                                }
                            } label: {
                                Text(draft.relationship.displayName).font(CareFont.chip).foregroundStyle(CareColor.textPrimary)
                                    .padding(.horizontal, 12).frame(height: 32).background(CareColor.chip, in: Capsule())
                            }
                        }
                        .careCard(radius: CareRadius.tile, padding: CareSpace.xs + 2)
                    }
                    Button { drafts.append(Draft(relationship: .friend)) } label: {
                        Label("Another person", systemImage: "plus").font(CareFont.chip).foregroundStyle(CareColor.textSecondary).frame(maxWidth: .infinity).frame(height: 44)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .scrollIndicators(.hidden)
            PillButton("Open Care", style: .ink) {
                for (i, d) in drafts.enumerated() where !d.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    store.addPerson(PersonRecord(name: d.name.trimmingCharacters(in: .whitespaces), relationship: d.relationship, aura: Aura.suggested(for: d.relationship, index: i)))
                }
                prefs.hasOnboarded = true
            }
        }
        .padding(CareSpace.gutter)
        .padding(.bottom, CareSpace.md)
    }
}

/// Module cards drifting in with the auras of people you will add. Still under Reduce Motion.
struct FloatingCards: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cards: [(String, String, String, Aura, CGFloat, CGFloat, Double)] = [
        ("face.smiling", "Mood", "Good, 7 day trail", .coralRose, -110, -30, -8),
        ("pills", "Medication", "2 of 2 today", .skyViolet, 100, -70, 6),
        ("birthday.cake", "Anniversary", "in 12 days", .amberCoral, -60, 70, 4),
        ("pawprint", "Pet care", "vet in 18 days", .honeyMint, 120, 60, -5),
        ("phone.arrow.up.right", "Sunday call", "2 talking points", .violetLilac, 10, 0, 0),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.offset) { i, c in
                HStack(spacing: 10) {
                    Image(systemName: c.0).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(c.3.gradient, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(c.1).font(CareFont.textSemi(13, relativeTo: .subheadline)).foregroundStyle(CareColor.textPrimary)
                        Text(c.2).font(CareFont.caption).foregroundStyle(CareColor.textMuted)
                    }
                }
                .careCard(radius: CareRadius.tile, padding: CareSpace.sm, strong: true)
                .rotationEffect(.degrees(c.6))
                .offset(x: c.4, y: c.5)
                .modifier(Float(seed: Double(i), enabled: !reduceMotion))
                .staggeredEntrance(index: i)
            }
        }
    }

    struct Float: ViewModifier {
        var seed: Double
        var enabled: Bool
        func body(content: Content) -> some View {
            if enabled {
                TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    content.offset(y: sin(t * 0.8 + seed * 1.7) * 6)
                }
            } else {
                content
            }
        }
    }
}
