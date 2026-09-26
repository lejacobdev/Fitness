import XCTest

/// Sunday's weekly review.
final class WeeklyReviewTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func input(sessions: Int, checkIns: Int, bests: [String] = [], games: Int = 0, deload: Bool = false) -> (WeeklyReview.Input, Date) {
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 10))!
        let days = (0..<7).map { calendar.date(byAdding: .day, value: -$0, to: sunday)! }
        let old = calendar.date(byAdding: .day, value: -20, to: sunday)!
        return (WeeklyReview.Input(
            sessionDates: Array(days.prefix(sessions)) + [old], sessionMinutes: Array(repeating: 40, count: sessions) + [90],
            checkInDates: Array(days.prefix(checkIns)), lessonsThisWeek: 2, newBests: bests, streak: checkIns,
            gamesNextWeek: games, deloadNextWeek: deload, phase: .inSeason, goal: nil
        ), sunday)
    }

    func testCountsOnlyThisWeek() {
        let (data, now) = input(sessions: 3, checkIns: 5)
        let review = WeeklyReview.make(data, now: now, calendar: calendar)
        XCTAssertEqual(review.workouts, 3)
        XCTAssertEqual(review.minutes, 120)
        XCTAssertEqual(review.checkIns, 5)
    }

    func testThePersonalBestIsTheHighlightAndNextWeekLooksAhead() {
        let (data, now) = input(sessions: 1, checkIns: 7, bests: ["Vertical jump 48 cm"], games: 2)
        let review = WeeklyReview.make(data, now: now, calendar: calendar)
        XCTAssertTrue(review.highlight.contains("48 cm"))
        XCTAssertTrue(review.focus.contains("2 games"))
        let (deload, _) = input(sessions: 3, checkIns: 7, deload: true)
        XCTAssertTrue(WeeklyReview.make(deload, now: now, calendar: calendar).focus.contains("deload"))
    }

    func testAQuietWeekIsSaidKindly() {
        let (data, now) = input(sessions: 0, checkIns: 2)
        let review = WeeklyReview.make(data, now: now, calendar: calendar)
        XCTAssertTrue(review.highlight.contains("Rest is part of the plan"))
        XCTAssertTrue(review.focus.contains("Check in"))
    }
}
