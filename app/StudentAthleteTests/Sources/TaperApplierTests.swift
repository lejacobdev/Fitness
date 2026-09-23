import XCTest

final class TaperApplierTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func item(
        slug: String, quality: String, order: Int = 0, sets: Int = 4, restSec: Int = 60
    ) -> GeneratedPlannedItem {
        GeneratedPlannedItem(
            itemSlug: slug, order: order, dose: Dose(kind: "reps", sets: sets, reps: 8),
            restSec: restSec, rationale: "r", quality: quality
        )
    }

    private func session(date d: Date, items: [GeneratedPlannedItem]) -> GeneratedSession {
        GeneratedSession(
            date: d, title: "Session", focusQualities: items.map(\.quality),
            estimatedMinutes: items.reduce(0) { $0 + PlanGenerator.estimatedMinutes(dose: $1.dose, restSec: $1.restSec) },
            items: items
        )
    }

    func testAWeekWithNoCompetitionsIsCompletelyUnchanged() {
        let week = GeneratedWeek(phase: .offSeason, weekStart: date(2026, 10, 1), sessions: [
            session(date: date(2026, 10, 1), items: [item(slug: "a", quality: "acceleration")]),
        ])
        let tapered = TaperApplier.apply(to: week, competitions: [], contactLevel: "NONE", calendar: calendar)
        XCTAssertEqual(tapered, week)
    }

    func testGameDayIsDroppedEntirely() {
        let gameDate = date(2026, 10, 5)
        let week = GeneratedWeek(phase: .inSeason, weekStart: date(2026, 10, 5), sessions: [
            session(date: gameDate, items: [item(slug: "a", quality: "acceleration")]),
        ])
        let tapered = TaperApplier.apply(to: week, competitions: [gameDate], contactLevel: "NONE", calendar: calendar)
        XCTAssertTrue(tapered.sessions.isEmpty)
    }

    func testThreeDaysOutKeepsIntensityButReducesVolume() {
        let items = [
            item(slug: "a", quality: "acceleration", order: 0, sets: 4),
            item(slug: "b", quality: "lower-body-strength", order: 1, sets: 4),
            item(slug: "c", quality: "aerobic-base", order: 2, sets: 4),
        ]
        let day = date(2026, 10, 2)
        let week = GeneratedWeek(phase: .inSeason, weekStart: day, sessions: [session(date: day, items: items)])

        let tapered = TaperApplier.apply(to: week, competitions: [date(2026, 10, 5)], contactLevel: "NONE", calendar: calendar)

        let resultItems = tapered.sessions.first?.items ?? []
        XCTAssertEqual(resultItems.count, 2, "expected volume capped to 2 items")
        XCTAssertEqual(resultItems.map(\.dose.sets), [2, 2], "sets halved, intensity (reps) untouched")
        XCTAssertEqual(resultItems.map(\.dose.reps), [8, 8])
    }

    func testTwoDaysOutExcludesStrengthWork() {
        let items = [
            item(slug: "strength-only", quality: "lower-body-strength"),
        ]
        let day = date(2026, 10, 3)
        let week = GeneratedWeek(phase: .inSeason, weekStart: day, sessions: [session(date: day, items: items)])

        let tapered = TaperApplier.apply(to: week, competitions: [date(2026, 10, 5)], contactLevel: "NONE", calendar: calendar)

        // Falls back to the original item rather than an empty session,
        // since excluding strength here would otherwise leave nothing.
        XCTAssertEqual(tapered.sessions.first?.items.map(\.itemSlug), ["strength-only"])
    }

    func testTwoDaysOutPrefersNonStrengthWhenAvailable() {
        let items = [
            item(slug: "strength-item", quality: "lower-body-strength", order: 0),
            item(slug: "speed-item", quality: "acceleration", order: 1),
        ]
        let day = date(2026, 10, 3)
        let week = GeneratedWeek(phase: .inSeason, weekStart: day, sessions: [session(date: day, items: items)])

        let tapered = TaperApplier.apply(to: week, competitions: [date(2026, 10, 5)], contactLevel: "NONE", calendar: calendar)

        let slugs = tapered.sessions.first?.items.map(\.itemSlug) ?? []
        XCTAssertFalse(slugs.contains("strength-item"))
        XCTAssertTrue(slugs.contains("speed-item"))
    }

    func testOneDayOutIsAMinimalPrimerPreferringSpeedOrPower() {
        let items = [
            item(slug: "strength-item", quality: "lower-body-strength", order: 0, sets: 4),
            item(slug: "power-item", quality: "vertical-power", order: 1, sets: 4),
        ]
        let day = date(2026, 10, 4)
        let week = GeneratedWeek(phase: .inSeason, weekStart: day, sessions: [session(date: day, items: items)])

        let tapered = TaperApplier.apply(to: week, competitions: [date(2026, 10, 5)], contactLevel: "NONE", calendar: calendar)

        let resultItems = tapered.sessions.first?.items ?? []
        XCTAssertEqual(resultItems.map(\.itemSlug), ["power-item"])
        XCTAssertEqual(resultItems.first?.dose.sets, 2)
        XCTAssertEqual(tapered.sessions.first?.title, "Primer — not a hard session, game tomorrow")
    }

    func testPostGameRecoveryIsMinimalForACollisionSportButUnchangedForANonContactOne() {
        let items = [item(slug: "a", quality: "hip-mobility", order: 0, sets: 4)]
        let day = date(2026, 10, 6)
        let week = GeneratedWeek(phase: .inSeason, weekStart: day, sessions: [session(date: day, items: items)])

        let collision = TaperApplier.apply(to: week, competitions: [date(2026, 10, 5)], contactLevel: "COLLISION", calendar: calendar)
        XCTAssertEqual(collision.sessions.first?.items.first?.dose.sets, 2)
        XCTAssertEqual(collision.sessions.first?.title, "Easy recovery day")

        let none = TaperApplier.apply(to: week, competitions: [date(2026, 10, 5)], contactLevel: "NONE", calendar: calendar)
        XCTAssertEqual(none.sessions.first?.items.first?.dose.sets, 4, "a non-contact sport should not be forced to back off")
    }

    /// §10: "Two games in a week: the block between them collapses to
    /// primer-and-recover... the app says so plainly."
    func testTwoGamesInAWeekProducesAnExplicitlyLabelledCollapsedSession() {
        let items = [item(slug: "a", quality: "acceleration", order: 0, sets: 4)]
        let day = date(2026, 10, 6)
        let week = GeneratedWeek(phase: .inSeason, weekStart: day, sessions: [session(date: day, items: items)])

        let tapered = TaperApplier.apply(
            to: week, competitions: [date(2026, 10, 5), date(2026, 10, 8)], contactLevel: "NONE", calendar: calendar
        )

        XCTAssertEqual(tapered.sessions.first?.title, "Recovery and primer — two games this week")
        XCTAssertEqual(tapered.sessions.first?.items.first?.dose.sets, 2)
    }

    func testItemOrderIsReindexedContiguouslyAfterCapping() {
        let items = [
            item(slug: "a", quality: "acceleration", order: 0, sets: 4),
            item(slug: "b", quality: "vertical-power", order: 1, sets: 4),
            item(slug: "c", quality: "lower-body-strength", order: 2, sets: 4),
        ]
        let day = date(2026, 10, 2)
        let week = GeneratedWeek(phase: .inSeason, weekStart: day, sessions: [session(date: day, items: items)])

        let tapered = TaperApplier.apply(to: week, competitions: [date(2026, 10, 5)], contactLevel: "NONE", calendar: calendar)

        XCTAssertEqual(tapered.sessions.first?.items.map(\.order), [0, 1])
    }
}
