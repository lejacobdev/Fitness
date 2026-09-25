import XCTest

/// Benchmark tests every 6–8 weeks: the maths, the schedule and the
/// improvement shown on Home.
final class BenchmarkTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "benchmark.results")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "benchmark.results")
        super.tearDown()
    }

    private func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 10))!
    }

    func testJumpHeightFromFlightTime() {
        // 0.5 s in the air ≈ 30.7 cm (h = g·t²/8).
        XCTAssertEqual(BenchmarkMath.jumpHeightCentimeters(flightTime: 0.5), 30.66, accuracy: 0.01)
    }

    func testTheBestTryOfTheDayIsKeptAndChangesAreSaidPlainly() {
        BenchmarkStore.record(30, for: BenchmarkCatalog.jump, on: day(8, 1), calendar: calendar)
        BenchmarkStore.record(28, for: BenchmarkCatalog.jump, on: day(8, 1), calendar: calendar)
        XCTAssertEqual(BenchmarkStore.results.map(\.value), [30])
        BenchmarkStore.record(33, for: BenchmarkCatalog.jump, on: day(9, 20), calendar: calendar)
        BenchmarkStore.record(4.60, for: BenchmarkCatalog.sprint30, on: day(8, 1), calendar: calendar)
        BenchmarkStore.record(4.40, for: BenchmarkCatalog.sprint30, on: day(9, 20), calendar: calendar)

        let results = BenchmarkStore.results
        let sprint = BenchmarkMath.change(results, test: BenchmarkCatalog.sprint30)
        XCTAssertEqual(sprint?.improved, true, "lower is better for a sprint")
        XCTAssertEqual(BenchmarkCatalog.sprint30.unit.formatChange(-0.2, higherIsBetter: false), "0.20 s faster")
        XCTAssertEqual(BenchmarkMath.headline(results, tests: BenchmarkCatalog.body), "Vertical jump: 3 cm higher")
    }

    func testTestsAreDueAfterSixWeeksAndOverdueAfterEight() {
        XCTAssertEqual(BenchmarkSchedule.status(lastTest: nil), .firstTime)
        XCTAssertEqual(BenchmarkSchedule.status(lastTest: day(8, 1), now: day(8, 11), calendar: calendar), .notYet(daysLeft: 32))
        XCTAssertEqual(BenchmarkSchedule.status(lastTest: day(8, 1), now: day(9, 13), calendar: calendar), .due)
        XCTAssertEqual(BenchmarkSchedule.status(lastTest: day(8, 1), now: day(9, 30), calendar: calendar), .overdue)
    }

    func testEveryFeaturedSportHasItsOwnTest() {
        let featured = allSports.filter { $0.featured == true }.map(\.slug)
        XCTAssertFalse(featured.isEmpty)
        for slug in featured {
            let test = BenchmarkCatalog.sportTest(for: slug)
            XCTAssertEqual(test.id, "sport.\(slug)")
            XCTAssertFalse(test.howTo.isEmpty, "\(slug) explains how to do its test")
        }
        XCTAssertEqual(BenchmarkCatalog.tests(for: "soccer").count, BenchmarkCatalog.body.count + 1)
    }

    func testTypedResultsAreRead() {
        XCTAssertEqual(BenchmarkRunView.parse("6:12", unit: .seconds), 372)
        XCTAssertEqual(BenchmarkRunView.parse("4,52", unit: .seconds), 4.52)
        XCTAssertNil(BenchmarkRunView.parse("11", unit: .outOf10))
        XCTAssertNil(BenchmarkRunView.parse("abc", unit: .centimeters))
    }
}
