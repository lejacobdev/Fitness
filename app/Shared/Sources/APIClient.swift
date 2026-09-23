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

    /// §14/M5: one logged session plus its sets, exactly what `POST
    /// /sync/sessions` expects. Field names and shapes mirror
    /// backend/src/routes/sync.js's validation directly.
    public struct SyncSessionRequest: Sendable {
        public let session: SessionPayload
        public let sets: [SetPayload]

        public init(session: SessionPayload, sets: [SetPayload]) {
            self.session = session
            self.sets = sets
        }

        public struct SessionPayload: Sendable {
            public let clientId: String
            public let startedAt: Date
            public let endedAt: Date?
            public let sessionRPE: Int?
            public let minutes: Int
            public let source: String
            public let plannedSessionId: String?
            public let healthKitWorkoutId: String?

            public init(
                clientId: String, startedAt: Date, endedAt: Date? = nil, sessionRPE: Int? = nil,
                minutes: Int, source: String, plannedSessionId: String? = nil, healthKitWorkoutId: String? = nil
            ) {
                self.clientId = clientId
                self.startedAt = startedAt
                self.endedAt = endedAt
                self.sessionRPE = sessionRPE
                self.minutes = minutes
                self.source = source
                self.plannedSessionId = plannedSessionId
                self.healthKitWorkoutId = healthKitWorkoutId
            }
        }

        public struct SetPayload: Sendable {
            public let clientId: String
            public let itemSlug: String
            public let setIndex: Int
            public let reps: Int?
            public let weightKg: Double?
            public let seconds: Int?
            public let distanceM: Double?
            public let contacts: Int?
            public let side: String?

            public init(
                clientId: String, itemSlug: String, setIndex: Int, reps: Int? = nil,
                weightKg: Double? = nil, seconds: Int? = nil, distanceM: Double? = nil,
                contacts: Int? = nil, side: String? = nil
            ) {
                self.clientId = clientId
                self.itemSlug = itemSlug
                self.setIndex = setIndex
                self.reps = reps
                self.weightKg = weightKg
                self.seconds = seconds
                self.distanceM = distanceM
                self.contacts = contacts
                self.side = side
            }
        }
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

    /// POST /sync/sessions, authenticated (§3's sync responsibility, M5's
    /// slice of it). Idempotent on the server by `clientId` — safe to call
    /// again for the same session (SyncQueue does exactly that on every
    /// retry) without ever producing a duplicate row.
    public func syncSession(_ request: SyncSessionRequest, sessionToken: String) async throws {
        var sessionJSON: [String: Any] = [
            "clientId": request.session.clientId,
            "startedAt": Self.iso8601String(request.session.startedAt),
            "minutes": request.session.minutes,
            "source": request.session.source,
        ]
        if let endedAt = request.session.endedAt {
            sessionJSON["endedAt"] = Self.iso8601String(endedAt)
        }
        if let rpe = request.session.sessionRPE { sessionJSON["sessionRPE"] = rpe }
        if let plannedSessionId = request.session.plannedSessionId {
            sessionJSON["plannedSessionId"] = plannedSessionId
        }
        if let workoutId = request.session.healthKitWorkoutId {
            sessionJSON["healthKitWorkoutId"] = workoutId
        }

        let setsJSON: [[String: Any]] = request.sets.map { set in
            var setJSON: [String: Any] = [
                "clientId": set.clientId, "itemSlug": set.itemSlug, "setIndex": set.setIndex,
            ]
            if let reps = set.reps { setJSON["reps"] = reps }
            if let weightKg = set.weightKg { setJSON["weightKg"] = weightKg }
            if let seconds = set.seconds { setJSON["seconds"] = seconds }
            if let distanceM = set.distanceM { setJSON["distanceM"] = distanceM }
            if let contacts = set.contacts { setJSON["contacts"] = contacts }
            if let side = set.side { setJSON["side"] = side }
            return setJSON
        }

        var urlRequest = URLRequest(url: baseURL.appending(path: "sync/sessions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: ["session": sessionJSON, "sets": setsJSON])

        let (data, response) = try await perform(urlRequest)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw apiError(from: response, data: data)
        }
    }

    public struct CheckInPayload: Sendable {
        public let clientId: String
        public let date: Date
        public let sleepQuality: Int
        public let sleepHours: Double?
        public let soreness: Int
        public let sorenessAreas: [String]
        public let energy: Int
        public let stress: Int
        public let readinessBand: String?
        public let readinessZ: Double?

        public init(
            clientId: String, date: Date, sleepQuality: Int, sleepHours: Double?, soreness: Int,
            sorenessAreas: [String], energy: Int, stress: Int, readinessBand: String?, readinessZ: Double?
        ) {
            self.clientId = clientId
            self.date = date
            self.sleepQuality = sleepQuality
            self.sleepHours = sleepHours
            self.soreness = soreness
            self.sorenessAreas = sorenessAreas
            self.energy = energy
            self.stress = stress
            self.readinessBand = readinessBand
            self.readinessZ = readinessZ
        }
    }

    /// POST /sync/checkins — §14: one row per athlete per day, upserted, so
    /// re-pushing an edited check-in updates the same day on the server.
    public func syncCheckIn(_ checkIn: CheckInPayload, sessionToken: String) async throws {
        var json: [String: Any] = [
            "clientId": checkIn.clientId,
            "date": Self.dayString(checkIn.date),
            "sleepQuality": checkIn.sleepQuality,
            "soreness": checkIn.soreness,
            "sorenessAreas": checkIn.sorenessAreas,
            "energy": checkIn.energy,
            "stress": checkIn.stress,
        ]
        if let sleepHours = checkIn.sleepHours { json["sleepHours"] = sleepHours }
        if let band = checkIn.readinessBand { json["readinessBand"] = band }
        if let z = checkIn.readinessZ { json["readinessZ"] = z }

        var urlRequest = URLRequest(url: baseURL.appending(path: "sync/checkins"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: ["checkIn": json])

        let (data, response) = try await perform(urlRequest)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw apiError(from: response, data: data)
        }
    }

    /// A check-in's calendar day in the athlete's own time zone, as
    /// YYYY-MM-DD — the server stores it as a DATE, never a timestamp that
    /// could shift a day across a time-zone boundary.
    static func dayString(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
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
