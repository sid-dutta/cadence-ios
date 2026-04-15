import Foundation
import Security

/// Where the API bearer token lives. Kept behind a protocol so previews and
/// tests never touch the real Keychain.
public protocol TokenStore: Sendable {
    func read() -> String?
    func write(_ token: String?)
}

/// Stores the token as a generic-password Keychain item, scoped to this app.
/// `UserDefaults` would be simpler but is readable from device backups, which
/// is the wrong place for a credential.
public struct KeychainTokenStore: TokenStore {
    private let service = "com.sidharthdutta.cadence"
    private let account = "api-token"

    public init() {}

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func write(_ token: String?) {
        SecItemDelete(baseQuery as CFDictionary)
        guard let token, let data = token.data(using: .utf8) else { return }

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }
}

public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    public init(token: String? = nil) {
        self.token = token
    }

    public func read() -> String? { lock.withLock { token } }
    public func write(_ token: String?) { lock.withLock { self.token = token } }
}
