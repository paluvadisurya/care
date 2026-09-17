import Foundation
import Observation
import CareCore
import CareIntelligence
import CareReminders

/// Small settings that are not records. Backed by UserDefaults; keys never go here.
@Observable
public final class AppPreferences {
    private let defaults: UserDefaults

    public var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: "care.hasOnboarded") } }
    public var userName: String { didSet { defaults.set(userName, forKey: "care.userName") } }
    public var provider: ProviderID { didSet { defaults.set(provider.rawValue, forKey: "care.provider") } }
    public var intelligenceEnabled: Bool { didSet { defaults.set(intelligenceEnabled, forKey: "care.intelligenceEnabled") } }
    public var modelConfigs: [ProviderID: ModelConfig] { didSet { save(modelConfigs, key: "care.modelConfigs") } }
    public var reminders: ReminderPreferences { didSet { save(reminders, key: "care.reminders") } }
    public var demoMode: Bool { didSet { defaults.set(demoMode, forKey: "care.demoMode") } }
    public var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: "care.appearance") } }

    public enum Appearance: String, CaseIterable, Sendable { case system, light, night }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasOnboarded = defaults.bool(forKey: "care.hasOnboarded")
        userName = defaults.string(forKey: "care.userName") ?? ""
        provider = ProviderID(rawValue: defaults.string(forKey: "care.provider") ?? "") ?? .openAI
        intelligenceEnabled = defaults.object(forKey: "care.intelligenceEnabled") as? Bool ?? true
        demoMode = defaults.bool(forKey: "care.demoMode")
        appearance = Appearance(rawValue: defaults.string(forKey: "care.appearance") ?? "") ?? .system
        modelConfigs = Self.load([ProviderID: ModelConfig].self, key: "care.modelConfigs", defaults: defaults)
            ?? [.openAI: .default(for: .openAI), .deepSeek: .default(for: .deepSeek)]
        reminders = Self.load(ReminderPreferences.self, key: "care.reminders", defaults: defaults) ?? .default
    }

    public var activeModelConfig: ModelConfig {
        get { modelConfigs[provider] ?? .default(for: provider) }
        set { modelConfigs[provider] = newValue }
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? PayloadCoder.encode(value) { defaults.set(data, forKey: key) }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? PayloadCoder.decode(type, from: data)
    }
}
