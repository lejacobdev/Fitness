import XCTest

final class AgeGateTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testTurningThirteenTodayIsEligible() {
        let now = date(2026, 9, 22)
        let birthDate = date(2013, 9, 22)
        XCTAssertEqual(AgeGate.evaluate(birthDate: birthDate, now: now, calendar: calendar), .eligible)
    }

    func testOneDayShortOfThirteenIsUnderMinimum() {
        let now = date(2026, 9, 21)
        let birthDate = date(2013, 9, 22)
        XCTAssertEqual(AgeGate.evaluate(birthDate: birthDate, now: now, calendar: calendar), .underMinimum)
    }

    func testWellUnderThirteenIsUnderMinimum() {
        let now = date(2026, 9, 22)
        let birthDate = date(2020, 1, 1)
        XCTAssertEqual(AgeGate.evaluate(birthDate: birthDate, now: now, calendar: calendar), .underMinimum)
    }

    func testEighteenYearOldIsEligible() {
        let now = date(2026, 9, 22)
        let birthDate = date(2008, 3, 15)
        XCTAssertEqual(AgeGate.evaluate(birthDate: birthDate, now: now, calendar: calendar), .eligible)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
