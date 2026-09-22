import Foundation

/// The thin backend's three network-reachable responsibilities (§3): sign
/// in, sync, and pack download. Deliberately minimal — no networking
/// library (§0/§23: no third-party Swift packages), just `URLSession`.
public struct APIClient: Sendable {
    public let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public struct AuthResponse: Sendable {
        public let sessionToken: String
        public let athlete: AthleteSummary
        public struct AthleteSummary: Sendable {
            public let id: String
            /// The Apple `sub`. Needed, not just `id`, because a restore onto
            /// a brand-new device has no local Athlete row yet and both are
            /// required fields on the SwiftData model (AthleteModels.swift).
            public let appleUserId: String
            public let birthDate: Date
            public let createdAt: Date
        }
    }

    /// The over-the-wire shape, decoded as plain strings first. Prisma/Express
    /// serialise `DateTime` via `Date.prototype.toJSON()`, which always
    /// includes millisecond fractional seconds (`...T00:00:00.000Z`) —
    /// `JSONDecoder`'s built-in `.iso8601` strategy uses `withInternetDateTime`
    /// only and fails closed on every real response this backend sends, so
    /// both date fields are parsed explicitly instead of trusting it.
    private struct WireAuthResponse: Decodable {
        let sessionToken: String
        let athlete: WireAthleteSummary
        struct WireAthleteSummary: Decodable {
            let id: String
            let appleUserId: String
            let birthDate: String
            let createdAt: String
        }
    }

    public enum APIError: Error, Sendable {
        case http(status: Int, code: String?)
        case decoding
        case transport(underlying: Error)
    }

    /// POST /auth/apple. `birthDate` is required only on a first sign-in
    /// (§2's age gate happens client-side before this call, so the client
    /// already knows the athlete's birth date by the time it gets here) —
    /// omitted on every subsequent sign-in, when the server already has it.
    public func signInWithApple(identityToken: String, rawNonce: String?, birthDate: Date?) async throws -> AuthResponse {
        var body: [String: Any] = ["identityToken": identityToken]
        if let rawNonce { body["rawNonce"] = rawNonce }
        if let birthDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            body["birthDate"] = formatter.string(from: birthDate)
        }

        var request = URLRequest(url: baseURL.appending(path: "auth/apple"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw apiError(from: response, data: data)
        }
        return try Self.decodeAuthResponse(from: data)
    }

    static func decodeAuthResponse(from data: Data) throws -> AuthResponse {
        let wire: WireAuthResponse
        do {
            wire = try JSONDecoder().decode(WireAuthResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
        guard
            let birthDate = parseISO8601(wire.athlete.birthDate),
            let createdAt = parseISO8601(wire.athlete.createdAt)
        else {
            throw APIError.decoding
        }
        return AuthResponse(
            sessionToken: wire.sessionToken,
            athlete: .init(
                id: wire.athlete.id, appleUserId: wire.athlete.appleUserId,
                birthDate: birthDate, createdAt: createdAt
            )
        )
    }

    /// Tries with fractional seconds first (what this backend actually
    /// sends) and falls back to the plain form, so a future backend change
    /// that drops milliseconds does not break decoding either.
    private static func parseISO8601(_ string: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) { return date }
        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]
        return withoutFractional.date(from: string)
    }

    /// GET /packs/manifest.json — the checksummed index every pack download
    /// verifies against (§3). Plain `Data`, decoded by the caller
    /// (PackDownloader), since the manifest's shape lives in content/, not here.
    public func fetchPackManifest() async throws -> Data {
        try await fetchPack(named: "manifest.json")
    }

    /// GET /packs/<file>. §3: served with an ETag; `URLSession`'s own HTTP
    /// cache already honours that via `Cache-Control`/conditional requests
    /// when using `.useProtocolCachePolicy` (the default), so there is no
    /// hand-rolled conditional-GET logic on the client side either.
    public func fetchPack(named file: String) async throws -> Data {
        let request = URLRequest(url: baseURL.appending(path: "packs/\(file)"))
        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw apiError(from: response, data: data)
        }
        return data
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.transport(underlying: error)
        }
    }

    private func apiError(from response: URLResponse, data: Data) -> APIError {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let code = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
        return .http(status: status, code: code)
    }
}
