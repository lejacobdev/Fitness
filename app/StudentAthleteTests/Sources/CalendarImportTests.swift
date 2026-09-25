import XCTest

/// Team and school calendars: reading .ics links, sorting events, and the
/// plan built around them.
final class CalendarImportTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private let teamFeed = """
    BEGIN:VCALENDAR\r
    VERSION:2.0\r
    BEGIN:VEVENT\r
    UID:practice-1\r
    DTSTART;TZID=America/New_York:20260831T160000\r
    DTEND;TZID=America/New_York:20260831T180000\r
    RRULE:FREQ=WEEKLY;BYDAY=MO,WE,TH;UNTIL=20261120T235959Z\r
    EXDATE;TZID=America/New_York:20261005T160000\r
    SUMMARY:Practice\r
    LOCATION:Main field\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    UID:practice-1\r
    RECURRENCE-ID;TZID=America/New_York:20261001T160000\r
    DTSTART;TZID=America/New_York:20261001T160000\r
    STATUS:CANCELLED\r
    SUMMARY:Practice\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    UID:game-1\r
    DTSTART:20261003T223000Z\r
    SUMMARY:Game at Lions\r
    LOCATION:Lions Stadium\\, Springfield\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    UID:game-2\r
    DTSTART:20261010T180000Z\r
    SUMMARY:Game vs. Tigers\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    UID:tourney\r
    DTSTART;VALUE=DATE:20261017\r
    DTEND;VALUE=DATE:20261019\r
    SUMMARY:Fall Invitational\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    UID:dinner\r
    DTSTART:20261002T230000Z\r
    SUMMARY:Team dinner at Joe's\r
    END:VEVENT\r
    END:VCALENDAR\r

    """

    private func events() -> [ScheduleEvent] {
        let now = date(2026, 9, 25, 9)
        let window = DateInterval(start: now.addingTimeInterval(-7 * 86_400), end: now.addingTimeInterval(183 * 86_400))
        return ICSParser.events(from: teamFeed, feedID: "team", schoolCalendar: false, window: window, calendar: calendar)
    }

    func testWeeklyPracticesKeepTheirTimeAndSkipAndCancelOccurrences() {
        let practices = events().filter { $0.kind == .practice }
        XCTAssertFalse(practices.isEmpty)
        XCTAssertTrue(practices.allSatisfy { calendar.component(.hour, from: $0.start) == 16 }, "4 pm, before and after the clocks change")
        XCTAssertFalse(practices.contains { calendar.isDate($0.start, inSameDayAs: date(2026, 10, 5)) }, "a skipped date is gone")
        XCTAssertEqual(practices.first { calendar.isDate($0.start, inSameDayAs: date(2026, 10, 1)) }?.cancelled, true)
        XCTAssertTrue(practices.allSatisfy { $0.start < date(2026, 11, 21) }, "the rule ends when it says")
    }

    func testGamesComeWithHomeAwayAndKind() {
        let games = events().filter { $0.kind == .game }
        let lions = games.first { $0.title == "Game at Lions" }
        XCTAssertEqual(lions?.isAway, true)
        XCTAssertEqual(lions?.location, "Lions Stadium, Springfield")
        XCTAssertEqual(games.first { $0.title == "Game vs. Tigers" }?.isAway, false)
        XCTAssertEqual(games.first { $0.title == "Fall Invitational" }?.competitionKind, "TOURNAMENT")
        XCTAssertEqual(events().first { $0.title.hasPrefix("Team dinner") }?.kind, .other)
    }

    func testSortingTitles() {
        XCTAssertEqual(ScheduleClassifier.kind(title: "Biology test", schoolCalendar: true), .exam)
        XCTAssertEqual(ScheduleClassifier.kind(title: "Fitness test", schoolCalendar: false), .other, "on a team calendar a test is a fitness test")
        XCTAssertEqual(ScheduleClassifier.kind(title: "Practice Sat", schoolCalendar: false), .practice)
        XCTAssertEqual(ScheduleClassifier.kind(title: "Tigers @ Lions", schoolCalendar: false), .game)
        XCTAssertTrue(ScheduleClassifier.isCancelled(title: "CANCELLED: Practice", status: nil))
        XCTAssertTrue(ScheduleClassifier.isCancelled(title: "Practice", status: "CANCELLED"))
    }

    func testCalendarLinksBecomeHTTPS() {
        XCTAssertEqual(CalendarFeed.normalizedURL("webcal://p12-caldav.icloud.com/published/2/abc")?.absoluteString,
                       "https://p12-caldav.icloud.com/published/2/abc")
        XCTAssertNil(CalendarFeed.normalizedURL("not a link"))
    }

    func testACancelledPracticeCountsAsNoPracticeAndIsListed() {
        let schedule = ImportedSchedule(byFeed: ["team": events()])
        XCTAssertEqual(schedule.practiceStatus(on: date(2026, 9, 30), calendar: calendar), true)
        XCTAssertEqual(schedule.practiceStatus(on: date(2026, 10, 1), calendar: calendar), false)
        let week = calendar.dateInterval(of: .weekOfYear, for: date(2026, 10, 1))!
        XCTAssertEqual(schedule.cancelledPracticeDays(in: week, calendar: calendar).count, 1)
        XCTAssertNil(schedule.practiceStatus(on: date(2027, 6, 2), calendar: calendar), "no practices that week: practice days apply")
    }

    func testACancelledPracticeMovesTheGymDayThere() {
        let weekStart = date(2026, 9, 28) // a Monday
        let sessions = (0..<2).map { index in
            GeneratedSession(date: weekStart, title: "S\(index)", focusQualities: [], estimatedMinutes: 45, items: [])
        }
        let week = GeneratedWeek(phase: .inSeason, weekStart: weekStart, sessions: sessions)
        let practice: Set<Int> = [2, 4, 5] // Mon, Wed, Thu
        let isPractice = { (day: Date) in practice.contains(self.calendar.component(.weekday, from: day)) }
        let normal = WeeklyPlan.alignToSchedule(week, isPracticeDay: isPractice, preferredDays: [], gameDays: [], calendar: calendar)!
        let wednesday = date(2026, 9, 30)
        XCTAssertFalse(normal.sessions.contains { calendar.isDate($0.date, inSameDayAs: wednesday) })

        // Wednesday's practice is cancelled: a gym session moves onto it.
        let cancelled = { (day: Date) in isPractice(day) && !self.calendar.isDate(day, inSameDayAs: wednesday) }
        let moved = WeeklyPlan.alignToSchedule(week, isPracticeDay: cancelled, preferredDays: [wednesday], gameDays: [], calendar: calendar)!
        XCTAssertTrue(moved.sessions.contains { calendar.isDate($0.date, inSameDayAs: wednesday) })
        XCTAssertEqual(moved.sessions.count, 2, "moved, not added")
    }

    func testExamWeeksAreLighter() {
        let item = GeneratedPlannedItem(itemSlug: "split-squat", order: 0, dose: Dose(kind: "reps", sets: 3, reps: 8),
                                        restSec: 90, rationale: "", quality: "lower-body-strength")
        let sessions = (0..<3).map { index in
            GeneratedSession(date: date(2026, 9, 28 + index * 2), title: "S\(index)", focusQualities: [], estimatedMinutes: 50, items: [item])
        }
        let lighter = ExamWeek.lighten(GeneratedWeek(phase: .offSeason, weekStart: date(2026, 9, 28), sessions: sessions))
        XCTAssertEqual(lighter.sessions.map(\.title), ["S0", "S2"])
        XCTAssertTrue(lighter.sessions.allSatisfy { $0.estimatedMinutes == 35 && $0.items[0].dose.sets == 2 })
    }
}
