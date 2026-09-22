import SwiftData
import XCTest

/// `SessionLogger` is `@MainActor` — calling its isolated init/methods needs
/// this whole case isolated too, same fix and same root cause as
/// SyncQueueTests (see its own doc comment): a plain synchronous test method
/// is a "nonisolated context" just as much as an async one is, contrary to
/// what the first version of this fix assumed.
@MainActor
final class SessionLoggerTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        ModelContext(try AthleteStore.makeContainer(inMemory: true))
    }

    /// M5: "Start a session, log sets and drills, finish, RPE, history" —
    /// and per §3, every one of those steps is a plain local SwiftData
    /// write, so none of it needs a network stub to prove: it's instant and
    /// offline by construction, not by a special code path.
    func testFullSessionLifecycleIsPersistedLocally() throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-1", birthDate: .now)
        context.insert(athlete)
        let logger = SessionLogger(modelContext: context)

        let session = try logger.startSession(athlete: athlete)
        XCTAssertNil(session.endedAt)
        XCTAssertNil(session.syncedAt)
        XCTAssertEqual(session.source, .phone)

        try logger.logSet(session: session, itemSlug: "trap-bar-deadlift", setIndex: 0, reps: 6, weightKg: 60)
        try logger.logSet(session: session, itemSlug: "trap-bar-deadlift", setIndex: 1, reps: 6, weightKg: 62.5)

        XCTAssertEqual(session.sets.count, 2)
        XCTAssertEqual(session.sets.map(\.itemSlug), ["trap-bar-deadlift", "trap-bar-deadlift"])

        try logger.finishSession(session, sessionRPE: 7)
        XCTAssertEqual(session.sessionRPE, 7)
        XCTAssertNotNil(session.endedAt)
        XCTAssertGreaterThanOrEqual(session.minutes, 0)

        let stored = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.sets.count, 2)
    }

    func testMinutesAreDerivedFromElapsedWallClockTime() throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-2", birthDate: .now)
        context.insert(athlete)
        let logger = SessionLogger(modelContext: context)

        // A session that "started" 30 minutes ago, finished now.
        let session = Session(startedAt: Date.now.addingTimeInterval(-30 * 60), source: .phone, athlete: athlete)
        context.insert(session)
        try context.save()

        try logger.finishSession(session, sessionRPE: 5)

        XCTAssertEqual(session.minutes, 30)
    }

    func testDeletingASessionCascadesToItsSets() throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-3", birthDate: .now)
        context.insert(athlete)
        let logger = SessionLogger(modelContext: context)

        let session = try logger.startSession(athlete: athlete)
        try logger.logSet(session: session, itemSlug: "acceleration-wall-drill", setIndex: 0, seconds: 20)

        context.delete(session)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SetLog>()), 0)
    }
}
