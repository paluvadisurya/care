import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules
import CareIntelligence
import CareReminders

/// Your own profile, the intelligence controls, the reminder rules, appearance and your data.
struct YouView: View {
    @Environment(CareStore.self) private var store
    @Environment(AppPreferences.self) private var prefs
    @Environment(AppRouter.self) private var router

    var body: some View {
        ZStack {
            MeshBackground(aura: store.me?.aura ?? .ink, intensity: 0.7)
            ScrollView {
                VStack(alignment: .leading, spacing: CareLayout.sectionGap) {
                    ScreenTitle(eyebrow: "You", lead: "Your", accent: "settings")
                        .staggeredEntrance(index: 0)
                    MeCard { router.handle(.person($0)) }
                        .staggeredEntrance(index: 1)
                    IntelligenceSettingsCard()
                        .staggeredEntrance(index: 2)
                    RemindersSettingsCard()
                        .staggeredEntrance(index: 3)
                    AppearanceCard()
                        .staggeredEntrance(index: 4)
                    DataCard()
                        .staggeredEntrance(index: 5)
                    AboutCard()
                        .staggeredEntrance(index: 6)
                }
                .careGutter()
                .padding(.top, CareSpace.xs)
                .padding(.bottom, CareLayout.scrollBottomInset)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct MeCard: View {
    @Environment(CareStore.self) private var store
    var open: (UUID) -> Void

    var body: some View {
        if let me = store.me {
            Button { open(me.id) } label: {
                HStack(spacing: CareSpace.sm) {
                    PersonOrb(person: me, size: .header)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(me.name)
                            .careType(.cardTitle)
                            .foregroundStyle(CareColor.textPrimary)
                        Text("\(ModuleHelpers.plural(me.enabledModules.count, "module")) on your profile · \(ModuleHelpers.plural(store.others.count, "person", "people")) in your circle")
                            .careType(.caption)
                            .foregroundStyle(CareColor.textSecondary)
                    }
                    Spacer(minLength: CareSpace.xs)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CareColor.textMuted)
                }
                .careSurface(.hero)
            }
            .buttonStyle(.pressable(scale: 0.98))
        }
    }
}

/// Provider choice, the key into the Keychain, editable model names and a connection test.
struct IntelligenceSettingsCard: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(InsightCoordinator.self) private var insights
    @State private var keyInput = ""
    @State private var savedKey = false
    @State private var testResult: TestResult?
    @State private var isTesting = false
    private let secrets: any SecretStore = KeychainSecretStore()

    private enum TestResult: Equatable {
        case ok(String), failed(String)

        var text: String {
            switch self {
            case .ok(let s), .failed(let s): s
            }
        }

        var isOK: Bool { if case .ok = self { true } else { false } }
    }

    private var trimmedKey: String { keyInput.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        @Bindable var prefs = prefs
        VStack(alignment: .leading, spacing: CareLayout.stackGap) {
            HStack(spacing: CareSpace.xs) {
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(CareColor.intelligence)
                Text("Intelligence")
                    .careType(.labelEmphasis)
                    .foregroundStyle(CareColor.intelligence)
                Spacer(minLength: CareSpace.xs)
                Text(insights.hasKey ? "\(prefs.provider.displayName) key saved" : "on device")
                    .careType(.meta)
                    .foregroundStyle(insights.hasKey ? CareColor.positive : CareColor.textMuted)
            }

            Text("Without a key, insights are written on device from your own numbers. Add an OpenAI or DeepSeek key and the model writes them instead. Keys live in the Keychain.")
                .careType(.caption)
                .foregroundStyle(CareColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ChipRow(items: ProviderID.allCases, selection: [prefs.provider], label: \.displayName) { provider in
                prefs.provider = provider
                keyInput = ""
                testResult = nil
            }

            HStack(spacing: CareSpace.xs) {
                SecureField(insights.hasKey ? "Replace the saved key" : "Paste your \(prefs.provider.displayName) key", text: $keyInput)
                    .careType(.body)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, CareSpace.sm)
                    .frame(minHeight: CareLayout.touchTarget + 4)
                    .careSurface(.field, padding: 0)
                PillButton("Save", style: .ink, compact: true) {
                    secrets.setSecret(trimmedKey, for: prefs.provider)
                    keyInput = ""
                    savedKey.toggle()
                    testResult = nil
                }
                .disabled(trimmedKey.isEmpty)
            }
            .sensoryFeedback(.success, trigger: savedKey)

            HStack(spacing: CareSpace.xs) {
                CareField("Daily model",
                          placeholder: ModelConfig.default(for: prefs.provider).dailyModel,
                          text: Binding(get: { prefs.activeModelConfig.dailyModel },
                                        set: { var config = prefs.activeModelConfig; config.dailyModel = $0; prefs.activeModelConfig = config }))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                CareField("Weekly model",
                          placeholder: ModelConfig.default(for: prefs.provider).weeklyModel,
                          text: Binding(get: { prefs.activeModelConfig.weeklyModel },
                                        set: { var config = prefs.activeModelConfig; config.weeklyModel = $0; prefs.activeModelConfig = config }))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            CareToggleRow("Use the model", detail: "Off keeps everything on device even with a key", isOn: $prefs.intelligenceEnabled)

            HStack(spacing: CareSpace.xs) {
                PillButton(isTesting ? "Testing…" : "Test connection", symbol: "bolt", style: .ghost, compact: true) {
                    Task { await test() }
                }
                .disabled(isTesting || !insights.hasKey)
                if insights.hasKey {
                    PillButton("Remove key", style: .ghost, compact: true) {
                        secrets.setSecret(nil, for: prefs.provider)
                        savedKey.toggle()
                        testResult = nil
                    }
                }
                Spacer(minLength: 0)
            }

            if let testResult {
                Text(testResult.text)
                    .careType(.caption)
                    .foregroundStyle(testResult.isOK ? CareColor.positive : CareColor.attention)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .offset(y: -4)))
            }

            Link("Where to get a key", destination: prefs.provider.docsURL)
                .careType(.footnote)
                .foregroundStyle(CareColor.textMuted)
        }
        .careSurface(.card)
        .animation(CareMotion.standard, value: testResult)
    }

    private func test() async {
        isTesting = true
        defer { isTesting = false }
        let engine = insights.engine()
        guard let provider = engine.provider else {
            testResult = .failed("No key saved.")
            return
        }
        do {
            let text = try await provider.generateJSON(system: "Answer with JSON only.",
                                                       user: "Return {\"ok\": true}",
                                                       model: engine.config.dailyModel,
                                                       maxOutputTokens: 40, timeout: 20)
            testResult = text.contains("ok")
                ? .ok("OK. \(prefs.provider.displayName) answered with \(engine.config.dailyModel).")
                : .failed("Answered, but not with the expected JSON: \(text.prefix(60))")
        } catch {
            testResult = .failed((error as? LLMError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

struct RemindersSettingsCard: View {
    @Environment(AppPreferences.self) private var prefs
    @State private var authorized: Bool?
    @State private var pending = 0
    private let scheduler = ReminderScheduler()

    var body: some View {
        @Bindable var prefs = prefs
        VStack(alignment: .leading, spacing: CareLayout.stackGap) {
            SectionLabel("Reminders", trailing: authorized == false ? "not allowed" : "\(pending) planned")

            Text("Every nudge names a person, a reason and one action. Planned from module rules, capped per day, quiet at night. Medication is time-sensitive and exempt from the cap.")
                .careType(.caption)
                .foregroundStyle(CareColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            CareStepperRow("Daily cap", valueText: "\(prefs.reminders.dailyCap) a day",
                           value: $prefs.reminders.dailyCap, range: 1...12)
            CareStepperRow("Morning brief", valueText: TimeOfDay(hour: prefs.reminders.morningBriefHour).label,
                           value: $prefs.reminders.morningBriefHour, range: 5...11)
            CareToggleRow("Evening wrap",
                          detail: "Three questions at \(TimeOfDay(hour: prefs.reminders.eveningWrapHour).label)",
                          isOn: $prefs.reminders.eveningWrapEnabled)
            if prefs.reminders.eveningWrapEnabled {
                CareStepperRow("Evening wrap at", valueText: TimeOfDay(hour: prefs.reminders.eveningWrapHour).label,
                               value: $prefs.reminders.eveningWrapHour, range: 18...23)
                    .transition(.opacity.combined(with: .offset(y: -6)))
            }

            if authorized != true {
                PillButton("Allow notifications", symbol: "bell", style: .ink, compact: true) {
                    Task {
                        authorized = await scheduler.requestAuthorization()
                        pending = await scheduler.pendingCount()
                    }
                }
            }
        }
        .careSurface(.card)
        .animation(CareMotion.standard, value: prefs.reminders.eveningWrapEnabled)
        .task {
            pending = await scheduler.pendingCount()
            if pending > 0 { authorized = true }
        }
    }
}

private struct AppearanceCard: View {
    @Environment(AppPreferences.self) private var prefs

    var body: some View {
        @Bindable var prefs = prefs
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            SectionLabel("Appearance")
            SegmentedPicker(options: AppPreferences.Appearance.allCases, selection: $prefs.appearance) {
                $0.rawValue.capitalized
            }
            Text("Night is deep and glowing. Light is warm. System follows your phone.")
                .careType(.footnote)
                .foregroundStyle(CareColor.textMuted)
        }
        .careSurface(.card)
    }
}

struct DataCard: View {
    @Environment(CareStore.self) private var store
    @Environment(AppPreferences.self) private var prefs
    @State private var confirmWipe = false

    var body: some View {
        VStack(alignment: .leading, spacing: CareLayout.stackGap) {
            SectionLabel("Your data", trailing: "\(store.entries.count) entries · \(store.events.count) events")
            Text("Everything is stored in a local database on this phone. Export is one JSON file you own.")
                .careType(.caption)
                .foregroundStyle(CareColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: CareSpace.xs) {
                ShareLink(item: ExportFile(data: store.exportJSON()), preview: SharePreview("Care export")) {
                    Label("Export JSON", systemImage: "square.and.arrow.up")
                        .careType(.chipLabel)
                        .careChipSurface()
                }
                .buttonStyle(.pressable)
                if store.isEmpty {
                    PillButton("Load the demo circle", style: .ghost, compact: true) {
                        store.seedDemo()
                        prefs.demoMode = true
                    }
                }
                Spacer(minLength: 0)
            }

            Button("Erase everything", role: .destructive) { confirmWipe = true }
                .careType(.chipLabel)
                .foregroundStyle(CareColor.attention)
                .frame(minHeight: CareLayout.touchTarget, alignment: .leading)
        }
        .careSurface(.card)
        .confirmationDialog("Erase everything on this phone?", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Erase all people, entries and insights", role: .destructive) {
                store.wipeEverything()
                prefs.hasOnboarded = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Export first if you want a copy.")
        }
    }
}

private struct AboutCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("About")
            Text("Care, Phase 0. Local only. Nothing leaves this phone unless you add a model key or share an export.")
                .careType(.callout)
                .foregroundStyle(CareColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Type: Bricolage Grotesque, Geist, Geist Mono and Instrument Serif, all under the SIL Open Font License.")
                .careType(.footnote)
                .foregroundStyle(CareColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .careSurface(.card)
    }
}

/// A JSON export that ShareLink can hand to Files, Mail or AirDrop.
struct ExportFile: Transferable, Sendable {
    var data: Data

    nonisolated static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName("care-export.json")
    }
}
