import Foundation
import Security

/// Where the session token from `/auth/apple` (§3) lives between launches.
/// Abstracted behind a protocol so `SyncQueue` and friends can be tested
/// against an in-memory fake — Keychain behaviour inside an unhosted XCTest
/// bundle running in CI is not something this environment can verify without
/// a real device/simulator run, so the real implementation is compiled and
/// used at runtime but deliberately not exercised by the test target itself.
public protocol TokenStore: Sendable {
    func save(_ token: String) throws
    func read() throws -> String?
    func delete() throws
}

public enum KeychainError: Error, Sendable {
    case status(OSStatus)
}

public struct KeychainTokenStore: TokenStore {
    private let service = "com.studentathlete.app"
    private let account = "sessionToken"

    public init() {}

    public func save(_ token: String) throws {
        // Delete-then-add rather than update-or-add: simpler, and this is
        // called once per sign-in, not a hot path.
        try? delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    public func read() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.status(status)
        }
        return String(data: data, encoding: .utf8)
    }

    public func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.status(status)
        }
    }
}
