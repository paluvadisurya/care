import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules

/// Every module as a card with its tier label, toggled per person. It exists from day one so the paywall can
/// be switched on later without a redesign: the tier already renders, it just always reads "Included".
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
        if let id = personID ?? initialPersonID, let match = store.person(id) { return match }
        return store.people.first
    }

    private var modules: [ModuleMeta] {
        ModuleCatalog.all.filter { category == nil || $0.category == category }
    }

    private var onCount: Int {
        guard let person else { return 0 }
        return person.enabledModules.count
    }

    var body: some View {
        ZStack {
            MeshBackground(aura: person?.aura ?? .violetLilac, intensity: 0.85)
            ScrollView {
                VStack(alignment: .leading, spacing: CareLayout.sectionGap) {
                    header
                        .careGutter()

                    OrbRail(people: store.people, size: .small, selection: person?.id, showsLabels: true) { id in
                        personID = id
                    }

                    VStack(alignment: .leading, spacing: CareLayout.stackGap) {
                        ChipRow(items: [ModuleCategory?.none] + ModuleCategory.allCases.map { Optional($0) },
                                selection: [category],
                                label: { $0?.displayName ?? "All" }) { category = $0 }
                            .padding(.horizontal, -CareSpace.gutter)

                        BentoGrid {
                            ForEach(modules) { meta in
                                ModuleStoreCard(meta: meta,
                                                person: person,
                                                label: entitlement.label(for: meta.id),
                                                isOn: person?.isEnabled(meta.id) ?? false) { isOn in
                                    guard let person else { return }
                                    store.setModule(meta.id, enabled: isOn, for: person.id)
                                }
                            }
                        }
                    }
                    .careGutter()

                    Text("Tier labels come from the module descriptor. Everything reads Included while Phase 0 keeps the paywall off.")
                        .careType(.meta)
                        .foregroundStyle(CareColor.textMuted)
                        .careGutter()
                }
                .padding(.top, CareSpace.sm)
                .padding(.bottom, CareLayout.sectionGap)
            }
            .scrollIndicators(.hidden)
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CareRadius.hero)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: CareSpace.sm) {
            ScreenTitle(eyebrow: person.map { "For \($0.shortName) · \(onCount) on" } ?? "Modules",
                        lead: "Switch on what",
                        accent: "matters",
                        role: .sheetTitle)
            Spacer(minLength: 0)
            IconButton("xmark", label: "Close") { dismiss() }
        }
    }
}

/// One module in the store. Fixed zones so every card in a row lines up regardless of tagline length.
struct ModuleStoreCard: View {
    @ScaledMetric(relativeTo: .headline) private var minHeight: CGFloat = 158
    let meta: ModuleMeta
    let person: PersonRecord?
    let label: String
    let isOn: Bool
    let onToggle: (Bool) -> Void

    private var isSuggested: Bool {
        guard let person, !isOn else { return false }
        return person.relationship.suggestedModules.contains(meta.id) || meta.defaultFor.contains(person.relationship)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            HStack {
                Text(meta.emoji)
                    .font(.system(size: 21))
                Spacer(minLength: 0)
                if meta.isImplemented {
                    Toggle("", isOn: Binding(get: { isOn }, set: onToggle))
                        .labelsHidden()
                        .tint(CareColor.ink)
                        .scaleEffect(0.82, anchor: .trailing)
                        .accessibilityLabel(meta.name)
                } else {
                    Text(meta.tier == .later ? "Later" : "Soon")
                        .careType(.meta)
                        .foregroundStyle(CareColor.textMuted)
                }
            }
            .frame(height: 26)

            Text(meta.name)
                .careType(.bodyEmphasis)
                .foregroundStyle(CareColor.textPrimary)
                .lineLimit(1)

            Text(meta.tagline)
                .careType(.caption)
                .foregroundStyle(CareColor.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: CareSpace.xxs)

            HStack(spacing: 5) {
                TierBadge(text: label, tone: meta.tier == .core ? CareColor.positive : CareColor.intelligence)
                if meta.autoFills { TierBadge(text: "auto", tone: CareColor.textMuted) }
                if isSuggested { TierBadge(text: "suggested", tone: CareColor.upcoming) }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
        .careSurface(.tile)
        .opacity(meta.isImplemented ? 1 : 0.68)
        .accessibilityElement(children: .combine)
    }
}

private struct TierBadge: View {
    var text: String
    var tone: Color

    var body: some View {
        Text(text)
            .careType(.meta)
            .foregroundStyle(tone)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(CareColor.chip, in: Capsule())
    }
}
