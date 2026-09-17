import Foundation

#if canImport(Security)
import Security

/// Keys live in the Keychain, never in UserDefaults or source.
public final class KeychainSecretStore: SecretStore, @unchecked Sendable {
    private let service: String

    public init(service: String = "com.paluvadi.care.llm") {
        self.service = service
    }

    public func secret(for provider: ProviderID) -> String? {
        var query = baseQuery(provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func setSecret(_ value: String?, for provider: ProviderID) {
        let query = baseQuery(provider)
        SecItemDelete(query as CFDictionary)
        guard let value, !value.isEmpty, let data = value.data(using: .utf8) else { return }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private func baseQuery(_ provider: ProviderID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
    }
}
#endif
