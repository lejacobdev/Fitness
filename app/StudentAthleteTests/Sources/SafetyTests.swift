import XCTest

/// The low-energy warning and the concussion day status.
final class SafetyTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 9))! }
    private func day(_ back: Int) -> Date { calendar.date(byAdding: .day, value: -back, to: calendar.startOfDay(for: now))! }

    override func tearDown() {
        DayStatusStore.set(.active, days: nil)
        super.tearDown()
    }

    func testConstantFatigueWithHeavyTrainingWarns() {
        let energies = (0..<8).map { (date: day($0), energy: $0 < 6 ? 2 : 4) }
        let training = Set((0..<14).filter { $0 % 3 != 0 }.map(day))
        XCTAssertEqual(LowEnergyCheck.evaluate(energies: energies, trainingDays: training, now: now, calendar: calendar),
                       LowEnergyWarning(lowDays: 6, checkIns: 8, trainingDays: 9))
        XCTAssertNil(LowEnergyCheck.evaluate(energies: energies, trainingDays: Set((0..<5).map(day)), now: now, calendar: calendar),
                     "tired but not training much: not this warning")
        let someTired = (0..<10).map { (date: day($0), energy: $0 < 4 ? 2 : 4) }
        XCTAssertNil(LowEnergyCheck.evaluate(energies: someTired, trainingDays: training, now: now, calendar: calendar))
    }

    func testAHeadKnockPausesTrainingUntilChanged() {
        DayStatusStore.set(.concussion, days: nil)
        XCTAssertFalse(DayStatus.concussion.trainsAsPlanned)
        XCTAssertEqual(DayStatusStore.status(on: calendar.date(byAdding: .day, value: 20, to: .now)!), .concussion)
        XCTAssertEqual(ConcussionGuide.steps.count, 6)
        XCTAssertTrue(ConcussionGuide.steps[4].title.contains("doctor"), "contact only after a doctor clears you")
    }
}
