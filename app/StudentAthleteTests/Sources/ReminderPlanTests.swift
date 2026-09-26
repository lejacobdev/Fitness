import XCTest

/// Smart reminders: a later check-in at weekends, the reflection after
/// practice, and a bedtime for nine hours before tomorrow's start.
final class ReminderPlanTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private func day(_ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: d))! } // 21 = Monday

    private var settings: ReminderScheduler.Settings {
        ReminderScheduler.Settings(checkInEnabled: true, checkInHour: 7, checkInMinute: 0, gameRemindersEnabled: true,
                                   reflectionEnabled: true, reflectionHour: 20, reflectionMinute: 30, bedtimeEnabled: true)
    }

    func testWeekendCheckInsComeLaterAndTheReflectionFollowsPractice() {
        let monday = ReminderScheduler.plan(for: day(21), settings: settings, practice: PracticeTime(start: 15 * 60, end: 17 * 60), sessionTomorrowStart: nil, calendar: calendar)
        XCTAssertEqual(monday.checkIn, 7 * 60)
        XCTAssertEqual(monday.reflection, 18 * 60, "an hour after practice ends")
        let saturday = ReminderScheduler.plan(for: day(26), settings: settings, practice: nil, sessionTomorrowStart: nil, calendar: calendar)
        XCTAssertEqual(saturday.checkIn, 7 * 60 + 75)
        XCTAssertEqual(saturday.reflection, 20 * 60 + 30)
        var plain = settings
        plain.smartTiming = false
        XCTAssertEqual(ReminderScheduler.plan(for: day(26), settings: plain, practice: nil, sessionTomorrowStart: nil, calendar: calendar).checkIn, 7 * 60)
    }

    func testBedtimeGivesNineHoursAndMovesEarlierForAnEarlyStart() {
        XCTAssertEqual(Bedtime.suggested(wakeMinutes: 7 * 60, firstSessionTomorrow: nil), 22 * 60)
        XCTAssertEqual(Bedtime.suggested(wakeMinutes: 7 * 60, firstSessionTomorrow: 8 * 60), 21 * 60 + 30, "up 90 minutes before an 8:00 start")
        let monday = ReminderScheduler.plan(for: day(21), settings: settings, practice: nil, sessionTomorrowStart: nil, calendar: calendar)
        XCTAssertEqual(monday.bedtime, 22 * 60 - 30, "the nudge comes 30 minutes before")
        let friday = ReminderScheduler.plan(for: day(25), settings: settings, practice: nil, sessionTomorrowStart: nil, calendar: calendar)
        XCTAssertEqual(friday.bedtime, 22 * 60 + 75 - 30, "Saturday's later wake-up means a later bedtime")
    }

    func testHydrationComesTwoHoursBeforeAGameOrALongPractice() {
        let game = day(21).addingTimeInterval(18 * 3600)
        XCTAssertEqual(ReminderScheduler.hydrationTime(gameStart: game, practice: nil, day: day(21), calendar: calendar), game.addingTimeInterval(-7200))
        XCTAssertEqual(ReminderScheduler.hydrationTime(gameStart: nil, practice: PracticeTime(start: 15 * 60, end: 17 * 60), day: day(21), calendar: calendar),
                       day(21).addingTimeInterval(13 * 3600))
        XCTAssertNil(ReminderScheduler.hydrationTime(gameStart: nil, practice: PracticeTime(start: 15 * 60, end: 16 * 60), day: day(21), calendar: calendar),
                     "a short practice needs no reminder")
    }

    func testAGameWithATimeUsesItAndOneWithoutUsesTheUsualTime() {
        let at7pm = day(21).addingTimeInterval(19 * 3600)
        XCTAssertEqual(FuelEngine.gameStart(at7pm, usualMinutes: 17 * 60, calendar: calendar), at7pm)
        XCTAssertEqual(FuelEngine.gameStart(day(21), usualMinutes: 17 * 60, calendar: calendar), day(21).addingTimeInterval(17 * 3600))
    }
}
