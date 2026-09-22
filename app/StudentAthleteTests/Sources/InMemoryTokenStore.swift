import Foundation

/// A `TokenStore` test double. Keychain access from this unhosted test
/// target isn't something CI can verify reliably (see TokenStore.swift's own
/// doc comment), so SyncQueue is tested against this instead — the real
/// KeychainTokenStore is exercised at runtime, not here.
final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storedToken: String?

    init(token: String? = nil) {
        storedToken = token
    }

    func save(_ token: String) throws {
        lock.lock(); defer { lock.unlock() }
        storedToken = token
    }

    func read() throws -> String? {
        lock.lock(); defer { lock.unlock() }
        return storedToken
    }

    func delete() throws {
        lock.lock(); defer { lock.unlock() }
        storedToken = nil
    }
}
