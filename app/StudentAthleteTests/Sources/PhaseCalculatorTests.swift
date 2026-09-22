import XCTest

final class PhaseCalculatorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testWithinTheSeasonWindowIsInSeason() {
        let phase = PhaseCalculator.phase(
            today: date(2026, 10, 15), seasonStart: date(2026, 9, 1), seasonEnd: date(2026, 11, 30),
            calendar: calendar
        )
        XCTAssertEqual(phase, .inSeason)
    }

    func testExactlyOnSeasonStartAndEndAreBothInSeason() {
        XCTAssertEqual(
            PhaseCalculator.phase(today: date(2026, 9, 1), seasonStart: date(2026, 9, 1), seasonEnd: date(2026, 11, 30), calendar: calendar),
            .inSeason
        )
        XCTAssertEqual(
            PhaseCalculator.phase(today: date(2026, 11, 30), seasonStart: date(2026, 9, 1), seasonEnd: date(2026, 11, 30), calendar: calendar),
            .inSeason
        )
    }

    func testSixWeeksBeforeSeasonStartIsPreSeason() {
        let phase = PhaseCalculator.phase(
            today: date(2026, 7, 21), seasonStart: date(2026, 9, 1), seasonEnd: date(2026, 11, 30),
            calendar: calendar
        )
        XCTAssertEqual(phase, .preSeason)
    }

    func testTwelveWeeksBeforeSeasonStartIsOffSeason() {
        let phase = PhaseCalculator.phase(
            today: date(2026, 6, 9), seasonStart: date(2026, 9, 1), seasonEnd: date(2026, 11, 30),
            calendar: calendar
        )
        XCTAssertEqual(phase, .offSeason)
    }

    func testThreeWeeksAfterSeasonEndIsPostSeason() {
        let phase = PhaseCalculator.phase(
            today: date(2026, 12, 21), seasonStart: date(2026, 9, 1), seasonEnd: date(2026, 11, 30),
            calendar: calendar
        )
        XCTAssertEqual(phase, .postSeason)
    }

    func testEightWeeksAfterSeasonEndIsOffSeason() {
        let phase = PhaseCalculator.phase(
            today: date(2027, 1, 25), seasonStart: date(2026, 9, 1), seasonEnd: date(2026, 11, 30),
            calendar: calendar
        )
        XCTAssertEqual(phase, .offSeason)
    }
}
