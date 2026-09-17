import SwiftUI
import CareCore
import CareDesign
import CareData

public enum MentionsUI: ModuleUI {
    public static let id: ModuleID = .mentions

    public static func quickLog(person: PersonRecord, prefill: String?) -> AnyView? {
        AnyView(MentionQuickLog(person: person, prefill: prefill))
    }

    public static func detail(person: PersonRecord) -> AnyView {
        AnyView(MentionsDetail(person: person))
    }
}

struct MentionQuickLog: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var text: String
    @State private var kind: MentionKind?
    @FocusState private var focused: Bool

    init(person: PersonRecord, prefill: String?) {
        self.person = person
        self.text = prefill ?? ""
    }

    var body: some View {
        SheetScaffold(title: "\(person.shortName) said…", subtitle: "Mention", aura: person.aura, primaryTitle: "Remember it", primaryEnabled: !text.trimmingCharacters(in: .whitespaces).isEmpty) {
            store.addEntry(person: person.id, module: .mentions, payload: MentionPayload(text: text.trimmingCharacters(in: .whitespacesAndNewlines), kind: kind))
        } content: {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                HStack(alignment: .top) {
                    TextField("Wants to try the pottery class", text: $text, axis: .vertical)
                        .font(CareFont.text(20, relativeTo: .title3))
                        .foregroundStyle(CareColor.textPrimary)
                        .focused($focused)
                        .lineLimit(3...8)
                    Image(systemName: "mic.fill").foregroundStyle(CareColor.textMuted).padding(.top, 6)
                        .accessibilityLabel("Use dictation from the keyboard")
                }
                .padding(CareSpace.sm)
                .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.tile))
                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    SectionLabel("Kind", trailing: kind == nil ? "guessed: \(MentionClassifier.classify(text).label.lowercased())" : nil)
                    ChipRow(items: MentionKind.allCases, selection: kind.map { [$0] } ?? [], label: { $0.label }) { kind = kind == $0 ? nil : $0 }
                }
            }
        }
        .task { focused = true }
    }
}

struct MentionsDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var showLog = false

    var entries: [EntryRecord] { store.entries(for: person.id, module: .mentions) }

    var body: some View {
        ModuleScreen(person: person, module: .mentions, actionTitle: "Add a mention", action: { showLog = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                ForEach(MentionKind.allCases, id: \.self) { kind in
                    let group = entries.filter { $0.decode(MentionPayload.self)?.kind == kind }
                    if !group.isEmpty {
                        CardSection(kind.label + "s", trailing: "\(group.count)") {
                            ForEach(group) { e in
                                if let m = e.decode(MentionPayload.self) {
                                    CardRow(symbol: kind.symbol, title: m.text, subtitle: CareDates.relativeDays(from: .now, to: e.occurredAt).capitalized, tint: ModuleAccent.color(for: .mentions), isDone: m.resolved) {
                                        if kind == .worry || kind == .want || kind == .promise {
                                            CheckToggle(isOn: Binding(get: { m.resolved }, set: { new in
                                                var copy = m
                                                copy.resolved = new
                                                store.updateEntry(e.id, payload: copy)
                                            }))
                                        }
                                    }
                                    .contextMenu {
                                        Button("Delete", systemImage: "trash", role: .destructive) { store.deleteEntry(e.id) }
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) { store.deleteEntry(e.id) } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                            }
                        }
                    }
                }
                if entries.isEmpty {
                    EmptyState(symbol: "quote.bubble", title: "Nothing noted yet", message: "The small things they say, want and worry about. One line each.")
                }
            }
        }
        .sheet(isPresented: $showLog) { MentionQuickLog(person: person, prefill: nil) }
    }
}
