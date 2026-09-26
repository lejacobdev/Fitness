import SwiftData
import XCTest

/// The whole daily loop with no connection: check in, get today's plan and
/// workout, log it — everything works on the phone, and what couldn't be
/// uploaded waits for the next time there's signal.
@MainActor
final class OfflineLoopTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    private func item(_ slug: String, _ quality: String) -> CatalogueItem {
        CatalogueItem(
            slug: slug, name: slug, kind: "exercise", qualities: [quality: 1], muscles: [:],
            equipment: [], surface: "anywhere", minAge: 13, supervisionLevel: "SELF",
            setup: [], execution: [], cues: [], mistakes: [], progressions: [], regressions: [], substitutes: [],
            defaultDose: Dose(kind: "reps", sets: 3, reps: 8), restSeconds: 60, startPose: "hinge", endPose: "hinge",
            unilateralEligible: nil, tempoEligible: nil, prop: nil, variant: nil, baseSlug: nil,
            constraintAxes: nil, equipmentChain: nil, unilateralPosePattern: nil, unilateralStabilityQuality: nil,
            itemSportSlug: nil
        )
    }

    func testTheDailyLoopWorksWithNoConnection() async throws {
        let context = ModelContext(try AthleteStore.makeContainer(inMemory: true))
        let athlete = Athlete(appleUserId: "sub-offline", birthDate: Calendar.current.date(byAdding: .year, value: -16, to: .now)!)
        context.insert(athlete)

        // PREPARE: the check-in and today's readiness.
        let checkIn = try CheckInStore(modelContext: context).submit(athlete: athlete, sleepQuality: 4, soreness: 2, energy: 4, stress: 2)
        let readiness = DailyLoop.readiness(
            answers: MorningAnswers(sleepQuality: 4, sleepHours: 8, energy: 4, soreness: 2, stress: 2),
            personalBand: nil, pain: nil, yesterday: nil
        )
        XCTAssertEqual(readiness?.level, .normal)

        // The plan and a workout, from what's on the phone.
        let items = [item("split-squat", "lower-body-strength"), item("push-up", "upper-body-push"), item("dead-bug", "trunk-anti-rotation")]
        let catalogue = Catalogue(itemsBySlug: Dictionary(uniqueKeysWithValues: items.map { ($0.slug, $0) }))
        let week = PlanGenerator.generate(PlanGeneratorInput(
            sportProfile: ["lower-body-strength": 1], seasonStart: .now.addingTimeInterval(90 * 86_400),
            seasonEnd: .now.addingTimeInterval(180 * 86_400), weekStart: .now, birthDate: athlete.birthDate,
            catalogue: catalogue, seed: "offline"
        ))
        XCTAssertFalse(week.sessions.flatMap(\.items).isEmpty)

        // PERFORM: log it.
        let logger = SessionLogger(modelContext: context)
        let session = try logger.startSession(athlete: athlete)
        try logger.logSet(session: session, itemSlug: "split-squat", setIndex: 0, reps: 8, weightKg: 20)
        try logger.finishSession(session, sessionRPE: 6)

        // No signal: nothing is lost, everything waits.
        StubURLProtocol.handler = nil
        let queue = SyncQueue(apiClient: APIClient(baseURL: URL(string: "https://example.invalid")!, session: StubURLProtocol.makeSession()),
                              tokenStore: InMemoryTokenStore(token: "tok"), modelContext: context)
        let sessions = await queue.drainPendingSessions()
        XCTAssertEqual(sessions.succeeded, 0)
        XCTAssertNil(session.syncedAt, "still waiting to upload")
        XCTAssertNil(checkIn.syncedAt)
        XCTAssertEqual(athlete.sessions.count, 1)
        XCTAssertEqual(athlete.checkIns.count, 1)
    }
}
