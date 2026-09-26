import XCTest

/// Progress: team-practice logs and what they add up to, workout kinds for
/// the calendar, practice times and extra trainings, and struggles.
final class ProgressModelsTests: XCTestCase {
    private let keys = ["progress.practiceLogs", "progress.sessionKinds", "profile.struggles",
                        "schedule.practiceTimes", "schedule.extraPractices"]

    override func setUp() {
        super.setUp()
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    func testOneLogPerDayAndCountsPerKindOfPractice() {
        PracticeLogStore.save(PracticeLog(day: "2026-09-20", sportSlug: "golf", types: ["Range session", "Putting"], hard: 3, went: 4, mood: 4,
                                          ratings: ["Driver": 4, "Irons": 2]))
        PracticeLogStore.save(PracticeLog(day: "2026-09-21", sportSlug: "golf", types: ["Range session"], hard: 2, went: 3, mood: 3))
        PracticeLogStore.save(PracticeLog(day: "2026-09-21", sportSlug: "golf", types: ["Course play"], hard: 2, went: 3, mood: 3))
        XCTAssertEqual(PracticeLogStore.logs.count, 2, "logging the same day again replaces it")

        let counts = PracticeStats.counts(PracticeLogStore.logs)
        XCTAssertEqual(counts.map(\.type), ["Course play", "Putting", "Range session"].sorted())
        XCTAssertEqual(PracticeStats.ratings(PracticeLogStore.logs).first?.item, "Driver")
        XCTAssertEqual(PracticeStats.counts(PracticeLogStore.logs, since: "2026-09-21").map(\.type), ["Course play"])
    }

    func testTheInsightPointsAtWhatWasPractisedLeast() {
        let counts: [(type: String, count: Int)] = [("Range session", 10), ("Course play", 12), ("Putting", 2)]
        let insight = PracticeStats.insight(counts, allTypes: SportPractice.types(for: "golf"))
        XCTAssertNotNil(insight)
        XCTAssertFalse(SportPractice.types(for: "golf").isEmpty)
        XCTAssertEqual(SportPractice.components(for: "golf").items.first, "Driver")
    }

    func testWorkoutKindsAndExtraTrainingsCountForTheCalendar() {
        SessionKinds.record("abc", .afterPractice)
        XCTAssertEqual(SessionKinds.kind(of: "abc"), .afterPractice)
        let day = Calendar.current.date(byAdding: .day, value: 3, to: .now)!
        ExtraPractices.all = [ExtraPractice(day: DayKey.of(day), title: "Saturday session", time: PracticeTime(start: 600, end: 720))]
        XCTAssertTrue(PracticeSchedule.hasPractice(on: day))
        XCTAssertEqual(PracticeSchedule.time(on: day)?.start, 600)
    }

    func testStrugglesLeanThePlanWithoutLosingTheSport() {
        Struggles.selected = [.acceleration, .strength, .agility, .power]
        XCTAssertEqual(Struggles.selected, [.acceleration, .strength, .agility], "three at most")
        let profile = Struggles.profile(base: ["acceleration": 0.5, "aerobic-base": 0.9], struggles: [.acceleration])
        XCTAssertGreaterThan(profile["acceleration"] ?? 0, 0.9)
        XCTAssertEqual(profile["aerobic-base"], 0.9, "the sport's own qualities stay")
        XCTAssertNil(Struggles.topQuality([.confidence]), "confidence changes the Mindset tools, not the exercises")
    }
}
