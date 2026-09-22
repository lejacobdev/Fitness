import SwiftData
import XCTest

final class AthleteModelsTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        ModelContext(try AthleteStore.makeContainer(inMemory: true))
    }

    /// Cascade rules here are supposed to mirror schema.prisma's `onDelete`
    /// exactly (AthleteModels.swift's own doc comment says so) — this is the
    /// on-device half of that guarantee, proven rather than assumed.
    func testDeletingAthleteCascadesToItsCheckIns() throws {
        let context = try makeContext()

        let athlete = Athlete(appleUserId: "sub-cascade", birthDate: .now)
        context.insert(athlete)
        context.insert(CheckIn(date: .now, sleepQuality: 4, soreness: 2, energy: 3, stress: 2, athlete: athlete))
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CheckIn>()), 1)

        context.delete(athlete)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CheckIn>()), 0)
    }

    /// The one deliberate exception to "everything cascades": a logged
    /// Session survives its PlannedSession being deleted or regenerated,
    /// just losing the link (`.nullify`, matching Postgres's `SetNull`).
    func testSessionSurvivesItsPlannedSessionBeingDeleted() throws {
        let context = try makeContext()

        let athlete = Athlete(appleUserId: "sub-nullify", birthDate: .now)
        context.insert(athlete)
        let plan = Plan(weekStart: .now, phase: "build", seed: "seed-1", athlete: athlete)
        context.insert(plan)
        let plannedSession = PlannedSession(date: .now, title: "Leg day", estimatedMinutes: 45, plan: plan)
        context.insert(plannedSession)
        let session = Session(startedAt: .now, source: .phone, athlete: athlete, plannedSession: plannedSession)
        context.insert(session)
        try context.save()

        context.delete(plannedSession)
        try context.save()

        let survivors = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(survivors.count, 1)
        XCTAssertNil(survivors.first?.plannedSession)
    }

    /// §14: DownloadedPack is device-local only. Nothing here asserts that —
    /// there is no sync path to assert it against yet — but the round trip
    /// through the same container every other model uses is exactly what
    /// `PackDownloader`'s `DownloadedPackRecorder` depends on at runtime.
    func testDownloadedPackRoundTripsThroughTheStore() throws {
        let context = try makeContext()
        context.insert(DownloadedPack(packSlug: "core", version: 3))
        try context.save()

        let stored = try context.fetch(FetchDescriptor<DownloadedPack>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.packSlug, "core")
        XCTAssertEqual(stored.first?.version, 3)
    }
}
