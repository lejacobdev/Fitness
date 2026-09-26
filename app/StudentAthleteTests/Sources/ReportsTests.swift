import XCTest

/// The season report, the PDF and the recruiting profile's numbers.
final class ReportsTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private func day(_ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: d, hour: 16))! }

    func testTheReportCountsTheSeasonOnly() {
        let jump = BenchmarkCatalog.jump
        let input = AthleteReport.Input(
            name: "Sam", sport: "Soccer", position: "Midfielder", age: 16,
            sessionDates: [day(2), day(3), day(4), day(20)], sessionMinutes: [30, 40, 50, 60],
            exerciseNames: ["Split squat", "Split squat", "Plank"], practiceDays: ["2026-09-05", "2026-08-01"],
            checkInDates: [day(2), day(3), day(4), day(5)], sleepHours: [7, 8], lessons: 4,
            results: [BenchmarkResult(testID: jump.id, value: 40, date: day(2)), BenchmarkResult(testID: jump.id, value: 44, date: day(18))],
            tests: [jump]
        )
        let report = AthleteReport.make(input, from: day(1), to: day(19), calendar: calendar)
        XCTAssertEqual(report.workouts, 3)
        XCTAssertEqual(report.minutes, 120)
        XCTAssertEqual(report.practices, 1)
        XCTAssertEqual(report.checkIns, 4)
        XCTAssertEqual(report.longestStreak, 4)
        XCTAssertEqual(report.averageSleep ?? 0, 7.5, accuracy: 0.01)
        XCTAssertEqual(report.topExercise, "Split squat")
        XCTAssertEqual(report.tests.first?.best, "44 cm")
        XCTAssertEqual(report.tests.first?.change, "4 cm higher")
    }
}
