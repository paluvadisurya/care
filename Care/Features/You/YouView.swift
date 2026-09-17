import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules
import CareIntelligence
import CareReminders

/// Own profile, intelligence controls, reminders, appearance, data.
struct YouView: View {
    @Environment(CareStore.self) private var store
    @Environment(AppPreferences.self) private var prefs
    @Environment(AppRouter.self) private var router

    var body: some View {
        ZStack {
            MeshBackground(aura: store.me?.aura ?? .ink, intensity: 0.7)
            ScrollView {
                VStack(alignment: .leading, spacing: CareSpace.lg) {
                    ScreenTitle(eyebrow: "You", lead: "Your", accent: "settings").padding(.top, CareSpace.xs)
                    meCard
                    IntelligenceSettingsCard()
                    RemindersSettingsCard()
                    appearanceCard
                    DataCard()
                    aboutCard
                }
                .padding(.horizontal, CareSpace.gutter)
                .padding(.bottom, CareSpace.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var meCard: some View {
        Group {
            if let me = store.me {
                Button { router.tab = .people; router.selectedPersonID = me.id } label: {
                    HStack(spacing: CareSpace.sm) {
                        PersonOrb(initials: me.initials, aura: me.aura, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(me.name).font(CareFont.cardTitle).foregroundStyle(CareColor.textPrimary)
                            Text("\(ModuleHelpers.plural(me.enabledModules.count, "module")) on your own profile · \(ModuleHelpers.plural(store.others.count, "person", "people")) in your circle")
                                .font(CareFont.caption).foregroundStyle(CareColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(CareColor.textMuted)
                    }
                    .careCard(strong: true)
                }
                .buttonStyle(.pressable(scale: 0.98))
            }
        }
    }

    private var appearanceCard: some View {
        @Bindable var prefs = prefs
        return VStack(alignment: .leading, spacing: CareSpace.xs) {
            SectionLabel("Appearance")
            ChipRow(items: AppPreferences.Appearance.allCases, selection: [prefs.appearance], label: { $0.rawValue.capitalized }) { prefs.appearance = $0 }
            Text("Night mode is deep and glowing. Light is warm. System follows your phone.").font(CareFont.meta).foregroundStyle(CareColor.textMuted)
        }
        .careCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("About")
            Text("Care, Phase 0. Local only. Nothing leaves this phone unless you add a model key or share an export.")
                .font(CareFont.callout).foregroundStyle(CareColor.textSecondary)
            Text("Type: Bricolage Grotesque, Geist, Geist Mono and Instrument Serif, all under the SIL Open Font License.")
                .font(CareFont.meta).foregroundStyle(CareColor.textMuted)
        }
        .careCard()
    }
}

/// Provider choice, API key entry into the Keychain, model names, a connection test.
struct IntelligenceSettingsCard: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(InsightCoordinator.self) private var insights
    @State private var keyInput = ""
    @State private var savedKey = false
    @State private var testResult: String?
    @State private var testing = false
    private let secrets: any SecretStore = KeychainSecretStore()

    var body: some View {
        @Bindable var prefs = prefs
        VStack(alignment: .leading, spacing: CareSpace.sm) {
            HStack {
                Image(systemName: "sparkle").foregroundStyle(CareColor.intelligence)
                SectionLabel("Intelligence")
                Spacer()
                Text(insights.hasKey ? "\(prefs.provider.displayName) key saved" : "on device").font(CareFont.meta).foregroundStyle(insights.hasKey ? CareColor.positive : CareColor.textMuted)
            }
            Text("Without a key, insights are written on device from your own numbers. Add an OpenAI or DeepSeek key and the model writes them instead. Keys live in the Keychain.")
                .font(CareFont.caption).foregroundStyle(CareColor.textSecondary)
            ChipRow(items: ProviderID.allCases, selection: [prefs.provider], label: { $0.displayName }) { p in
                prefs.provider = p
                keyInput = ""
                testResult = nil
            }
            HStack(spacing: CareSpace.xs) {
                SecureField(insights.hasKey ? "Replace the saved key" : "Paste your \(prefs.provider.displayName) key", text: $keyInput)
                    .font(CareFont.body).textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(.horizontal, CareSpace.sm).frame(minHeight: 46)
                    .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.inner))
                PillButton("Save", style: .ink, compact: true) {
                    secrets.setSecret(keyInput.trimmingCharacters(in: .whitespacesAndNewlines), for: prefs.provider)
                    keyInput = ""
                    savedKey.toggle()
                    testResult = nil
                }
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .sensoryFeedback(.success, trigger: savedKey)
            HStack(spacing: CareSpace.xs) {
                CareField("Daily model", placeholder: ModelConfig.default(for: prefs.provider).dailyModel,
                          text: Binding(get: { prefs.activeModelConfig.dailyModel }, set: { var c = prefs.activeModelConfig; c.dailyModel = $0; prefs.activeModelConfig = c }))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                CareField("Weekly model", placeholder: ModelConfig.default(for: prefs.provider).weeklyModel,
                          text: Binding(get: { prefs.activeModelConfig.weeklyModel }, set: { var c = prefs.activeModelConfig; c.weeklyModel = $0; prefs.activeModelConfig = c }))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            CareToggleRow("Use the model", detail: "Off keeps everything on device even with a key", isOn: $prefs.intelligenceEnabled)
            HStack(spacing: CareSpace.xs) {
                PillButton(testing ? "Testing…" : "Test connection", symbol: "bolt", style: .ghost, compact: true) { Task { await test() } }
                    .disabled(testing || !insights.hasKey)
                if insights.hasKey {
                    PillButton("Remove key", style: .ghost, compact: true) {
                        secrets.setSecret(nil, for: prefs.provider)
                        savedKey.toggle()
                        testResult = nil
                    }
                }
                Spacer()
            }
            if let testResult {
                Text(testResult).font(CareFont.caption).foregroundStyle(testResult.hasPrefix("OK") ? CareColor.positive : CareColor.attention)
            }
            Link("Where to get a key", destination: prefs.provider.docsURL).font(CareFont.meta).foregroundStyle(CareColor.textMuted)
        }
        .careCard()
    }

    private func test() async {
        testing = true
        defer { testing = false }
        let engine = insights.engine()
        guard let provider = engine.provider else { testResult = "No key saved."; return }
        do {
            let text = try await provider.generateJSON(system: "Answer with JSON only.", user: "Return {\"ok\": true}", model: engine.config.dailyModel, maxOutputTokens: 40, timeout: 20)
            testResult = text.contains("ok") ? "OK. \(prefs.provider.displayName) answered with \(engine.config.dailyModel)." : "Answered, but not with the expected JSON: \(text.prefix(60))"
        } catch {
            testResult = (error as? LLMError)?.errorDescription ?? error.localizedDescription
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
        VStack(alignment: .leading, spacing: CareSpace.sm) {
            HStack {
                SectionLabel("Reminders")
                Spacer()
                Text(authorized == true ? "\(pending) planned" : (authorized == false ? "not allowed" : "")).font(CareFont.meta).foregroundStyle(CareColor.textMuted)
            }
            Text("Every nudge names a person, a reason and one action. Planned from module rules, capped per day, quiet at night. Medication is time-sensitive and exempt from the cap.")
                .font(CareFont.caption).foregroundStyle(CareColor.textSecondary)
            stepper("Daily cap", value: $prefs.reminders.dailyCap, range: 1...12, unit: "a day")
            stepper("Morning brief", value: $prefs.reminders.morningBriefHour, range: 5...11, unit: "o'clock")
            CareToggleRow("Evening wrap", detail: "Three questions at \(prefs.reminders.eveningWrapHour):00", isOn: $prefs.reminders.eveningWrapEnabled)
            stepper("Evening wrap at", value: $prefs.reminders.eveningWrapHour, range: 18...23, unit: "o'clock")
            if authorized != true {
                PillButton("Allow notifications", symbol: "bell", style: .ink, compact: true) {
                    Task { authorized = await scheduler.requestAuthorization(); pending = await scheduler.pendingCount() }
                }
            }
        }
        .careCard()
        .task { pending = await scheduler.pendingCount(); if pending > 0 { authorized = true } }
    }

    private func stepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack {
            Text(label).font(CareFont.label).foregroundStyle(CareColor.textSecondary)
            Spacer()
            Text("\(value.wrappedValue) \(unit)").font(CareFont.bodyMedium).foregroundStyle(CareColor.textPrimary).contentTransition(.numericText())
            Stepper(label, value: value, in: range).labelsHidden().tint(CareColor.ink)
        }
        .padding(.horizontal, CareSpace.sm).frame(minHeight: 46)
        .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.inner))
    }
}

struct DataCard: View {
    @Environment(CareStore.self) private var store
    @Environment(AppPreferences.self) private var prefs
    @State private var confirmWipe = false

    var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.sm) {
            SectionLabel("Your data", trailing: "\(store.entries.count) entries · \(store.events.count) events")
            Text("Everything is stored in a local database on this phone. Export is one JSON file you own.")
                .font(CareFont.caption).foregroundStyle(CareColor.textSecondary)
            HStack(spacing: CareSpace.xs) {
                ShareLink(item: ExportFile(data: store.exportJSON()), preview: SharePreview("Care export")) {
                    Label("Export JSON", systemImage: "square.and.arrow.up").font(CareFont.chip).foregroundStyle(CareColor.textPrimary)
                        .padding(.horizontal, CareSpace.sm).frame(height: 36).background(CareColor.chip, in: Capsule())
                }
                .buttonStyle(.pressable)
                if store.isEmpty {
                    PillButton("Load the demo circle", style: .ghost, compact: true) { store.seedDemo(); prefs.demoMode = true }
                }
                PillButton("Erase everything", style: .ghost, compact: true) { confirmWipe = true }
                    .foregroundStyle(CareColor.attention)
            }
        }
        .careCard()
        .confirmationDialog("Erase everything on this phone?", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Erase all people, entries and insights", role: .destructive) { store.wipeEverything(); prefs.hasOnboarded = false }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Export first if you want a copy.")
        }
    }
}

/// A JSON export that ShareLink can hand to Files, Mail or AirDrop.
struct ExportFile: Transferable {
    var data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName("care-export.json")
    }
}
