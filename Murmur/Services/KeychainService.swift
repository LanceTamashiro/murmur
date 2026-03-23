import Foundation
import Security

/// Manages API key storage in the macOS Keychain.
///
/// Keys are stored as generic passwords with the service name
/// `"murmur.apikey.<providerID>"`. This keeps each provider's
/// key isolated and identifiable.
struct KeychainService: Sendable {

    private let servicePrefix: String

    init(servicePrefix: String = "murmur.apikey") {
        self.servicePrefix = servicePrefix
    }

    /// Save an API key for the given provider. Overwrites any existing key.
    func save(apiKey: String, for providerID: String) throws {
        let service = serviceName(for: providerID)
        let data = Data(apiKey.utf8)

        // Delete existing key first (ignore error if not found)
        delete(for: providerID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Load the API key for the given provider. Returns nil if not found.
    func load(for providerID: String) -> String? {
        let service = serviceName(for: providerID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// Delete the API key for the given provider.
    @discardableResult
    func delete(for providerID: String) -> Bool {
        let service = serviceName(for: providerID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Private

    private func serviceName(for providerID: String) -> String {
        "\(servicePrefix).\(providerID)"
    }
}

enum KeychainError: Error, Sendable {
    case saveFailed(OSStatus)
}
