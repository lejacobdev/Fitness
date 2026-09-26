import XCTest

/// V3's daily loop: the morning answers, pain, today's readiness in words,
/// the one-sentence reason for the plan, the evening reflection feeding
/// tomorrow, and a practice confirmed in the check-in.
final class DailyLoopTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let keys = ["safety.pain", "mindset.reflections", "schedule.dayOverrides"]

    override func setUp() {
        super.setUp()
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    private var morning: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 7))! }

    private func answers(sleep: Int = 4, hours: Double? = 8, energy: Int = 4, soreness: Int = 2, stress: Int = 2) -> MorningAnswers {
        MorningAnswers(sleepQuality: sleep, sleepHours: hours, energy: energy, soreness: soreness, stress: stress)
    }

    func testFeelingGoodIsANormalDay() {
        let result = DailyLoop.readiness(answers: answers(), personalBand: nil, pain: nil, yesterday: nil)
        XCTAssertEqual(result?.level, .normal)
        XCTAssertNil(DailyLoop.readiness(answers: nil, personalBand: nil, pain: nil, yesterday: nil), "nothing known yet")
    }

    func testOneWarningSignLightensTheDayTwoMakeItARecoveryDay() {
        XCTAssertEqual(DailyLoop.readiness(answers: answers(hours: 5.5), personalBand: nil, pain: nil, yesterday: nil)?.level, .reduced)
        XCTAssertEqual(DailyLoop.readiness(answers: answers(soreness: 5), personalBand: nil, pain: nil, yesterday: nil)?.level, .reduced)
        XCTAssertEqual(DailyLoop.readiness(answers: answers(hours: 5.5, energy: 1), personalBand: nil, pain: nil, yesterday: nil)?.level, .recovery)
    }

    func testPainAlwaysWinsAndSaysWhy() {
        let knee = PainReport(day: "2026-09-26", areas: [.knee], level: .little)
        let result = DailyLoop.readiness(answers: answers(), personalBand: .green, pain: knee, yesterday: nil)
        XCTAssertEqual(result?.level, .reduced)
        XCTAssertEqual(result?.reason, "Because you reported pain, your training is reduced today.")
        let head = PainReport(day: "2026-09-26", areas: [.head], level: .little)
        XCTAssertEqual(DailyLoop.readiness(answers: answers(), personalBand: nil, pain: head, yesterday: nil)?.level, .recovery,
                       "a head is never trained through")
        let lot = PainReport(day: "2026-09-26", areas: [.ankle], level: .lot)
        XCTAssertEqual(DailyLoop.readiness(answers: answers(), personalBand: nil, pain: lot, yesterday: nil)?.level, .recovery)
    }

    func testAVeryHardYesterdayLightensToday() {
        let result = DailyLoop.readiness(answers: answers(), personalBand: nil, pain: nil, yesterday: EveningSignal(hardness: 4, body: 2))
        XCTAssertEqual(result?.level, .reduced)
        XCTAssertEqual(TodayReadiness.reduced.band, .amber)
        XCTAssertEqual(TodayReadiness.recovery.title, "Recovery Focus")
    }

    func testWhyThisPlanIsOneSentence() {
        XCTAssertEqual(DailyLoop.whyThisPlan(status: .active, mode: .afterPractice, practiceToday: true, gameToday: false, daysToNextGame: nil, readiness: nil),
                       "You have practice today, so the gym work is short and complements it.")
        XCTAssertEqual(DailyLoop.whyThisPlan(status: .active, mode: .gymDay, practiceToday: false, gameToday: false, daysToNextGame: 2, readiness: nil),
                       "Game in 2 days, so today stays short and sharp.")
        XCTAssertEqual(DailyLoop.whyThisPlan(status: .concussion, mode: nil, practiceToday: false, gameToday: false, daysToNextGame: nil, readiness: nil),
                       "Training is paused until a doctor clears you.")
        let pain = (level: TodayReadiness.reduced, reason: "Because you reported pain, your training is reduced today.")
        XCTAssertEqual(DailyLoop.whyThisPlan(status: .active, mode: .gymDay, practiceToday: false, gameToday: false, daysToNextGame: nil, readiness: pain), pain.reason)
    }

    func testPainIsKeptPerDay() {
        let report = PainReport(day: DayKey.of(morning, calendar: calendar), areas: [.knee, .ankle], level: .some)
        PainStore.set(report, on: morning, calendar: calendar)
        XCTAssertEqual(PainStore.report(on: morning, calendar: calendar), report)
        XCTAssertNil(PainStore.report(on: morning.addingTimeInterval(86_400), calendar: calendar))
        PainStore.set(nil, on: morning, calendar: calendar)
        XCTAssertNil(PainStore.report(on: morning, calendar: calendar), "“It's gone” clears it")
    }

    func testCheckInAnswersMapOntoTheStoredScales() {
        XCTAssertEqual(CheckInOptions.nearest(7.8, in: CheckInOptions.sleepHours)?.title, "7–8 h")
        XCTAssertEqual(CheckInOptions.nearest(4, in: CheckInOptions.energy)?.title, "Good")
        XCTAssertEqual(CheckInOptions.nearest(2, in: CheckInOptions.energy)?.title, "Low", "an older 1–5 answer shows as the nearest word")
        XCTAssertNil(CheckInOptions.nearest(nil, in: CheckInOptions.mood))
        XCTAssertEqual(CheckInOptions.soreness.last?.scale, 5, "high soreness is the top of the scale")
    }

    func testThePracticeConfirmedInTheCheckInWins() {
        let day = DayKey.of(morning, calendar: calendar)
        XCTAssertNil(PracticeOverride.hasPractice(on: day))
        PracticeOverride.set(false, on: day)
        XCTAssertEqual(PracticeOverride.hasPractice(on: day), false)
        XCTAssertFalse(PracticeSchedule.hasPractice(on: morning, calendar: calendar))
        PracticeOverride.set(true, on: day)
        XCTAssertTrue(PracticeSchedule.hasPractice(on: morning, calendar: calendar))
        PracticeOverride.set(nil, on: day)
        XCTAssertNil(PracticeOverride.hasPractice(on: day))
    }

    func testTheEveningReflectionFeedsTomorrow() {
        let evening = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 21))!
        MindsetStore.saveEvening(hardness: 4, body: 3, practice: 3, wentWell: ["Effort", "Focus"], needsWork: ["Speed"],
                                 learned: "  Call for the ball earlier ", on: evening, calendar: calendar)
        let saved = MindsetStore.reflection(on: evening, calendar: calendar)
        XCTAssertEqual(saved?.win, "Effort, Focus")
        XCTAssertEqual(saved?.lesson, "Speed")
        XCTAssertEqual(saved?.learned, "Call for the ball earlier")
        XCTAssertEqual(MindsetStore.yesterdaySignal(now: morning, calendar: calendar), EveningSignal(hardness: 4, body: 3))
    }

    func testTheDayCountsWhatsDone() {
        let day = DayCompletion(checkedIn: true, trained: true, learned: false, reflected: true)
        XCTAssertEqual(day.doneCount, 3)
        XCTAssertEqual(day.items.map(\.title), ["Morning check-in", "Training", "Campus lesson", "Evening reflection"])
    }
}
