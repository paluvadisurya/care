import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules

/// Every module as a card with its tier label. Toggle per person. Exists from day one so the paywall can be switched on later.
struct ModuleStoreView: View {
    @Environment(CareStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let initialPersonID: UUID?
    @State private var personID: UUID?
    @State private var category: ModuleCategory?
    private let entitlement = EntitlementService.shared

    init(initialPersonID: UUID?) {
        self.initialPersonID = initialPersonID
    }

    private var person: PersonRecord? {
        if let id = personID ?? initialPersonID, let p = store.person(id) { return p }
        return store.people.first
    }

    private var modules: [ModuleMeta] {
        ModuleCatalog.all.filter { category == nil || $0.category == category }
    }

    var body: some View {
        ZStack {
            MeshBackground(aura: person?.aura ?? .violetLilac, intensity: 0.8)
            ScrollView {
                VStack(alignment: .leading, spacing: CareSpace.md) {
                    HStack(alignment: .top) {
                        ScreenTitle(eyebrow: person.map { "For \($0.shortName)" } ?? "Modules", lead: "Switch on what", accent: "matters", size: 30)
                        Spacer()
                        IconButton("xmark", label: "Close") { dismiss() }
                    }
                    ScrollView(.horizontal) {
                        HStack(spacing: CareSpace.xs) {
                            ForEach(store.people) { p in
                                Button { personID = p.id } label: {
                                    PersonOrb(initials: p.initials, aura: p.aura, size: 38, isSelected: p.id == person?.id, symbol: p.relationship == .pet ? "pawprint.fill" : nil)
                                }
                                .buttonStyle(.pressable)
                                .accessibilityLabel(p.name)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .scrollIndicators(.hidden)
                    ChipRow(items: [nil] + ModuleCategory.allCases.map { Optional($0) }, selection: [category], label: { $0?.displayName ?? "All" }) { category = $0 }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: CareSpace.sm), GridItem(.flexible(), spacing: CareSpace.sm)], spacing: CareSpace.sm) {
                        ForEach(modules) { meta in
                            ModuleStoreCard(meta: meta, person: person, label: entitlement.label(for: meta.id), isOn: person?.isEnabled(meta.id) ?? false) { on in
                                if let person { store.setModule(meta.id, enabled: on, for: person.id) }
                            }
                        }
                    }
                    Text("Tier labels come from the module descriptor. Everything reads Included while Phase 0 keeps the paywall off.")
                        .font(CareFont.meta).foregroundStyle(CareColor.textMuted)
                }
                .padding(CareSpace.gutter)
            }
            .scrollIndicators(.hidden)
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CareRadius.hero)
    }
}

struct ModuleStoreCard: View {
    let meta: ModuleMeta
    let person: PersonRecord?
    let label: String
    let isOn: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        let suggested = person.map { $0.relationship.suggestedModules.contains(meta.id) || meta.defaultFor.contains($0.relationship) } ?? false
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            HStack {
                Text(meta.emoji).font(.system(size: 22))
                Spacer()
                if meta.isImplemented {
                    Toggle("", isOn: Binding(get: { isOn }, set: onToggle)).labelsHidden().tint(CareColor.ink).scaleEffect(0.85)
                } else {
                    Text(meta.tier == .later ? "Later" : "Soon").font(CareFont.meta).foregroundStyle(CareColor.textMuted)
                }
            }
            Text(meta.name).font(CareFont.textSemi(15, relativeTo: .body)).foregroundStyle(CareColor.textPrimary)
            Text(meta.tagline).font(CareFont.caption).foregroundStyle(CareColor.textSecondary).lineLimit(3)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Text(label).font(CareFont.meta).foregroundStyle(meta.tier == .core ? CareColor.positive : CareColor.violet)
                    .padding(.horizontal, 7).padding(.vertical, 3).background(CareColor.chip, in: Capsule())
                if meta.autoFills { Text("auto").font(CareFont.meta).foregroundStyle(CareColor.textMuted).padding(.horizontal, 7).padding(.vertical, 3).background(CareColor.chip, in: Capsule()) }
                if suggested, !isOn { Text("suggested").font(CareFont.meta).foregroundStyle(CareColor.upcoming) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .careCard(radius: CareRadius.tile, padding: CareSpace.sm + 2)
        .opacity(meta.isImplemented ? 1 : 0.7)
    }
}
