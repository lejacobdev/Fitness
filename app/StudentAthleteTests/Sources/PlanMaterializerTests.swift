import SwiftData
import XCTest

/// `PlanMaterializer` is `@MainActor` (see SessionLoggerTests/SyncQueueTests
/// for why this whole case needs the same annotation).
@MainActor
final class PlanMaterializerTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        ModelContext(try AthleteStore.makeContainer(inMemory: true))
    }

    func testMaterializingAGeneratedWeekWritesTheFullRelationalGraph() throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-plan", birthDate: .now)
        context.insert(athlete)

        let week = GeneratedWeek(
            phase: .offSeason,
            weekStart: Date(timeIntervalSince1970: 1_700_000_000),
            sessions: [
                GeneratedSession(
                    date: Date(timeIntervalSince1970: 1_700_000_000),
                    title: "Acceleration session", focusQualities: ["acceleration"],
                    estimatedMinutes: 12,
                    items: [
                        GeneratedPlannedItem(
                            itemSlug: "accel-drill", order: 0,
                            dose: Dose(kind: "reps", sets: 3, reps: 8), restSec: 60,
                            rationale: "This is here because your sport rewards acceleration.",
                            quality: "acceleration"
                        ),
                    ]
                ),
            ]
        )

        let plan = try PlanMaterializer(modelContext: context).materialize(week, athlete: athlete, seed: "seed-xyz")

        XCTAssertEqual(plan.phase, "OFF_SEASON")
        XCTAssertEqual(plan.seed, "seed-xyz")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Plan>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlannedSession>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlannedItem>()), 1)

        let storedSession = try context.fetch(FetchDescriptor<PlannedSession>()).first
        XCTAssertEqual(storedSession?.title, "Acceleration session")
        XCTAssertEqual(storedSession?.items.first?.itemSlug, "accel-drill")
        XCTAssertEqual(storedSession?.items.first?.dose.sets, 3)
    }

    func testDeletingAMaterializedPlanCascadesToItsSessionsAndItems() throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-plan-2", birthDate: .now)
        context.insert(athlete)

        let week = GeneratedWeek(
            phase: .inSeason, weekStart: .now,
            sessions: [
                GeneratedSession(
                    date: .now, title: "Session", focusQualities: [], estimatedMinutes: 10,
                    items: [GeneratedPlannedItem(itemSlug: "x", order: 0, dose: Dose(kind: "reps", sets: 1, reps: 5), restSec: 30, rationale: "r", quality: "acceleration")]
                ),
            ]
        )
        let plan = try PlanMaterializer(modelContext: context).materialize(week, athlete: athlete, seed: "s")

        context.delete(plan)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlannedSession>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlannedItem>()), 0)
    }
}
