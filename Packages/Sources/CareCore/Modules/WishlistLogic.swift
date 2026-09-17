import Foundation

public struct WishlistItemPayload: Codable, Hashable, Sendable {
    public var title: String
    public var url: String?
    public var price: Double?
    public var currency: String?
    public var note: String?
    public var doNotBuy: Bool
    public var claimed: Bool
    public var purchased: Bool

    public init(title: String, url: String? = nil, price: Double? = nil, currency: String? = "INR", note: String? = nil,
                doNotBuy: Bool = false, claimed: Bool = false, purchased: Bool = false) {
        self.title = title
        self.url = url
        self.price = price
        self.currency = currency
        self.note = note
        self.doNotBuy = doNotBuy
        self.claimed = claimed
        self.purchased = purchased
    }

    public var priceLabel: String? {
        guard let price else { return nil }
        let symbol = currency == "INR" || currency == nil ? "₹" : (currency == "USD" ? "$" : (currency ?? "") + " ")
        return price == price.rounded() ? "\(symbol)\(Int(price))" : symbol + String(format: "%.2f", price)
    }
}

public enum WishlistLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.wishlist)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .stat, .list, .action, .note]

    public static func items(_ ctx: ModuleContext) -> [(EntryRecord, WishlistItemPayload)] {
        ctx.entries.compactMap { e -> (EntryRecord, WishlistItemPayload)? in
            guard let item = e.decode(WishlistItemPayload.self) else { return nil }
            return (e, item)
        }
    }

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        let open = items(ctx).filter { !$0.1.purchased && !$0.1.doNotBuy }
        guard !open.isEmpty else { return ModuleTodayState(headline: "Empty", detail: "Share a link") }
        let priced = open.compactMap { $0.1.price }
        let detail = priced.isEmpty ? open.prefix(2).map { $0.1.title }.joined(separator: ", ") : "\(priced.filter { $0 <= 3000 }.count) under ₹3,000"
        return ModuleTodayState(headline: ModuleHelpers.plural(open.count, "item"), detail: detail)
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        let p = ctx.person
        let open = items(ctx).filter { !$0.1.purchased && !$0.1.doNotBuy && !$0.1.claimed }
        guard !open.isEmpty else { return [] }
        let dates = ctx.events(for: .dates).map { $0.nextOccurrence(after: ctx.now, calendar: ctx.calendar) }.filter { CareDates.daysBetween(ctx.now, $0, calendar: ctx.calendar) <= 30 }
        guard let date = dates.min() else { return [] }
        return [Signal(id: ModuleHelpers.signalID(.wishlist, .wishlistInBudget, p.id), personID: p.id, moduleID: .wishlist, kind: .wishlistInBudget,
                       title: "Gift for \(p.shortName)", body: "\(ModuleHelpers.plural(open.count, "unclaimed item")) on the wishlist. \(CareDates.relativeDays(from: ctx.now, to: date).capitalized).",
                       at: date, priority: 0.25, tone: .upcoming,
                       actions: [SignalAction(title: "Pick one", link: .module(personID: p.id, module: .wishlist), isPrimary: true)])]
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let rows = items(ctx).filter { !$0.1.purchased }.map { JSONValue.object(["id": .string($0.0.id.uuidString), "title": .string($0.1.title), "price": $0.1.price.map { .number($0) } ?? .null, "do_not_buy": .bool($0.1.doNotBuy), "claimed": .bool($0.1.claimed)]) }
        guard !rows.isEmpty else { return nil }
        return ContextPack(moduleID: .wishlist, summary: "\(rows.count) wishlist items", data: .array(rows))
    }
}
