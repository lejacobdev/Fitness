import XCTest

/// Watch and band workouts: effort from heart rate, a lighter day after a
/// hard one, and practice logged from the watch.
final class WearableLoadTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 22))! }
    private func at(_ hour: Double, minutes: Int, heartRate: Double?, activity: String = "Run") -> ExternalWorkout {
        let start = day.addingTimeInterval(hour * 3600)
        return ExternalWorkout(start: start, end: start.addingTimeInterval(Double(minutes) * 60), activity: activity, averageHeartRate: heartRate)
    }

    func testEffortFollowsHeartRateAgainstAgePredictedMax() {
        // 16 years old: max ≈ 196.8
        XCTAssertEqual(WearableLoad.effort(averageHeartRate: 110, minutes: 40, age: 16), 3)
        XCTAssertEqual(WearableLoad.effort(averageHeartRate: 160, minutes: 40, age: 16), 7)
        XCTAssertEqual(WearableLoad.effort(averageHeartRate: 185, minutes: 40, age: 16), 9)
        XCTAssertEqual(WearableLoad.effort(averageHeartRate: nil, minutes: 70, age: 16), 6)
    }

    func testAHardMorningRunMakesTheDayLighterButPracticeDoesNot() {
        let now = day.addingTimeInterval(16 * 3600)
        let run = at(7, minutes: 45, heartRate: 165)
        XCTAssertNotNil(WearableLoad.reason([run], now: now, age: 16, practiceToday: nil, calendar: calendar))
        XCTAssertNil(WearableLoad.reason([at(7, minutes: 20, heartRate: 110)], now: now, age: 16, practiceToday: nil, calendar: calendar), "an easy jog")
        let practice = PracticeTime(start: 15 * 60, end: 17 * 60)
        let atPractice = at(15, minutes: 90, heartRate: 170, activity: "Soccer")
        XCTAssertNil(WearableLoad.reason([atPractice], now: day.addingTimeInterval(18 * 3600), age: 16, practiceToday: practice, calendar: calendar),
                     "practice itself isn't extra load")
    }

    func testAWatchWorkoutAtPracticeTimeIsLoggedAsPractice() {
        let practice = PracticeTime(start: 15 * 60, end: 17 * 60)
        let log = WearableLoad.practiceLog(from: [at(14.75, minutes: 100, heartRate: 150, activity: "Soccer")], practice: practice,
                                           day: day, sportSlug: "soccer", age: 16, calendar: calendar)
        XCTAssertEqual(log?.minutes, 100)
        XCTAssertEqual(log?.day, "2026-09-22")
        XCTAssertEqual(log?.note, "From your watch")
        XCTAssertNil(WearableLoad.practiceLog(from: [at(9, minutes: 60, heartRate: 150)], practice: practice, day: day,
                                              sportSlug: "soccer", age: 16, calendar: calendar), "a morning run isn't practice")
    }

    func testHeartRateSummary() {
        XCTAssertNil(HeartRateSummary([]))
        XCTAssertEqual(HeartRateSummary([120, 140, 160]), HeartRateSummary(average: 140, max: 160))
    }
}
