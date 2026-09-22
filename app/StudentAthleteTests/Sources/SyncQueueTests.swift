import SwiftData
import XCTest

/// `SyncQueue` is `@MainActor` (it shares a `ModelContext` with SwiftUI's
/// own MainActor-confined access — see SyncQueue.swift's doc comment), so
/// constructing it from a plain `async throws` test method fails actor
/// isolation checking under `SWIFT_STRICT_CONCURRENCY = complete` even
/// though the equivalent synchronous-context calls elsewhere in this test
/// target were tolerated. Marking the whole case `@MainActor` is the
/// standard fix for testing MainActor-isolated code with XCTest.
@MainActor
final class SyncQueueTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try AthleteStore.makeContainer(inMemory: true))
    }

    private func makeClient() -> APIClient {
        APIClient(baseURL: URL(string: "https://example.invalid")!, session: StubURLProtocol.makeSession())
    }

    private func makeAthleteAndPendingSession(in context: ModelContext) throws -> Session {
        let athlete = Athlete(appleUserId: "sub-sync", birthDate: .now)
        context.insert(athlete)
        let logger = SessionLogger(modelContext: context)
        let session = try logger.startSession(athlete: athlete)
        try logger.logSet(session: session, itemSlug: "trap-bar-deadlift", setIndex: 0, reps: 6, weightKg: 60)
        try logger.finishSession(session, sessionRPE: 6)
        return session
    }

    func testWithNoStoredTokenDrainIsANoOpAndNeverTouchesTheNetwork() async throws {
        let context = try makeContext()
        _ = try makeAthleteAndPendingSession(in: context)
        StubURLProtocol.handler = { _ in XCTFail("should never reach the network with no token"); throw URLError(.badURL) }

        let queue = SyncQueue(apiClient: makeClient(), tokenStore: InMemoryTokenStore(token: nil), modelContext: context)
        let result = await queue.drainPendingSessions()

        XCTAssertEqual(result.succeeded, 0)
        XCTAssertEqual(result.failed, 0)
    }

    func testAPendingSessionIsSyncedAndMarkedWithSyncedAt() async throws {
        let context = try makeContext()
        let session = try makeAthleteAndPendingSession(in: context)
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let queue = SyncQueue(apiClient: makeClient(), tokenStore: InMemoryTokenStore(token: "tok"), modelContext: context)
        let result = await queue.drainPendingSessions()

        XCTAssertEqual(result.succeeded, 1)
        XCTAssertEqual(result.failed, 0)
        XCTAssertNotNil(session.syncedAt)
    }

    /// §21's sync idempotency test, client side: once a session is marked
    /// synced, a second drain call must not even attempt to re-send it.
    func testASecondDrainDoesNotRetouchAnAlreadySyncedSession() async throws {
        let context = try makeContext()
        _ = try makeAthleteAndPendingSession(in: context)
        var requestCount = 0
        StubURLProtocol.handler = { request in
            requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let queue = SyncQueue(apiClient: makeClient(), tokenStore: InMemoryTokenStore(token: "tok"), modelContext: context)
        let first = await queue.drainPendingSessions()
        let second = await queue.drainPendingSessions()

        XCTAssertEqual(first.succeeded, 1)
        XCTAssertEqual(second.succeeded, 0)
        XCTAssertEqual(second.failed, 0)
        XCTAssertEqual(requestCount, 1, "the second drain should never have posted the network request again")
    }

    func testAFailedSyncLeavesTheSessionPendingForTheNextRetryRatherThanLosingIt() async throws {
        let context = try makeContext()
        let session = try makeAthleteAndPendingSession(in: context)
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }

        let queue = SyncQueue(apiClient: makeClient(), tokenStore: InMemoryTokenStore(token: "tok"), modelContext: context)
        let result = await queue.drainPendingSessions()

        XCTAssertEqual(result.succeeded, 0)
        XCTAssertEqual(result.failed, 1)
        XCTAssertNil(session.syncedAt, "a failed push must leave syncedAt nil so the next drain retries it")

        let stillPending = try context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.syncedAt == nil }))
        XCTAssertEqual(stillPending.count, 1)
    }

    func testAlreadySyncedSessionsAreNeverIncludedInTheDrainAtAll() async throws {
        let context = try makeContext()
        let session = try makeAthleteAndPendingSession(in: context)
        session.syncedAt = .now
        try context.save()
        StubURLProtocol.handler = { _ in XCTFail("an already-synced session should never be re-posted"); throw URLError(.badURL) }

        let queue = SyncQueue(apiClient: makeClient(), tokenStore: InMemoryTokenStore(token: "tok"), modelContext: context)
        let result = await queue.drainPendingSessions()

        XCTAssertEqual(result.succeeded, 0)
        XCTAssertEqual(result.failed, 0)
    }
}
