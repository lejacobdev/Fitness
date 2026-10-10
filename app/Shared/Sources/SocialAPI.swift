import Foundation

/// Campus leagues, coach teams and the parent summary link
/// (backend/src/routes/leagues.js, teams.js, parent.js).
public extension APIClient {
    struct LeagueTable: Decodable, Sendable, Equatable {
        public struct Member: Decodable, Sendable, Equatable {
            public let nickname: String
            public let xp: Int
            public let isMe: Bool
        }
        public struct League: Decodable, Sendable, Equatable, Identifiable {
            public let id: String
            public let name: String
            public let code: String
            public let members: [Member]
        }
        public let week: String
        public let leagues: [League]
    }

    struct Teams: Decodable, Sendable, Equatable {
        public struct Coached: Decodable, Sendable, Equatable, Identifiable {
            public let id: String
            public let name: String
            public let code: String
            /// The athletic trainer's code, when the coach made one.
            public let trainerCode: String?
            public let memberCount: Int
        }
        public struct Joined: Decodable, Sendable, Equatable, Identifiable {
            public let id: String
            public let name: String
            public let nickname: String
            /// Pain reports and training pauses shared with this team.
            public let shareHealth: Bool?
        }
        /// A team I'm the athletic trainer of.
        public struct Staffed: Decodable, Sendable, Equatable, Identifiable {
            public let id: String
            public let name: String
        }
        public let coaching: [Coached]
        public let member: [Joined]
        public let trainer: [Staffed]?
    }

    /// Pain and training pauses of a member who shares them (never a diagnosis).
    struct HealthStatus: Decodable, Sendable, Equatable {
        public struct Pain: Decodable, Sendable, Equatable {
            public let day: String
            public let areas: [String]
            public let level: String?
        }
        public let memberId: String?
        public let nickname: String
        public let paused: Bool
        public let pausedSince: String?
        public let pain: Pain?
        public let painDays: Int
        /// The last return-to-play step the trainer recorded (1–6).
        public let rtpStep: Int?
        public let rtpRecordedAt: String?
    }

    struct RtpEntry: Decodable, Sendable, Equatable {
        public let step: Int
        public let note: String?
        public let teamName: String?
        public let recordedAt: String
    }

    /// This phone can get push notifications (re-sent when the switches change).
    func registerPushDevice(token: String, muted: [String], sessionToken: String) async throws {
        struct Body: Encodable, Sendable { let token: String; let muted: [String] }
        let _: Ignored = try await social("PUT", "push/device", json: try JSONEncoder().encode(Body(token: token, muted: muted)), sessionToken: sessionToken)
    }

    func removePushDevice(token: String, sessionToken: String) async throws {
        struct Body: Encodable, Sendable { let token: String }
        let _: Ignored = try await social("DELETE", "push/device", json: try JSONEncoder().encode(Body(token: token)), sessionToken: sessionToken)
    }

    func recordRtp(teamID: String, memberId: String, step: Int, note: String?, sessionToken: String) async throws {
        struct Body: Encodable, Sendable { let memberId: String; let step: Int; let note: String? }
        let _: Ignored = try await social("POST", "teams/\(teamID)/rtp", json: try JSONEncoder().encode(Body(memberId: memberId, step: step, note: note)), sessionToken: sessionToken)
    }

    struct WebLoginInfo: Decodable, Sendable, Equatable {
        public let status: String
        public let device: String?
        public let createdAt: String
    }

    func webLoginInfo(id: String, sessionToken: String) async throws -> WebLoginInfo {
        try await social("GET", "web-login/\(id)/info", sessionToken: sessionToken)
    }

    func approveWebLogin(id: String, approve: Bool, sessionToken: String) async throws {
        let _: Ignored = try await social("POST", "web-login/\(id)/\(approve ? "approve" : "deny")", sessionToken: sessionToken)
    }

    func myRtp(sessionToken: String) async throws -> [RtpEntry] {
        struct Wire: Decodable, Sendable { let entries: [RtpEntry] }
        let wire: Wire = try await social("GET", "teams/rtp/mine", sessionToken: sessionToken)
        return wire.entries
    }

    struct TeamHealth: Decodable, Sendable, Equatable {
        public let role: String
        public let members: [HealthStatus]
    }

    struct Announcement: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let teamId: String
        public let teamName: String?
        public let text: String
        public let createdAt: String
    }

    struct TeamReadiness: Decodable, Sendable, Equatable {
        public struct Member: Decodable, Sendable, Equatable {
            public let memberId: String?
            public let nickname: String
            public let checkedInToday: Bool
            public let readiness: String?
            public let checkInsThisWeek: Int
            public let sessionsThisWeek: Int
            public let minutesThisWeek: Int
            /// The last 14 days, oldest first: GREEN, AMBER, RED, NONE or nil (no check-in).
            public let trend: [String?]?
            public let missedThisWeek: Int?
            public let sharesHealth: Bool?
            public let health: HealthStatus?
        }
        public let members: [Member]
    }

    struct Assignment: Codable, Sendable, Equatable, Identifiable {
        public struct Item: Codable, Sendable, Equatable {
            public let itemSlug: String
            public let sets: Int
            public let reps: Int?
            public let seconds: Int?

            public init(itemSlug: String, sets: Int, reps: Int?, seconds: Int?) {
                self.itemSlug = itemSlug
                self.sets = sets
                self.reps = reps
                self.seconds = seconds
            }
        }
        public let id: String
        public let teamId: String
        public let teamName: String?
        /// YYYY-MM-DD
        public let date: String
        public let title: String
        public let note: String?
        public let items: [Item]
    }

    // MARK: Leagues

    func leagues(week: String, sessionToken: String) async throws -> LeagueTable {
        try await social("GET", "leagues", query: [URLQueryItem(name: "week", value: week)], sessionToken: sessionToken)
    }

    func createLeague(name: String, nickname: String, sessionToken: String) async throws {
        let _: Ignored = try await social("POST", "leagues", body: ["name": name, "nickname": nickname], sessionToken: sessionToken)
    }

    func joinLeague(code: String, nickname: String, sessionToken: String) async throws {
        let _: Ignored = try await social("POST", "leagues/join", body: ["code": code, "nickname": nickname], sessionToken: sessionToken)
    }

    func leaveLeague(id: String, sessionToken: String) async throws {
        let _: Ignored = try await social("DELETE", "leagues/\(id)", sessionToken: sessionToken)
    }

    func reportWeeklyXP(week: String, xp: Int, sessionToken: String) async throws {
        struct Body: Encodable, Sendable { let week: String; let xp: Int }
        let _: Ignored = try await social("PUT", "leagues/xp", json: try JSONEncoder().encode(Body(week: week, xp: xp)), sessionToken: sessionToken)
    }

    // MARK: Teams

    func teams(sessionToken: String) async throws -> Teams {
        try await social("GET", "teams", sessionToken: sessionToken)
    }

    func createTeam(name: String, sessionToken: String) async throws {
        let _: Ignored = try await social("POST", "teams", body: ["name": name], sessionToken: sessionToken)
    }

    func joinTeam(code: String, nickname: String, sessionToken: String) async throws {
        let _: Ignored = try await social("POST", "teams/join", body: ["code": code, "nickname": nickname], sessionToken: sessionToken)
    }

    /// Leave a team as an athlete (never deletes it — not even for its coach).
    func leaveTeam(id: String, sessionToken: String) async throws {
        let _: Ignored = try await social("DELETE", "teams/\(id)/membership", sessionToken: sessionToken)
    }

    /// The coach deletes the team; a member leaves it.
    func deleteOrLeaveTeam(id: String, sessionToken: String) async throws {
        let _: Ignored = try await social("DELETE", "teams/\(id)", sessionToken: sessionToken)
    }

    func teamReadiness(teamID: String, today: String, weekStart: String, sessionToken: String) async throws -> TeamReadiness {
        try await social("GET", "teams/\(teamID)/readiness", query: [
            URLQueryItem(name: "today", value: today), URLQueryItem(name: "weekStart", value: weekStart),
        ], sessionToken: sessionToken)
    }

    func teamAssignments(teamID: String, from: String, sessionToken: String) async throws -> [Assignment] {
        struct Wire: Decodable, Sendable { let assignments: [Assignment] }
        let wire: Wire = try await social("GET", "teams/\(teamID)/assignments", query: [URLQueryItem(name: "from", value: from)], sessionToken: sessionToken)
        return wire.assignments
    }

    func assignWorkout(teamID: String, date: String, title: String, note: String?, items: [Assignment.Item], sessionToken: String) async throws {
        struct Body: Encodable, Sendable { let date: String; let title: String; let note: String?; let items: [Assignment.Item] }
        let body = try JSONEncoder().encode(Body(date: date, title: title, note: note, items: items))
        let _: Ignored = try await social("POST", "teams/\(teamID)/assignments", json: body, sessionToken: sessionToken)
    }

    func deleteAssignment(teamID: String, id: String, sessionToken: String) async throws {
        let _: Ignored = try await social("DELETE", "teams/\(teamID)/assignments/\(id)", sessionToken: sessionToken)
    }

    /// Workouts assigned to me by every coach whose team I'm on.
    func myAssignments(from: String, sessionToken: String) async throws -> [Assignment] {
        struct Wire: Decodable, Sendable { let assignments: [Assignment] }
        let wire: Wire = try await social("GET", "teams/assignments", query: [URLQueryItem(name: "from", value: from)], sessionToken: sessionToken)
        return wire.assignments
    }

    // MARK: Health sharing, athletic trainers, announcements

    func setShareHealth(teamID: String, share: Bool, sessionToken: String) async throws {
        struct Body: Encodable, Sendable { let shareHealth: Bool }
        let _: Ignored = try await social("PATCH", "teams/\(teamID)/membership", json: try JSONEncoder().encode(Body(shareHealth: share)), sessionToken: sessionToken)
    }

    /// Kept by the server only while the athlete shares health with a team.
    func postHealthNote(day: String, kind: String, areas: [String], level: String?, sessionToken: String) async throws {
        struct Body: Encodable, Sendable { let day: String; let kind: String; let areas: [String]; let level: String? }
        let body = try JSONEncoder().encode(Body(day: day, kind: kind, areas: areas, level: level))
        let _: Ignored = try await social("POST", "teams/health", json: body, sessionToken: sessionToken)
    }

    func teamHealth(teamID: String, sessionToken: String) async throws -> TeamHealth {
        try await social("GET", "teams/\(teamID)/health", sessionToken: sessionToken)
    }

    func makeTrainerCode(teamID: String, sessionToken: String) async throws -> String {
        struct Wire: Decodable, Sendable { let trainerCode: String }
        let wire: Wire = try await social("POST", "teams/\(teamID)/trainer-code", sessionToken: sessionToken)
        return wire.trainerCode
    }

    func deleteTrainerCode(teamID: String, sessionToken: String) async throws {
        let _: Ignored = try await social("DELETE", "teams/\(teamID)/trainer-code", sessionToken: sessionToken)
    }

    func joinAsTrainer(code: String, sessionToken: String) async throws {
        let _: Ignored = try await social("POST", "teams/join-staff", body: ["code": code], sessionToken: sessionToken)
    }

    func postAnnouncement(teamID: String, text: String, sessionToken: String) async throws {
        let _: Ignored = try await social("POST", "teams/\(teamID)/announcements", body: ["text": text], sessionToken: sessionToken)
    }

    func deleteAnnouncement(teamID: String, id: String, sessionToken: String) async throws {
        let _: Ignored = try await social("DELETE", "teams/\(teamID)/announcements/\(id)", sessionToken: sessionToken)
    }

    func teamAnnouncements(teamID: String, sessionToken: String) async throws -> [Announcement] {
        struct Wire: Decodable, Sendable { let announcements: [Announcement] }
        let wire: Wire = try await social("GET", "teams/\(teamID)/announcements", sessionToken: sessionToken)
        return wire.announcements
    }

    /// From every team I'm on, the last 14 days.
    func myAnnouncements(sessionToken: String) async throws -> [Announcement] {
        struct Wire: Decodable, Sendable { let announcements: [Announcement] }
        let wire: Wire = try await social("GET", "teams/announcements", sessionToken: sessionToken)
        return wire.announcements
    }

    // MARK: Shout-outs (private coach notes)

    func sendShoutout(teamID: String, memberId: String, text: String, sessionToken: String) async throws {
        let _: Ignored = try await social("POST", "teams/\(teamID)/shoutouts", body: ["memberId": memberId, "text": text], sessionToken: sessionToken)
    }

    func myShoutouts(sessionToken: String) async throws -> [Announcement] {
        struct Wire: Decodable, Sendable {
            struct Row: Decodable, Sendable { let id: String; let teamName: String?; let text: String; let createdAt: String }
            let shoutouts: [Row]
        }
        let wire: Wire = try await social("GET", "teams/shoutouts", sessionToken: sessionToken)
        return wire.shoutouts.map { Announcement(id: $0.id, teamId: "", teamName: $0.teamName, text: $0.text, createdAt: $0.createdAt) }
    }

    // MARK: Training together

    struct PartnerSession: Decodable, Sendable, Equatable {
        public struct Person: Decodable, Sendable, Equatable {
            public let nickname: String
            public let done: Int
            public let total: Int
            public let finished: Bool
            public let isMe: Bool
        }
        public let code: String
        public let title: String
        public let items: [Assignment.Item]
        public let people: [Person]
    }

    func startPartnerSession(title: String, items: [Assignment.Item], nickname: String, sessionToken: String) async throws -> String {
        struct Body: Encodable, Sendable { let title: String; let items: [Assignment.Item]; let nickname: String }
        struct Wire: Decodable, Sendable { let code: String }
        let wire: Wire = try await social("POST", "partner", json: try JSONEncoder().encode(Body(title: title, items: items, nickname: nickname)), sessionToken: sessionToken)
        return wire.code
    }

    func joinPartnerSession(code: String, nickname: String, sessionToken: String) async throws -> PartnerSession {
        try await social("POST", "partner/\(code)/join", body: ["nickname": nickname], sessionToken: sessionToken)
    }

    func partnerSession(code: String, sessionToken: String) async throws -> PartnerSession {
        try await social("GET", "partner/\(code)", sessionToken: sessionToken)
    }

    func reportPartnerProgress(code: String, done: Int, total: Int, finished: Bool, sessionToken: String) async throws {
        struct Body: Encodable, Sendable { let done: Int; let total: Int; let finished: Bool }
        let _: Ignored = try await social("PUT", "partner/\(code)/progress", json: try JSONEncoder().encode(Body(done: done, total: total, finished: finished)), sessionToken: sessionToken)
    }

    // MARK: Parent email

    struct ParentEmail: Decodable, Sendable, Equatable {
        public let email: String
        public let confirmed: Bool
    }

    func parentEmail(sessionToken: String) async throws -> ParentEmail? {
        do {
            let wire: ParentEmail = try await social("GET", "parent-email", sessionToken: sessionToken)
            return wire
        } catch APIError.http(status: 404, _) {
            return nil
        }
    }

    func setParentEmail(_ email: String, sessionToken: String) async throws -> ParentEmail {
        try await social("POST", "parent-email", body: ["email": email], sessionToken: sessionToken)
    }

    func deleteParentEmail(sessionToken: String) async throws {
        let _: Ignored = try await social("DELETE", "parent-email", sessionToken: sessionToken)
    }

    // MARK: Parent summary link

    /// The current link, or nil when there is none.
    func parentLink(sessionToken: String) async throws -> URL? {
        struct Wire: Decodable, Sendable { let url: String }
        do {
            let wire: Wire = try await social("GET", "parent-link", sessionToken: sessionToken)
            return URL(string: wire.url)
        } catch APIError.http(status: 404, _) {
            return nil
        }
    }

    /// A new link (the old one stops working).
    func makeParentLink(sessionToken: String) async throws -> URL? {
        struct Wire: Decodable, Sendable { let url: String }
        let wire: Wire = try await social("POST", "parent-link", sessionToken: sessionToken)
        return URL(string: wire.url)
    }

    func deleteParentLink(sessionToken: String) async throws {
        let _: Ignored = try await social("DELETE", "parent-link", sessionToken: sessionToken)
    }

    // MARK: Shared workouts and codes

    /// A workout shared under a code (backend/src/routes/workouts.js).
    struct SharedWorkout: Codable, Sendable, Equatable {
        public struct Item: Codable, Sendable, Equatable {
            public let itemSlug: String
            public let dose: Dose
            public let restSec: Int
        }
        public let code: String
        public let title: String
        public let items: [Item]
        public let sportSlug: String?

        /// A copy the athlete owns.
        public var workout: CustomWorkout {
            CustomWorkout(title: title, items: items.map { CustomItem(itemSlug: $0.itemSlug, dose: $0.dose, restSec: $0.restSec) })
        }
    }

    /// Shares a workout (Pro) and returns its code.
    func shareWorkout(_ workout: CustomWorkout, sportSlug: String?, sessionToken: String) async throws -> String {
        struct Body: Encodable, Sendable { let title: String; let items: [SharedWorkout.Item]; let sportSlug: String? }
        struct Wire: Decodable, Sendable { let code: String }
        let body = Body(title: workout.title, items: workout.items.map { SharedWorkout.Item(itemSlug: $0.itemSlug, dose: $0.dose, restSec: $0.restSec) },
                        sportSlug: sportSlug)
        let wire: Wire = try await social("POST", "workouts/shared", json: try JSONEncoder().encode(body), sessionToken: sessionToken)
        return wire.code
    }

    /// Anyone with the code can open it — no account needed.
    func sharedWorkout(code: String) async throws -> SharedWorkout {
        try await open("workouts/shared/\(code)")
    }

    func stopSharing(code: String, sessionToken: String) async throws {
        let _: Ignored = try await social("DELETE", "workouts/shared/\(code)", sessionToken: sessionToken)
    }

    /// What a code is — "team", "league" or "workout" — and its name.
    struct CodeInfo: Decodable, Sendable, Equatable {
        public let kind: String
        public let name: String?
    }

    func lookUpCode(_ code: String) async throws -> CodeInfo {
        try await open("codes/\(code)")
    }

    // MARK: Reporting (guideline 1.2)

    /// Reports a shared workout ("workout", its code), a league member
    /// ("leagueMember", "leagueId:nickname"), a league or a team (their id).
    func report(kind: String, target: String, reason: String? = nil, sessionToken: String?) async throws {
        struct Body: Encodable, Sendable { let kind: String; let target: String; let reason: String? }
        var request = URLRequest(url: baseURL.appending(path: "reports"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let sessionToken { request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(Body(kind: kind, target: target, reason: reason))
        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw apiError(from: response, data: data)
        }
    }

    // MARK: Plumbing

    /// A request that needs no sign-in.
    private func open<T: Decodable & Sendable>(_ path: String) async throws -> T {
        let (data, response) = try await perform(URLRequest(url: baseURL.appending(path: path)))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw apiError(from: response, data: data)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    /// A response whose body doesn't matter.
    struct Ignored: Decodable, Sendable {}

    private func social<T: Decodable & Sendable>(_ method: String, _ path: String, query: [URLQueryItem] = [],
                                                 body: [String: String]? = nil, sessionToken: String) async throws -> T {
        try await social(method, path, query: query, json: try body.map { try JSONEncoder().encode($0) }, sessionToken: sessionToken)
    }

    private func social<T: Decodable & Sendable>(_ method: String, _ path: String, query: [URLQueryItem] = [],
                                                 json: Data?, sessionToken: String) async throws -> T {
        var url = baseURL.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = json
        }
        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw apiError(from: response, data: data)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data.isEmpty ? Data("{}".utf8) : data)
        } catch {
            throw APIError.decoding
        }
    }
}
