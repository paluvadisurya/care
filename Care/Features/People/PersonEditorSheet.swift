import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules

/// Add or edit a person: name, relationship, aura, birthday, city, note. Modules default from the relationship.
struct PersonEditorSheet: View {
    @Environment(CareStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    let existing: PersonRecord?
    @State private var name: String
    @State private var relationship: Relationship
    @State private var aura: Aura
    @State private var hasBirthday: Bool
    @State private var birthday: Date
    @State private var city: String
    @State private var note: String
    @State private var confirmDelete = false

    init(existing: PersonRecord?) {
        self.existing = existing
        self.name = existing?.name ?? ""
        self.relationship = existing?.relationship ?? .partner
        self.aura = existing?.aura ?? .coralRose
        self.hasBirthday = existing?.birthday != nil
        self.birthday = existing?.birthday ?? Calendar.care.date(byAdding: .year, value: -30, to: .now) ?? .now
        self.city = existing?.homeCity ?? ""
        self.note = existing?.note ?? ""
    }

    var body: some View {
        SheetScaffold(title: existing == nil ? "Someone you look after" : "Edit \(existing?.shortName ?? "")", subtitle: existing == nil ? "New person" : "Profile",
                      aura: aura, primaryTitle: existing == nil ? "Add \(name.isEmpty ? "them" : PersonRecord.firstName(of: name))" : "Save", primaryEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) {
            save()
        } content: {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                HStack(spacing: CareSpace.sm) {
                    PersonOrb(initials: PersonRecord(name: name.isEmpty ? "?" : name, relationship: relationship, aura: aura).initials,
                              aura: aura, size: .hero,
                              symbol: relationship == .pet ? "pawprint.fill" : nil)
                    CareField("Name", placeholder: "Srivalli", text: $name)
                }
                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    SectionLabel("Who they are to you")
                    ChipRow(items: Relationship.allCases.filter { $0 != .me || existing?.relationship == .me }, selection: [relationship], label: { $0.displayName }) { r in
                        relationship = r
                        if existing == nil { aura = Aura.suggested(for: r, index: store.people.filter { $0.relationship == r }.count) }
                    }
                }
                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    SectionLabel("Aura", trailing: aura.name)
                    AuraPicker(selection: $aura)
                }
                CareToggleRow(relationship == .pet ? "Gotcha day" : "Birthday", detail: "Becomes a yearly date with a countdown", isOn: $hasBirthday)
                if hasBirthday { CareDateRow("Date", date: $birthday, components: [.date]) }
                CareField("City", placeholder: "Where they live", text: $city)
                CareField("Note", placeholder: relationship == .parent ? "BP patient, Mom gives the evening tablets" : "Anything you want to remember", text: $note, axis: .vertical)
                if existing == nil {
                    Text("Starts with: " + relationship.defaultModules.map { ModuleCatalog.meta($0).name }.joined(separator: ", ") + ". Change any time in Modules.")
                        .careType(.meta).foregroundStyle(CareColor.textMuted)
                }
                if let existing, existing.relationship != .me {
                    PillButton("Remove \(existing.shortName)", style: .ghost, compact: true) { confirmDelete = true }
                        .foregroundStyle(CareColor.attention)
                        .confirmationDialog("Remove \(existing.shortName) and everything logged about them?", isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("Remove", role: .destructive) { store.deletePerson(existing.id); router.selectedPersonID = nil; dismiss() }
                            Button("Cancel", role: .cancel) {}
                        }
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if var p = existing {
            p.name = trimmed
            p.shortName = PersonRecord.firstName(of: trimmed)
            p.relationship = relationship
            p.aura = aura
            p.birthday = hasBirthday ? birthday : nil
            p.homeCity = city.isEmpty ? nil : city
            p.note = note.isEmpty ? nil : note
            store.updatePerson(p)
        } else {
            let p = PersonRecord(name: trimmed, relationship: relationship, aura: aura, birthday: hasBirthday ? birthday : nil, homeCity: city.isEmpty ? nil : city, note: note.isEmpty ? nil : note)
            store.addPerson(p)
            if hasBirthday {
                store.addEvent(EventRecord(personID: p.id, moduleID: .dates, category: .milestone, title: relationship == .pet ? "\(p.shortName)'s gotcha day" : "\(p.shortName)'s birthday",
                                           start: birthday, isAllDay: true, recurrence: .yearly))
            }
            router.selectedPersonID = p.id
        }
    }
}

/// The eight aura presets as swatches. Each reserves a full touch target and its selection ring is drawn
/// inside that reserved space, so the row never clips at either end.
private struct AuraPicker: View {
    @Binding var selection: Aura

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CareSpace.xs) {
                ForEach(Aura.presets, id: \.self) { aura in
                    Button { selection = aura } label: {
                        ZStack {
                            Circle()
                                .fill(aura.gradient)
                                .frame(width: 34, height: 34)
                            if aura == selection {
                                Circle()
                                    .strokeBorder(CareColor.ink, lineWidth: 2.5)
                                    .frame(width: 42, height: 42)
                                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                            }
                        }
                        .frame(width: CareLayout.touchTarget, height: CareLayout.touchTarget)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.pressable(scale: 0.9))
                    .accessibilityLabel(aura.name)
                    .accessibilityAddTraits(aura == selection ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .animation(CareMotion.snappy, value: selection)
    }
}
