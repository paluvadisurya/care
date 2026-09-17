import Foundation

/// The one seam the app asks before showing a paid surface. Always true in Phase 0.
/// StoreKit 2 plugs in behind `policy` later without touching any call site.
public struct EntitlementService: Sendable {
    public enum Policy: Sendable {
        case everythingUnlocked
        case tiers(unlocked: Set<Tier>)
    }

    public var policy: Policy

    public init(policy: Policy = .everythingUnlocked) {
        self.policy = policy
    }

    public static let shared = EntitlementService()

    public func isUnlocked(_ module: ModuleID) -> Bool {
        switch policy {
        case .everythingUnlocked: true
        case .tiers(let unlocked): unlocked.contains(ModuleCatalog.meta(module).tier)
        }
    }

    /// Label shown on a store card. "Included" for everything while the policy is open.
    public func label(for module: ModuleID) -> String {
        let tier = ModuleCatalog.meta(module).tier
        if tier == .later { return "Later" }
        return isUnlocked(module) ? "Included" : tier.label
    }
}
