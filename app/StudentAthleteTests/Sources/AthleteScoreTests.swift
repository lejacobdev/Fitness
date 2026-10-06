import XCTest
#if canImport(Engine)
@testable import Engine
#endif

final class AthleteScoreTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 18))! }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!.addingTimeInterval(17 * 3600)
    }

    /// Four weeks: workouts on 3 days a week, a check-in most mornings.
    private func steadyMonth(rpe: Int = 6, minutes: Int = 60, skipEvery: Int = 0, recentRPE: Int? = nil) -> AthleteScoreInput {
        var activities: [AthleteScoreInput.Activity] = []
        var checkIns: [AthleteScoreInput.Wellness] = []
        var feelings: [AthleteScoreInput.Feeling] = []
        var index = 0
        for offset in 0..<28 {
            if offset % 7 == 0 || offset % 7 == 2 || offset % 7 == 4 {
                index += 1
                if skipEvery > 0, index % skipEvery == 0 { continue }
                activities.append(.init(date: day(offset), minutes: minutes, rpe: offset < 7 ? (recentRPE ?? rpe) : rpe))
            }
            if offset % 2 == 0 {
                checkIns.append(.init(date: day(offset), sleep: 4, energy: 4, soreness: 2, stress: 2))
                feelings.append(.init(date: day(offset), day: 4, practice: nil, learned: offset % 4 == 0))
            }
        }
        return AthleteScoreInput(now: now, activities: activities, practices: [], checkIns: checkIns, feelings: feelings,
                                 plannedPerWeek: 3, developmentChanges: [0.04, 0.01])
    }

    func testNewAthleteIsStillLearning() {
        let input = AthleteScoreInput(now: now, activities: [.init(date: day(2), minutes: 45, rpe: 6)], practices: [],
                                      checkIns: [.init(date: day(1), sleep: 4, energy: 4, soreness: 2, stress: 2)],
                                      feelings: [], plannedPerWeek: 3)
        let score = AthleteScoreEngine.score(input, calendar: calendar)
        XCTAssertNil(score.value)
        XCTAssertNotNil(score.learning)
        XCTAssertTrue(score.learning!.detail.contains("5 more sessions"))
        XCTAssertLessThan(score.learning!.progress, 1)
    }

    func testSteadyMonthScoresWell() {
        let score = AthleteScoreEngine.score(steadyMonth(), calendar: calendar)
        XCTAssertNotNil(score.value)
        XCTAssertGreaterThanOrEqual(score.value!, 75)
        XCTAssertEqual(score.components.first { $0.part == .consistency }?.value, 100)
    }

    func testMissedSessionsLowerConsistency() {
        let full = AthleteScoreEngine.score(steadyMonth(), calendar: calendar)
        let patchy = AthleteScoreEngine.score(steadyMonth(skipEvery: 2), calendar: calendar)
        XCTAssertLessThan(patchy.value!, full.value!)
        XCTAssertLessThan(patchy.components.first { $0.part == .consistency }!.value!, 70)
    }

    func testSickDaysNeverCountAgainst() {
        var input = steadyMonth()
        // Sick for the last week: no sessions, the days are paused.
        input.activities.removeAll { $0.date >= day(6) }
        input.pausedDays = Set((0..<7).map { calendar.startOfDay(for: day($0)) })
        let score = AthleteScoreEngine.score(input, calendar: calendar)
        XCTAssertGreaterThanOrEqual(score.components.first { $0.part == .consistency }!.value!, 95)
    }

    func testLoadSpikeSaysEaseOff() {
        let score = AthleteScoreEngine.score(steadyMonth(rpe: 4, recentRPE: 10), calendar: calendar)
        XCTAssertEqual(score.direction, .easeOff)
        XCTAssertGreaterThan(score.loadRatio!, 1.3)
    }

    func testEasyWeekWithGoodRecoveryCanPushMore() {
        var input = steadyMonth(rpe: 7, recentRPE: 2)
        input.developmentChanges = [0.05]
        let score = AthleteScoreEngine.score(input, calendar: calendar)
        XCTAssertLessThan(score.loadRatio!, 0.8)
        XCTAssertEqual(score.direction, .pushMore)
    }

    func testSmallChangesAreNoise() {
        XCTAssertEqual(AthleteScoreEngine.developmentPart([0.01, -0.02]).value, 65)
        XCTAssertEqual(AthleteScoreEngine.developmentPart([0.05]).value, 100)
    }

    func testScoreMovesSlowly() {
        XCTAssertEqual(AthleteScoreEngine.smoothed(90, lastWeek: 60), 68)
        XCTAssertEqual(AthleteScoreEngine.smoothed(30, lastWeek: 60), 52)
        XCTAssertEqual(AthleteScoreEngine.smoothed(63, lastWeek: 60), 63)
        XCTAssertEqual(AthleteScoreEngine.smoothed(63, lastWeek: nil), 63)
    }

    func testTrendAgainstAMonthAgo() {
        let history = [(week: day(35), value: 55), (week: day(28), value: 58), (week: day(7), value: 64)]
        XCTAssertEqual(AthleteScoreEngine.trend(current: 66, history: history, now: now, calendar: calendar), .up)
        XCTAssertEqual(AthleteScoreEngine.trend(current: 59, history: history, now: now, calendar: calendar), .steady)
        XCTAssertEqual(AthleteScoreEngine.trend(current: 50, history: history, now: now, calendar: calendar), .down)
        XCTAssertEqual(AthleteScoreEngine.trend(current: 50, history: [], now: now, calendar: calendar), .steady)
    }

    func testWordsAreCalm() {
        XCTAssertEqual(AthleteScore.word(for: 20), "Finding rhythm")
        XCTAssertEqual(AthleteScore.word(for: 85), "Strong phase")
    }
}
