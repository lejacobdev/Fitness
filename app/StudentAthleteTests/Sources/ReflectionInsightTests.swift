import XCTest
#if canImport(Engine)
@testable import Engine
#endif

/// V6 §19: after the reflection, one small true thing back — or nothing.
final class ReflectionInsightTests: XCTestCase {
    private func r(_ day: String, hardness: Int? = nil, body: Int? = nil, practice: Int? = nil, wentWell: [String] = [], needsWork: [String] = []) -> Reflection {
        Reflection(day: day, win: "", lesson: "", feeling: nil, hardness: hardness, body: body, practice: practice,
                   wentWell: wentWell, needsWork: needsWork, learned: nil)
    }

    func testAnOrdinaryDayGivesNothingBack() {
        XCTAssertNil(ReflectionInsight.make(today: r("2026-10-02", hardness: 2, body: 1, practice: 3), recent: [], practiceToday: true))
    }

    func testAHarderThanUsualPracticeSaysTheSessionChanged() {
        let week = (1...4).map { r("2026-09-2\($0)", hardness: 2) }
        let insight = ReflectionInsight.make(today: r("2026-10-02", hardness: 4), recent: week, practiceToday: true)
        XCTAssertEqual(insight?.key, "hard")
        XCTAssertTrue(insight?.text.contains("adjusted") ?? false)
    }

    func testSomethingHurtComesFirst() {
        XCTAssertEqual(ReflectionInsight.make(today: r("2026-10-02", hardness: 4, body: 4), recent: [], practiceToday: true)?.key, "hurt")
    }

    func testARepeatedStrengthIsNoticed() {
        let week = [r("2026-09-30", wentWell: ["Focus"]), r("2026-10-01", wentWell: ["Focus"])]
        let insight = ReflectionInsight.make(today: r("2026-10-02", wentWell: ["Focus"]), recent: week, practiceToday: false)
        XCTAssertEqual(insight?.key, "well-Focus")
    }

    func testTheSameInsightIsNotShownTwiceInARow() {
        let week = (1...4).map { r("2026-09-2\($0)", hardness: 2) }
        XCTAssertNil(ReflectionInsight.make(today: r("2026-10-02", hardness: 4), recent: week, practiceToday: true, lastShown: "hard"))
    }

    func testAVeryHardEveningLightensTomorrow() {
        let demands = SportDemandsTable.demands(sport: nil, position: nil)
        let day = TrainingDay(date: .now, phase: .offSeason, age: 16, experience: .intermediate, demands: demands,
                              reflection: ReflectionSignal(dayFelt: 4, bodyFelt: 3))
        let decision = SessionPlanner.decide(day)
        XCTAssertTrue(decision.reasons.contains(.reflectionVeryHard))
        XCTAssertTrue(decision.reasons.contains(.belowNormalReadiness))
        XCTAssertLessThan(decision.durationTarget, 65)
    }
}
