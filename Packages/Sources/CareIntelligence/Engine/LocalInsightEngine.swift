import Foundation
import CareCore

/// Writes an insight from packs without a model. It is deliberately plain and honest, so the app is useful offline
/// and the demo profile renders something real. Every sentence comes from a number in the packs.
public struct LocalInsightEngine: Sendable {
    public init() {}

    public func generate(_ ctx: ScopeContext) -> Insight {
        switch ctx.scope {
        case .home: return home(ctx)
        default: return person(ctx)
        }
    }

    // MARK: Person

    private func person(_ ctx: ScopeContext) -> Insight {
        guard let person = ctx.person else { return Insight(scope: ctx.scope, tone: .neutral, headline: "Nothing to read yet", blocks: [.note(text: "Log a few things and an insight will appear here.")]) }
        var blocks: [InsightBlock] = []
        var tone: InsightTone = .neutral
        var headline = "A quiet stretch for \(person.name)"
        var evidence: [String] = []
        let pack = Dictionary(uniqueKeysWithValues: ctx.packs.map { ($0.moduleID, $0) })

        if person.relationship == .pet {
            return pet(ctx, person: person, pack: pack)
        }

        // Mood
        if let mood = pack[.mood] {
            let checkins = mood.data["checkins"]?.intValue ?? 0
            let low = mood.data["low_days"]?.intValue ?? 0
            let trail = (mood.data["trail_14"]?.arrayValue ?? []).map { $0.intValue }
            let logged = trail.compactMap { $0 }
            let goodShare = logged.isEmpty ? 0 : Int((Double(logged.filter { $0 >= 4 }.count) / Double(logged.count) * 100).rounded())
            evidence.append("\(checkins) check-ins")
            if ctx.allowedBlocks.contains(.stat) {
                blocks.append(.stat(label: "Check-ins", value: "\(checkins)", trend: nil, tone: .neutral))
                blocks.append(.stat(label: "Good or better", value: "\(goodShare)%", trend: goodShare >= 60 ? .up : (goodShare < 40 ? .down : .flat), tone: goodShare >= 60 ? .good : (goodShare < 40 ? .attention : .neutral)))
            }
            if ctx.allowedBlocks.contains(.moodStrip), !trail.isEmpty { blocks.append(.moodStrip(label: "Mood, 14 days", values: trail)) }
            if let avg = mood.data["weekday_avg"]?.objectValue, avg.count >= 3,
               let worst = avg.min(by: { ($0.value.doubleValue ?? 5) < ($1.value.doubleValue ?? 5) }), (worst.value.doubleValue ?? 5) <= 2.8 {
                headline = goodShare >= 60 ? "A good month with a \(worst.key) dip" : "Softer days lately, \(worst.key)s hardest"
                if ctx.allowedBlocks.contains(.insight) { blocks.append(.insight(text: "\(worst.key)s average \(worst.value.doubleValue ?? 0) out of 5, the lowest weekday. Worth a lighter \(worst.key).", evidenceIDs: [])) }
            } else if checkins > 0 {
                headline = goodShare >= 70 ? "A genuinely good month for \(person.name)" : (low >= 3 ? "\(person.name) has had \(low) low days" : "Steady, with nothing alarming")
            }
            if low >= 3 { tone = .attention } else if goodShare >= 60 { tone = .positive }
        }

        // Health
        if let health = pack[.health] {
            let readings = health.data["readings"]?.arrayValue ?? []
            let highs = readings.filter { $0["high"]?.doubleValue == 1 || ($0["high"].map { if case .bool(true) = $0 { return true } else { return false } } ?? false) }
            evidence.append("\(readings.count) readings")
            if let streak = health.data["streaks"]?.arrayValue?.first, let symptom = streak["symptom"]?.stringValue, let days = streak["days"]?.intValue, days >= 2 {
                headline = "\(symptom.capitalized) for \(days) days"
                tone = .attention
                if ctx.allowedBlocks.contains(.insight) { blocks.append(.insight(text: "\(symptom.capitalized) has been logged \(days) days running. If it continues, a doctor visit is worth it.", evidenceIDs: [])) }
            } else if !highs.isEmpty {
                if pack[.mood] == nil { headline = "\(highs.count) of \(readings.count) readings above the usual range" }
                tone = .attention
                if ctx.allowedBlocks.contains(.stat) { blocks.append(.stat(label: "Readings above range", value: "\(highs.count) of \(readings.count)", trend: nil, tone: .attention)) }
            } else if !readings.isEmpty, ctx.allowedBlocks.contains(.stat) {
                blocks.append(.stat(label: "Readings in range", value: "\(readings.count) of \(readings.count)", trend: .flat, tone: .good))
                if pack[.mood] == nil { headline = "Readings steady, \(readings.count) logged"; tone = .positive }
            }
        }

        // Medication
        if let med = pack[.medication] {
            let taken = med.data["taken_14d"]?.intValue ?? 0
            let scheduled = med.data["scheduled_14d"]?.intValue ?? 0
            if scheduled > 0 {
                let pct = Int((Double(taken) / Double(scheduled) * 100).rounded())
                evidence.append("\(scheduled) doses")
                if ctx.allowedBlocks.contains(.stat) { blocks.append(.stat(label: "Doses taken, 14 days", value: "\(pct)%", trend: pct >= 90 ? .up : .down, tone: pct >= 90 ? .good : .attention)) }
                if let byDay = med.data["missed_by_weekday"]?.objectValue, let worst = byDay.max(by: { ($0.value.intValue ?? 0) < ($1.value.intValue ?? 0) }), (worst.value.intValue ?? 0) >= 2 {
                    if ctx.allowedBlocks.contains(.insight) { blocks.append(.insight(text: "Most missed doses fall on \(worst.key)s (\(worst.value.intValue ?? 0)). A reminder to whoever is around that day helps.", evidenceIDs: [])) }
                    if pack[.mood] == nil, pack[.health] == nil { headline = "Doses slip on \(worst.key)s" }
                }
            }
        }

        // Mentions
        if let mentions = pack[.mentions], let rows = mentions.data.arrayValue, !rows.isEmpty, ctx.allowedBlocks.contains(.list) {
            let wants = rows.filter { $0["type"]?.stringValue == "want" }.prefix(3)
            let worries = rows.filter { $0["type"]?.stringValue == "worry" && $0["resolved"].map { if case .bool(false) = $0 { return true } else { return false } } == true }
            evidence.append("\(rows.count) mentions")
            if !wants.isEmpty { blocks.append(.list(title: "Things \(person.name) mentioned wanting", items: wants.map { ListItem(text: $0["t"]?.stringValue ?? "", entryID: $0["id"]?.stringValue) })) }
            if let w = worries.first, ctx.allowedBlocks.contains(.talkingPoints) { blocks.append(.talkingPoints(items: ["How is \"\(w["t"]?.stringValue ?? "")\" going?"])) }
        }

        // Dates and wishlist link
        if let dates = pack[.dates], let next = dates.data.arrayValue?.first, let title = next["title"]?.stringValue, let days = next["days"]?.intValue {
            if ctx.allowedBlocks.contains(.countdown), let d = next["date"]?.stringValue { blocks.append(.countdown(title: title, date: d)) }
            let wishCount = pack[.wishlist]?.data.arrayValue?.filter { $0["do_not_buy"].map { if case .bool(false) = $0 { return true } else { return false } } == true }.count ?? 0
            if days <= 30, ctx.allowedBlocks.contains(.action), ctx.allowedModules.contains(.dates) {
                let reason = wishCount > 0 ? "\(wishCount) wishlist items, \(days) days to go" : "\(days) days to go, nothing planned yet"
                blocks.append(.action(title: "Plan \(title.lowercased())", reason: reason, deeplink: DeepLink.module(personID: UUID(uuidString: person.id) ?? UUID(), module: .dates).url.absoluteString))
            }
        }

        // Call rhythm
        if let call = pack[.callRhythm], let since = call.data["days_since"]?.intValue {
            evidence.append("last call \(since)d ago")
            if since >= 9 {
                headline = "\(since) days since you last spoke"
                tone = .attention
            }
            if ctx.allowedBlocks.contains(.talkingPoints), let points = call.data["talking_points"]?.arrayValue?.compactMap(\.stringValue), !points.isEmpty,
               !blocks.contains(where: { if case .talkingPoints = $0 { return true } else { return false } }) {
                blocks.append(.talkingPoints(items: points))
            }
            if !blocks.contains(where: { if case .action = $0 { return true } else { return false } }), ctx.allowedBlocks.contains(.action), since >= 5 {
                blocks.append(.action(title: "Call \(person.name) this week", reason: "Keeps the rhythm from slipping", deeplink: DeepLink.module(personID: UUID(uuidString: person.id) ?? UUID(), module: .callRhythm).url.absoluteString))
            }
        }

        // Travel
        if let travel = pack[.travelPlans], let trip = travel.data.arrayValue?.first, let dest = trip["dest"]?.stringValue, ctx.allowedBlocks.contains(.list) {
            blocks.append(.list(title: "Coming up", items: [ListItem(text: "\(dest), packed \(trip["packing"]?.stringValue ?? "0/0")")]))
        }

        if blocks.isEmpty {
            headline = "Not enough yet about \(person.name)"
            blocks.append(.note(text: "A few check-ins or mentions and this will fill in."))
        } else {
            let hasHealth = pack[.health] != nil || pack[.medication] != nil
            blocks.append(.note(text: "Based on \(evidence.joined(separator: ", ")).\(hasHealth ? " Not medical advice." : "") Written on device."))
        }
        return Insight(scope: ctx.scope, tone: tone, headline: headline, blocks: Array(blocks.prefix(7)), evidence: evidence)
    }

    private func pet(_ ctx: ScopeContext, person: PersonBrief, pack: [ModuleID: ContextPack]) -> Insight {
        var blocks: [InsightBlock] = []
        var headline = "\(person.name) is all set"
        var tone: InsightTone = .positive
        if let pet = pack[.petCare] {
            let dues = pet.data["due"]?.arrayValue ?? []
            let soon = dues.filter { ($0["days"]?.intValue ?? 99) <= 14 }
            if let first = soon.first, let kind = first["kind"]?.stringValue, let days = first["days"]?.intValue {
                let label = PetCareKind(rawValue: kind)?.label.lowercased() ?? kind
                headline = days <= 0 ? "\(label.capitalized) is due for \(person.name)" : "\(label.capitalized) in \(days) days"
                tone = days <= 3 ? .attention : .neutral
            }
            if !dues.isEmpty {
                blocks.append(.list(title: "Due next", items: dues.prefix(4).map { ListItem(text: "\(PetCareKind(rawValue: $0["kind"]?.stringValue ?? "")?.label ?? "") in \($0["days"]?.intValue ?? 0) days") }))
            }
            if let weights = pet.data["weights"]?.arrayValue, weights.count >= 2 {
                let values = weights.reversed().compactMap { $0["kg"]?.doubleValue }
                blocks.append(.trend(label: "Weight, kg", points: values, annotation: values.last.map { String(format: "%.1f kg now", $0) }))
            }
        }
        if let appt = pack[.appointments], let next = appt.data["next"], next != .null, let date = next["date"]?.stringValue {
            blocks.append(.countdown(title: next["title"]?.stringValue ?? "Vet", date: date))
        }
        blocks.append(.note(text: "Based on pet care logs. Written on device."))
        return Insight(scope: ctx.scope, tone: tone, headline: headline, blocks: blocks)
    }

    // MARK: Home

    private func home(_ ctx: ScopeContext) -> Insight {
        let signals = ctx.packs.first { $0.moduleID == .events }?.data["signals"]?.arrayValue ?? []
        let attention = signals.filter { $0["tone"]?.stringValue == "attention" }
        var blocks: [InsightBlock] = []
        let peopleCount = ctx.people.filter { $0.relationship != .me }.count
        let headline: String
        let tone: InsightTone
        if attention.isEmpty {
            headline = signals.isEmpty ? "Everyone is fine. Nothing needs you today." : "\(signals.count) small things today. Everyone else is fine."
            tone = .positive
        } else {
            let names = Set(attention.compactMap { $0["person"]?.stringValue })
            headline = names.count == 1 ? "\(names.first ?? "Someone") needs a moment today" : "\(names.count) people need a moment today"
            tone = .attention
        }
        blocks.append(.stat(label: "Needs you", value: "\(attention.count)", trend: nil, tone: attention.isEmpty ? .good : .attention))
        blocks.append(.stat(label: "People", value: "\(peopleCount)", trend: nil, tone: .neutral))
        if !signals.isEmpty {
            blocks.append(.list(title: "Today, in order", items: signals.prefix(4).map { ListItem(text: $0["title"]?.stringValue ?? "") }))
        }
        blocks.append(.note(text: "Ranked on device from \(signals.count) signals. Written on device."))
        return Insight(scope: .home, tone: tone, headline: headline, blocks: blocks)
    }
}
