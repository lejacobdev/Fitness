import XCTest

/// Campus leagues' weekly XP, spaced review and badges.
final class CampusExtrasTests: XCTestCase {
    private var defaults: UserDefaults!
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "CampusExtrasTests")
        defaults.removePersistentDomain(forName: "CampusExtrasTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "CampusExtrasTests")
        super.tearDown()
    }

    private func day(_ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: d, hour: 12))! }

    func testWeeksStartOnMondayForEveryone() {
        XCTAssertEqual(CampusLog.weekKey(day(24), calendar: calendar), "2026-09-21")
        XCTAssertEqual(CampusLog.weekKey(day(27), calendar: calendar), "2026-09-21", "Sunday belongs to the week that started Monday")
        CampusLog.record(xp: 15, lesson: true, perfect: true, review: false, streak: 2, on: day(24), calendar: calendar, defaults: defaults)
        CampusLog.record(xp: 10, lesson: false, perfect: false, review: true, streak: 3, on: day(27), calendar: calendar, defaults: defaults)
        XCTAssertEqual(CampusLog.xp(inWeekOf: day(22), calendar: calendar, defaults: defaults), 25)
        XCTAssertEqual(CampusLog.lessons(inWeekOf: day(22), calendar: calendar, defaults: defaults), 1)
        XCTAssertEqual(CampusLog.bestStreak(defaults), 3)
    }

    func testReviewsComeBackLaterWhenRightAndTomorrowWhenWrong() {
        let ids = campusTopics[0].lessons.map(\.id)
        CampusReview.schedule(ids[0], today: day(24), calendar: calendar, defaults: defaults)
        XCTAssertTrue(CampusReview.due(learned: [ids[0]], today: day(24), calendar: calendar, defaults: defaults).isEmpty)
        XCTAssertEqual(CampusReview.due(learned: [ids[0]], today: day(25), calendar: calendar, defaults: defaults), [ids[0]])
        CampusReview.record(reviewed: [ids[0], ids[1]], wrong: [ids[1]], today: day(25), calendar: calendar, defaults: defaults)
        XCTAssertEqual(CampusReview.due(learned: [ids[0], ids[1]], today: day(26), calendar: calendar, defaults: defaults), [ids[1]])
        let questions = CampusReview.questions(for: [ids[0]], today: day(25), calendar: calendar)
        XCTAssertEqual(questions.count, 2)
        XCTAssertEqual(CampusReview.lesson(of: questions[0]), ids[0])
    }

    func testBadgesAreEarnedOnceAndFinishingAUnitCounts() {
        let unit = campusTopics[0]
        let stats = CampusStats(learned: Set(unit.lessons.map(\.id)), xp: 120, bestStreak: 7, perfectLessons: 0, reviews: 0)
        let new = Set(CampusBadges.award(stats, today: day(24), calendar: calendar, defaults: defaults).map(\.id))
        XCTAssertTrue(new.isSuperset(of: ["first-lesson", "streak-3", "streak-7", "xp-100", "unit-\(unit.id)"]))
        XCTAssertFalse(new.contains("all-units"))
        XCTAssertTrue(CampusBadges.award(stats, today: day(25), calendar: calendar, defaults: defaults).isEmpty, "never twice")
        XCTAssertEqual(Set(CampusBadges.all.map(\.id)).count, CampusBadges.all.count)
    }
}
