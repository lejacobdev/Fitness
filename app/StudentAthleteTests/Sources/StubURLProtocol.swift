import Foundation

/// A network stand-in for tests that need a controlled response — or, for
/// §21's offline behaviour tests, a controlled failure — without touching a
/// real socket. `APIClient`/`PackDownloader` take a plain `URLSession`, so
/// pointing that session's configuration at this protocol is the only hook
/// needed; nothing under test has to know it is being stubbed.
final class StubURLProtocol: URLProtocol {
    /// Boxed behind a lock rather than a bare global, so this compiles clean
    /// under `SWIFT_STRICT_CONCURRENCY = complete` (project.yml) without
    /// depending on `nonisolated(unsafe)` being available on the toolchain
    /// this runs under.
    static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))? {
        get { box.value }
        set { box.value = newValue }
    }

    private static let box = HandlerBox()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class HandlerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    var value: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))? {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); defer { lock.unlock() }; _value = newValue }
    }
}
