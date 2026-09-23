import XCTest

final class TaperCalculatorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testNoCompetitionsIsAlwaysNormal() {
        let stage = TaperCalculator.stage(for: date(2026, 10, 1), competitions: [], calendar: calendar)
        XCTAssertEqual(stage, .normal)
    }

    func testFourDaysOutIsStillNormal() {
        let stage = TaperCalculator.stage(
            for: date(2026, 10, 1), competitions: [date(2026, 10, 5)], calendar: calendar
        )
        XCTAssertEqual(stage, .normal)
    }

    func testThreeDaysOutIsLastHeavySession() {
        let stage = TaperCalculator.stage(
            for: date(2026, 10, 2), competitions: [date(2026, 10, 5)], calendar: calendar
        )
        XCTAssertEqual(stage, .lastHeavySession)
    }

    func testTwoDaysOutIsQualityOverQuantity() {
        let stage = TaperCalculator.stage(
            for: date(2026, 10, 3), competitions: [date(2026, 10, 5)], calendar: calendar
        )
        XCTAssertEqual(stage, .qualityOverQuantity)
    }

    func testOneDayOutIsPrimer() {
        let stage = TaperCalculator.stage(
            for: date(2026, 10, 4), competitions: [date(2026, 10, 5)], calendar: calendar
        )
        XCTAssertEqual(stage, .primer)
    }

    func testTheCompetitionDateItselfIsGameDay() {
        let stage = TaperCalculator.stage(
            for: date(2026, 10, 5), competitions: [date(2026, 10, 5)], calendar: calendar
        )
        XCTAssertEqual(stage, .gameDay)
    }

    func testOneDayAfterIsPostGameRecovery() {
        let stage = TaperCalculator.stage(
            for: date(2026, 10, 6), competitions: [date(2026, 10, 5)], calendar: calendar
        )
        XCTAssertEqual(stage, .postGameRecovery)
    }

    func testTwoDaysAfterWithNothingElseUpcomingIsNormal() {
        let stage = TaperCalculator.stage(
            for: date(2026, 10, 7), competitions: [date(2026, 10, 5)], calendar: calendar
        )
        XCTAssertEqual(stage, .normal)
    }

    /// §10: "Two games in a week: the block between them collapses to
    /// primer-and-recover." Games on Oct 5 and Oct 8 -- Oct 6 (one day after
    /// the first) is also two days before the second.
    func testTwoGamesInAWeekCollapsesTheBlockBetweenThem() {
        let competitions = [date(2026, 10, 5), date(2026, 10, 8)]
        let stage = TaperCalculator.stage(for: date(2026, 10, 6), competitions: competitions, calendar: calendar)
        XCTAssertEqual(stage, .betweenGames)
    }

    func testBothGameDaysAreStillRecognisedInATwoGameWeek() {
        let competitions = [date(2026, 10, 5), date(2026, 10, 8)]
        XCTAssertEqual(TaperCalculator.stage(for: date(2026, 10, 5), competitions: competitions, calendar: calendar), .gameDay)
        XCTAssertEqual(TaperCalculator.stage(for: date(2026, 10, 8), competitions: competitions, calendar: calendar), .gameDay)
    }

    /// A day far enough before the SECOND game, and far enough after the
    /// first, that neither taper window applies.
    func testADayFarFromBothGamesInAMultiGameSeasonIsNormal() {
        let competitions = [date(2026, 10, 5), date(2026, 10, 20)]
        let stage = TaperCalculator.stage(for: date(2026, 10, 12), competitions: competitions, calendar: calendar)
        XCTAssertEqual(stage, .normal)
    }

    func testCompetitionsNeedNotBeSortedInput() {
        let competitions = [date(2026, 10, 20), date(2026, 10, 5)]
        let stage = TaperCalculator.stage(for: date(2026, 10, 4), competitions: competitions, calendar: calendar)
        XCTAssertEqual(stage, .primer)
    }
}
