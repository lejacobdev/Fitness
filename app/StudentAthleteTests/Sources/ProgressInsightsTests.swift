import XCTest

/// Progress → Last 30 days: the numbers and neutral patterns (never causes).
final class ProgressInsightsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 12))! }
    private func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: now)! }

    func testCountsOnlyTheLastThirtyDays() {
        let result = ProgressInsights.lastThirtyDays(
            sessions: [(daysAgo(1), 40), (daysAgo(3), 30), (daysAgo(45), 50)],
            practiceDays: [DayKey.of(daysAgo(2), calendar: calendar), DayKey.of(daysAgo(60), calendar: calendar)],
            checkIns: [], needsWork: [], now: now, calendar: calendar
        )
        XCTAssertEqual(result.workouts, 2)
        XCTAssertEqual(result.minutes, 70)
        XCTAssertEqual(result.practices, 1)
        XCTAssertEqual(result.trainingDays, 3)
        XCTAssertNil(result.averageSleep)
        XCTAssertEqual(result.insights.first, "You trained on 3 of the last 30 days.")
    }

    func testSleepAndEnergyPatternNeedsEnoughMorningsAndStaysNeutral() {
        let points = (0..<10).map { n in
            ProgressInsights.CheckInPoint(date: daysAgo(n), sleepHours: n % 2 == 0 ? 8.5 : 6.5, energy: n % 2 == 0 ? 5 : 3, soreness: 2)
        }
        let result = ProgressInsights.lastThirtyDays(sessions: [], practiceDays: [], checkIns: points, needsWork: [["Speed"], ["Speed", "Focus"]],
                                                     now: now, calendar: calendar)
        XCTAssertEqual(result.averageSleep ?? 0, 7.5, accuracy: 0.01)
        XCTAssertTrue(result.insights.contains("On mornings after 8+ hours of sleep, your energy was higher on average."))
        XCTAssertTrue(result.insights.contains("“Speed” came up most often in what needs work (2 times)."))
        XCTAssertFalse(result.insights.contains { $0.contains("because") || $0.contains("causes") }, "patterns, never causes")

        let few = ProgressInsights.lastThirtyDays(sessions: [], practiceDays: [], checkIns: Array(points.prefix(4)), needsWork: [],
                                                  now: now, calendar: calendar)
        XCTAssertTrue(few.insights.isEmpty, "two mornings on a side is too few to say anything")
    }
}
