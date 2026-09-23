import XCTest

final class ReadinessEngineTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let referenceNow = Date(timeIntervalSince1970: 1_760_000_000) // fixed, so tests never depend on "today"

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: referenceNow)!
    }

    func testFewerThanSevenDaysOfHistoryProducesNoBandAtAll() {
        // §11: "before that, the app shows the raw answers... rather than
        // inventing a score from nothing." 6 days is one short of the
        // 7-day minimum, even though every one of them is a rough day.
        let history = (1...6).map {
            CheckInAnswers(date: day(-$0), sleepQuality: 1, soreness: 5, energy: 1, stress: 5)
        }
        let today = CheckInAnswers(date: day(0), sleepQuality: 1, soreness: 5, energy: 1, stress: 5)
        let result = ReadinessEngine.score(today: today, history: history, now: referenceNow, calendar: calendar)
        XCTAssertNil(result)
    }

    func testHistoryOlderThanTwentyEightDaysDoesNotCountTowardsTheMinimum() {
        let staleHistory = (30...40).map {
            CheckInAnswers(date: day(-$0), sleepQuality: 4, soreness: 2, energy: 4, stress: 2)
        }
        let today = CheckInAnswers(date: day(0), sleepQuality: 1, soreness: 5, energy: 1, stress: 5)
        let result = ReadinessEngine.score(today: today, history: staleHistory, now: referenceNow, calendar: calendar)
        XCTAssertNil(result, "11 days of history all sit outside the trailing 28-day window, so none of it should count")
    }

    /// §21's acceptance test, named directly in the build plan: "The
    /// athlete who always sleeps six hours must not read red every day —
    /// this is the test that proves baselines are personal." A history
    /// with zero variance on every metric means there is nothing to
    /// detect a deviation FROM, so a day that matches it exactly must
    /// never read red — a population norm would flag this athlete's
    /// habitual low score every single morning; a personal baseline must not.
    func testAnAthleteAtTheirOwnConsistentNormalIsNeverFlaggedRed() {
        let history = (1...10).map { i in
            CheckInAnswers(date: day(-i), sleepQuality: 2, soreness: 3, energy: 3, stress: 3)
        }
        let today = CheckInAnswers(date: day(0), sleepQuality: 2, soreness: 3, energy: 3, stress: 3)
        let result = ReadinessEngine.score(today: today, history: history, now: referenceNow, calendar: calendar)
        XCTAssertEqual(result?.band, .green)
        XCTAssertEqual(result?.z, 0)
    }

    func testASharpDropAcrossEveryMetricReadsRed() {
        // mean 3.5/std 0.5 for sleep+energy, mean 2.5/std 0.5 for
        // soreness+stress — today is 5 standard deviations worse on all
        // four, a clear, unambiguous bad day.
        let history = (0..<10).map { i -> CheckInAnswers in
            let high = i.isMultiple(of: 2)
            return CheckInAnswers(
                date: day(-(i + 1)), sleepQuality: high ? 4 : 3, soreness: high ? 3 : 2,
                energy: high ? 4 : 3, stress: high ? 3 : 2
            )
        }
        let today = CheckInAnswers(date: day(0), sleepQuality: 1, soreness: 5, energy: 1, stress: 5)
        let result = ReadinessEngine.score(today: today, history: history, now: referenceNow, calendar: calendar)
        XCTAssertEqual(result?.band, .red)
        XCTAssertEqual(result?.z ?? 0, -5, accuracy: 0.001)
    }

    func testAMildDipOnSomeMetricsReadsAmberNotRed() {
        // Sleep and energy have real spread (mean 3, std 1); soreness and
        // stress are perfectly consistent (std 0, so their z is always 0
        // regardless of today). Today matches baseline on soreness/stress
        // but comes in one full standard deviation low on sleep/energy —
        // a real but partial dip, not the across-the-board crash above.
        let history = (0..<10).map { i -> CheckInAnswers in
            let low = i.isMultiple(of: 2)
            return CheckInAnswers(
                date: day(-(i + 1)), sleepQuality: low ? 2 : 4, soreness: 3,
                energy: low ? 2 : 4, stress: 3
            )
        }
        let today = CheckInAnswers(date: day(0), sleepQuality: 2, soreness: 3, energy: 2, stress: 3)
        let result = ReadinessEngine.score(today: today, history: history, now: referenceNow, calendar: calendar)
        XCTAssertEqual(result?.band, .amber)
        XCTAssertEqual(result?.z ?? 0, -0.5, accuracy: 0.001)
    }

    func testAGoodDayReadsGreen() {
        let history = (1...10).map { i in
            CheckInAnswers(date: day(-i), sleepQuality: 3, soreness: 3, energy: 3, stress: 3)
        }
        let today = CheckInAnswers(date: day(0), sleepQuality: 4, soreness: 2, energy: 4, stress: 2)
        let result = ReadinessEngine.score(today: today, history: history, now: referenceNow, calendar: calendar)
        // Zero variance in this history means every z-score collapses to
        // 0 regardless of today's answers (see the "consistent normal"
        // test above) — this asserts that degenerate case never
        // misfires as anything worse than green.
        XCTAssertEqual(result?.band, .green)
    }
}
