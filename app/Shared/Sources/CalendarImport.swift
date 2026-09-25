import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Events

/// One event from a team or school calendar, sorted into what the app
/// cares about: games (with time and home/away), practices (including
/// cancelled ones) and exams.
public struct ScheduleEvent: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case game, practice, exam, other
    }

    /// Unique per occurrence: feed, event UID and start.
    public var id: String
    public var title: String
    public var location: String?
    public var start: Date
    public var end: Date?
    public var allDay: Bool
    public var kind: Kind
    public var cancelled: Bool
    public var isAway: Bool
    /// "GAME", "TOURNAMENT" or "MEET" (CompetitionKind's raw values).
    public var competitionKind: String

    public init(id: String, title: String, location: String? = nil, start: Date, end: Date? = nil, allDay: Bool = false,
                kind: Kind, cancelled: Bool = false, isAway: Bool = false, competitionKind: String = "GAME") {
        self.id = id
        self.title = title
        self.location = location
        self.start = start
        self.end = end
        self.allDay = allDay
        self.kind = kind
        self.cancelled = cancelled
        self.isAway = isAway
        self.competitionKind = competitionKind
    }
}

// MARK: - Sorting events

/// Reads an event's title (and categories) the way an athlete would.
/// Works for TeamSnap ("Game vs. Tigers", "Game at Lions", "Practice"),
/// Google/Apple calendars typed by coaches, and school calendars.
public enum ScheduleClassifier {
    private static let exam = ["exam", "exams", "midterm", "midterms", "final exam", "final exams", "finals week",
                               "klausur", "klausuren", "prüfung", "prüfungen", "abitur", "abi", "sat test", "act test", "psat"]
    /// Only counted on a school calendar: on a team one "test" is usually a fitness test.
    private static let schoolOnlyExam = ["test", "tests", "quiz", "finals", "assessment"]
    private static let game = ["game", "games", "match", "matches", "vs", "v", "meet", "tournament", "tourney",
                               "invitational", "race", "regatta", "championship", "championships", "playoff", "playoffs",
                               "scrimmage", "jamboree", "bout", "dual", "derby", "cup", "final", "semifinal", "quarterfinal",
                               "spiel", "heimspiel", "auswärtsspiel", "turnier", "wettkampf", "punktspiel", "pokal"]
    private static let practice = ["practice", "practise", "training", "workout", "conditioning", "lift",
                                   "lifting", "weights", "film", "walkthrough", "walk-through", "session", "drills",
                                   "trainingseinheit", "übungseinheit"]
    private static let cancelled = ["cancelled", "canceled", "cancel", "called off", "postponed", "abgesagt", "fällt aus", "ausfall"]
    private static let tournament = ["tournament", "tourney", "invitational", "jamboree", "championships", "turnier", "cup"]
    private static let meet = ["meet", "race", "regatta", "wettkampf", "dual", "relays"]

    public static func kind(title: String, categories: String? = nil, schoolCalendar: Bool) -> ScheduleEvent.Kind {
        let text = "\(title) \(categories ?? "")"
        if contains(text, any: exam) || (schoolCalendar && contains(text, any: schoolOnlyExam)) { return .exam }
        if schoolCalendar { return .other }
        if contains(text, any: game) { return .game }
        if contains(text, any: practice) { return .practice }
        // "Tigers @ Lions"
        if title.contains("@") { return .game }
        return .other
    }

    public static func isCancelled(title: String, status: String?) -> Bool {
        status?.uppercased() == "CANCELLED" || contains(title, any: cancelled)
    }

    /// "@ Lions", "Game at Lions", "Away", "(A)", "auswärts" — unless it
    /// also says home.
    public static func isAway(title: String) -> Bool {
        let lower = title.lowercased()
        let away = hasAt(title) || contains(lower, any: ["away", "auswärts", "auswärtsspiel"]) || lower.contains("(a)")
        let home = contains(lower, any: ["home", "heim", "heimspiel"]) || lower.contains("(h)")
        return away && !home
    }

    public static func competitionKind(title: String) -> String {
        if contains(title, any: tournament) { return "TOURNAMENT" }
        if contains(title, any: meet) { return "MEET" }
        return "GAME"
    }

    /// "@" anywhere, or the word "at" (as in "Game at Lions").
    private static func hasAt(_ title: String) -> Bool {
        title.contains("@") || contains(title, any: ["at"])
    }

    /// Whole-word (or whole-phrase) match, case-insensitive; punctuation
    /// counts as a space ("vs." matches "vs").
    static func contains(_ text: String, any words: [String]) -> Bool {
        var normalized = " "
        for char in text.lowercased() { normalized.append(char.isLetter || char.isNumber || char == "-" ? char : " ") }
        normalized.append(" ")
        while normalized.contains("  ") { normalized = normalized.replacingOccurrences(of: "  ", with: " ") }
        return words.contains { normalized.contains(" \($0.lowercased()) ") }
    }
}

// MARK: - Reading .ics files

/// A small iCalendar (RFC 5545) reader: events with their times (UTC,
/// time zones and all-day), repeating events (daily and weekly rules, with
/// skipped and moved occurrences) and cancellations.
public enum ICSParser {
    struct Property {
        var name: String
        var params: [String: String]
        var value: String
    }

    struct RawEvent {
        var properties: [Property] = []
        func first(_ name: String) -> Property? { properties.first { $0.name == name } }
        func all(_ name: String) -> [Property] { properties.filter { $0.name == name } }
    }

    /// Every occurrence overlapping `window`, sorted by start.
    public static func events(from text: String, feedID: String, schoolCalendar: Bool, window: DateInterval,
                              calendar: Calendar = .current) -> [ScheduleEvent] {
        let raw = rawEvents(from: text)
        // Moved or cancelled single occurrences of a repeating event.
        var overrides: [String: [Date: RawEvent]] = [:]
        var masters: [RawEvent] = []
        for event in raw {
            guard let uid = event.first("UID")?.value else { masters.append(event); continue }
            if let recurrence = event.first("RECURRENCE-ID"), let date = parseDate(recurrence, calendar: calendar)?.date {
                overrides[uid, default: [:]][date] = event
            } else {
                masters.append(event)
            }
        }

        var out: [ScheduleEvent] = []
        for master in masters {
            guard let startProp = master.first("DTSTART"), let (start, allDay) = parseDate(startProp, calendar: calendar) else { continue }
            let end = master.first("DTEND").flatMap { parseDate($0, calendar: calendar)?.date }
            let duration = end.map { $0.timeIntervalSince(start) } ?? (allDay ? 86_400 : 3_600)
            let uid = master.first("UID")?.value ?? "\(start.timeIntervalSince1970)-\(master.first("SUMMARY")?.value ?? "")"
            let excluded = Set(master.all("EXDATE").flatMap { prop in
                prop.value.split(separator: ",").compactMap { value in
                    parseDate(Property(name: "EXDATE", params: prop.params, value: String(value)), calendar: calendar)?.date
                }
            })
            let starts: [Date]
            if let rule = master.first("RRULE") {
                starts = expand(rule.value, start: start, zone: zone(of: startProp, allDay: allDay, calendar: calendar), window: window)
            } else {
                starts = [start]
            }
            for occurrence in starts where !excluded.contains(where: { abs($0.timeIntervalSince(occurrence)) < 60 }) {
                if let moved = overrides[uid]?.first(where: { abs($0.key.timeIntervalSince(occurrence)) < 60 })?.value {
                    guard let movedStart = moved.first("DTSTART").flatMap({ parseDate($0, calendar: calendar) }) else { continue }
                    let movedEnd = moved.first("DTEND").flatMap { parseDate($0, calendar: calendar)?.date }
                    out.append(make(moved, uid: uid, feedID: feedID, start: movedStart.date, end: movedEnd, allDay: movedStart.allDay, schoolCalendar: schoolCalendar))
                } else {
                    out.append(make(master, uid: uid, feedID: feedID, start: occurrence, end: occurrence.addingTimeInterval(duration), allDay: allDay, schoolCalendar: schoolCalendar))
                }
            }
        }
        return out
            .filter { ($0.end ?? $0.start) >= window.start && $0.start <= window.end }
            .sorted { $0.start < $1.start }
    }

    private static func make(_ event: RawEvent, uid: String, feedID: String, start: Date, end: Date?, allDay: Bool, schoolCalendar: Bool) -> ScheduleEvent {
        let title = unescape(event.first("SUMMARY")?.value ?? "")
        let categories = event.first("CATEGORIES").map { unescape($0.value) }
        let location = event.first("LOCATION").map { unescape($0.value) }.flatMap { $0.isEmpty ? nil : $0 }
        let kind = ScheduleClassifier.kind(title: title, categories: categories, schoolCalendar: schoolCalendar)
        let start = allDay ? start : fixedAMPM(start: start, end: end, kind: kind)
        return ScheduleEvent(
            id: "\(feedID)|\(uid)|\(Int(start.timeIntervalSince1970))",
            title: title, location: location, start: start, end: end, allDay: allDay,
            kind: kind,
            cancelled: ScheduleClassifier.isCancelled(title: title, status: event.first("STATUS")?.value),
            isAway: ScheduleClassifier.isAway(title: title),
            competitionKind: ScheduleClassifier.competitionKind(title: title)
        )
    }

    /// School calendars often have "2:45 AM" typed for 2:45 PM, which turns
    /// a 2-hour practice into a 14-hour one. A practice or game that starts
    /// before 6 AM and runs more than 8 hours is moved 12 hours later.
    static func fixedAMPM(start: Date, end: Date?, kind: ScheduleEvent.Kind, calendar: Calendar = .current) -> Date {
        guard kind == .practice || kind == .game, let end else { return start }
        let hour = calendar.component(.hour, from: start)
        let shifted = start.addingTimeInterval(12 * 3600)
        guard hour < 6, end.timeIntervalSince(start) > 8 * 3600, shifted < end else { return start }
        return shifted
    }

    // MARK: Lines

    static func rawEvents(from text: String) -> [RawEvent] {
        // Unfold: a line starting with a space or tab continues the one before.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var lines: [String] = []
        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            if let first = line.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += line.dropFirst()
            } else {
                lines.append(String(line))
            }
        }

        var events: [RawEvent] = []
        var current: RawEvent?
        var nested = 0 // VALARM and friends inside an event
        for line in lines {
            guard let property = parseLine(line) else { continue }
            switch (property.name, property.value.uppercased()) {
            case ("BEGIN", "VEVENT"):
                current = RawEvent()
                nested = 0
            case ("END", "VEVENT"):
                if let event = current { events.append(event) }
                current = nil
            case ("BEGIN", _) where current != nil:
                nested += 1
            case ("END", _) where current != nil:
                nested = max(0, nested - 1)
            default:
                if nested == 0 { current?.properties.append(property) }
            }
        }
        return events
    }

    static func parseLine(_ line: String) -> Property? {
        // The value starts after the first colon that isn't inside a quoted parameter.
        var inQuotes = false
        var splitIndex: String.Index?
        for index in line.indices {
            let char = line[index]
            if char == "\"" { inQuotes.toggle() }
            if char == ":" && !inQuotes { splitIndex = index; break }
        }
        guard let splitIndex else { return nil }
        let head = line[..<splitIndex]
        let value = String(line[line.index(after: splitIndex)...])
        let parts = head.split(separator: ";")
        guard let name = parts.first else { return nil }
        var params: [String: String] = [:]
        for part in parts.dropFirst() {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2 { params[pair[0].uppercased()] = pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
        }
        return Property(name: name.uppercased(), params: params, value: value)
    }

    static func unescape(_ text: String) -> String {
        var out = ""
        var escaping = false
        for char in text {
            if escaping {
                out.append(char == "n" || char == "N" ? "\n" : char)
                escaping = false
            } else if char == "\\" {
                escaping = true
            } else {
                out.append(char)
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Dates

    private static func zone(of property: Property, allDay: Bool, calendar: Calendar) -> TimeZone {
        if property.value.hasSuffix("Z") { return TimeZone(identifier: "UTC")! }
        if let id = property.params["TZID"], let zone = TimeZone(identifier: id) { return zone }
        return calendar.timeZone
    }

    /// "20260925T160000Z" (UTC), "20260925T160000" with TZID (or local),
    /// "20260925" / VALUE=DATE (all day, local midnight).
    static func parseDate(_ property: Property, calendar: Calendar) -> (date: Date, allDay: Bool)? {
        let value = property.value.trimmingCharacters(in: .whitespaces)
        let digits = value.filter(\.isNumber)
        guard digits.count >= 8,
              let year = Int(digits.prefix(4)), let month = Int(digits.dropFirst(4).prefix(2)), let day = Int(digits.dropFirst(6).prefix(2))
        else { return nil }
        let allDay = property.params["VALUE"]?.uppercased() == "DATE" || !value.contains("T")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = allDay ? calendar.timeZone : zone(of: property, allDay: false, calendar: calendar)
        var components = DateComponents(year: year, month: month, day: day)
        if !allDay, digits.count >= 12 {
            components.hour = Int(digits.dropFirst(8).prefix(2))
            components.minute = Int(digits.dropFirst(10).prefix(2))
            components.second = digits.count >= 14 ? Int(digits.dropFirst(12).prefix(2)) : 0
        }
        return cal.date(from: components).map { ($0, allDay) }
    }

    // MARK: Repeating events

    private static let weekdayCodes = ["SU": 1, "MO": 2, "TU": 3, "WE": 4, "TH": 5, "FR": 6, "SA": 7]

    /// Occurrence starts of a DAILY or WEEKLY rule (the ones team schedules
    /// use), keeping the wall-clock time across daylight-saving changes.
    /// Other frequencies keep just the first occurrence.
    static func expand(_ rule: String, start: Date, zone: TimeZone, window: DateInterval) -> [Date] {
        var parts: [String: String] = [:]
        for part in rule.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2 { parts[pair[0].uppercased()] = String(pair[1]) }
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let interval = max(1, Int(parts["INTERVAL"] ?? "1") ?? 1)
        let count = parts["COUNT"].flatMap(Int.init)
        let until = parts["UNTIL"].flatMap { parseDate(Property(name: "UNTIL", params: [:], value: $0), calendar: cal)?.date }
        let limit = min(until ?? window.end, window.end)
        let time = cal.dateComponents([.hour, .minute, .second], from: start)

        var out: [Date] = []
        var produced = 0
        func accept(_ date: Date) -> Bool {
            if let count, produced >= count { return false }
            if date > limit { return false }
            produced += 1
            out.append(date)
            return true
        }

        // Without a COUNT, occurrences long before the window don't matter:
        // start close to it instead of walking there from years ago.
        let skipTo = count == nil ? window.start.addingTimeInterval(-8 * 86_400) : start

        switch parts["FREQ"]?.uppercased() {
        case "DAILY":
            var day = start
            if skipTo > start, let days = cal.dateComponents([.day], from: start, to: skipTo).day, days > interval,
               let jumped = cal.date(byAdding: .day, value: (days / interval) * interval, to: start) {
                day = jumped
            }
            for _ in 0..<2000 {
                guard accept(day) else { break }
                guard let next = cal.date(byAdding: .day, value: interval, to: day) else { break }
                day = next
            }
        case "WEEKLY":
            let days = (parts["BYDAY"] ?? "").split(separator: ",").compactMap { code in
                weekdayCodes[String(code.suffix(2)).uppercased()]
            }
            let weekdays = days.isEmpty ? [cal.component(.weekday, from: start)] : days
            guard var weekStart = cal.dateInterval(of: .weekOfYear, for: start)?.start else { return [start] }
            if skipTo > weekStart, let weeks = cal.dateComponents([.weekOfYear], from: weekStart, to: skipTo).weekOfYear, weeks > interval,
               let jumped = cal.date(byAdding: .weekOfYear, value: (weeks / interval) * interval, to: weekStart) {
                weekStart = jumped
            }
            var done = false
            for _ in 0..<600 where !done {
                let dates = weekdays.compactMap { weekday -> Date? in
                    var components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)
                    components.weekday = weekday
                    components.hour = time.hour
                    components.minute = time.minute
                    components.second = time.second
                    return cal.date(from: components)
                }
                for date in dates.sorted() where date >= start {
                    if !accept(date) { done = true; break }
                }
                guard let next = cal.date(byAdding: .weekOfYear, value: interval, to: weekStart) else { break }
                weekStart = next
            }
        default:
            out = [start]
        }
        return out
    }

}

// MARK: - The imported schedule

/// Everything imported from the athlete's calendars, with the questions the
/// planner asks of it.
public struct ImportedSchedule: Codable, Sendable, Equatable {
    /// Events per calendar feed id.
    public var byFeed: [String: [ScheduleEvent]]
    public var fetchedAt: Date?

    public init(byFeed: [String: [ScheduleEvent]] = [:], fetchedAt: Date? = nil) {
        self.byFeed = byFeed
        self.fetchedAt = fetchedAt
    }

    public var events: [ScheduleEvent] { byFeed.values.flatMap { $0 }.sorted { $0.start < $1.start } }

    /// Whether there's team practice on `date` — nil when the calendars
    /// have no practices that week at all (the practice days set by hand
    /// apply then). A cancelled practice counts as no practice.
    public func practiceStatus(on date: Date, calendar: Calendar = .current) -> Bool? {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return nil }
        let practices = events.filter { $0.kind == .practice && week.contains($0.start) }
        guard !practices.isEmpty else { return nil }
        return practices.contains { !$0.cancelled && calendar.isDate($0.start, inSameDayAs: date) }
    }

    /// Practices on a day, cancelled ones included.
    public func practices(on date: Date, calendar: Calendar = .current) -> [ScheduleEvent] {
        events.filter { $0.kind == .practice && calendar.isDate($0.start, inSameDayAs: date) }
    }

    /// Days in `week` whose practice was cancelled (and nothing else is on).
    public func cancelledPracticeDays(in week: DateInterval, calendar: Calendar = .current) -> [Date] {
        let practices = events.filter { $0.kind == .practice && week.contains($0.start) }
        let cancelledDays = Set(practices.filter(\.cancelled).map { calendar.startOfDay(for: $0.start) })
        let heldDays = Set(practices.filter { !$0.cancelled }.map { calendar.startOfDay(for: $0.start) })
        return cancelledDays.subtracting(heldDays).sorted()
    }

    public func exams(in interval: DateInterval) -> [ScheduleEvent] {
        events.filter { $0.kind == .exam && !$0.cancelled && interval.contains($0.start) }
    }

    /// Games that are on (not cancelled).
    public var games: [ScheduleEvent] { events.filter { $0.kind == .game && !$0.cancelled } }

    public var counts: (games: Int, away: Int, practices: Int, exams: Int) {
        let all = events.filter { !$0.cancelled }
        return (all.filter { $0.kind == .game }.count, all.filter { $0.kind == .game && $0.isAway }.count,
                all.filter { $0.kind == .practice }.count, all.filter { $0.kind == .exam }.count)
    }
}

/// A calendar the athlete connected by link.
public struct CalendarFeed: Codable, Sendable, Equatable, Identifiable {
    public enum Role: String, Codable, Sendable, CaseIterable {
        case team, school
    }

    public var id: String
    public var url: String
    public var name: String
    public var role: Role
    public var addedAt: Date

    public init(id: String = UUID().uuidString, url: String, name: String, role: Role, addedAt: Date = .now) {
        self.id = id
        self.url = url
        self.name = name
        self.role = role
        self.addedAt = addedAt
    }

    /// webcal:// and http:// links become https:// (what TeamSnap, Google
    /// and iCloud all serve).
    public static func normalizedURL(_ string: String) -> URL? {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.lowercased().hasPrefix("webcal://") { text = "https://" + text.dropFirst("webcal://".count) }
        if text.lowercased().hasPrefix("http://") { text = "https://" + text.dropFirst("http://".count) }
        if !text.lowercased().hasPrefix("https://") { text = "https://" + text }
        guard let url = URL(string: text), url.host?.contains(".") == true else { return nil }
        return url
    }

    /// Downloads and reads the calendar: from a week ago to half a year ahead.
    public func fetchEvents(session: URLSession = .shared, now: Date = .now, calendar: Calendar = .current) async throws -> [ScheduleEvent] {
        guard let url = Self.normalizedURL(self.url) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw URLError(.badServerResponse) }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
              text.contains("BEGIN:VCALENDAR") else { throw URLError(.cannotParseResponse) }
        let window = DateInterval(start: now.addingTimeInterval(-7 * 86_400), end: now.addingTimeInterval(183 * 86_400))
        return ICSParser.events(from: text, feedID: id, schoolCalendar: role == .school, window: window, calendar: calendar)
    }
}

// MARK: - Where it's kept

/// The connected calendars (backed up with the athlete's settings), the
/// last download of them (this phone only — the other phone downloads its
/// own) and exam weeks set by hand.
public enum ScheduleStore {
    static let feedsKey = "calendar.feeds"
    static let cacheKey = "calendarCache.v1"
    static let examWeeksKey = "schedule.examWeeks"

    public static var feeds: [CalendarFeed] {
        get { decode([CalendarFeed].self, UserDefaults.standard.data(forKey: feedsKey)) ?? [] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: feedsKey) }
    }

    /// Decoded once per change: the planner asks about every day of the week.
    public static var imported: ImportedSchedule {
        get {
            let data = UserDefaults.standard.data(forKey: cacheKey)
            return memo.value(for: data) { decode(ImportedSchedule.self, data) ?? ImportedSchedule() }
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: cacheKey) }
    }

    private static let memo = Memo()

    private final class Memo: @unchecked Sendable {
        private let lock = NSLock()
        private var data: Data?
        private var schedule = ImportedSchedule()

        func value(for data: Data?, decode: () -> ImportedSchedule) -> ImportedSchedule {
            lock.lock()
            defer { lock.unlock() }
            if data != self.data {
                self.data = data
                schedule = decode()
            }
            return schedule
        }
    }

    static let hiddenGamesKey = "calendar.hiddenGames"

    /// Imported games the athlete removed: they stay removed.
    public static var hiddenGameIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: hiddenGamesKey) ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: hiddenGamesKey) }
    }

    /// Week starts (seconds since 1970) the athlete marked as exam weeks.
    public static var manualExamWeeks: Set<Double> {
        get { Set(UserDefaults.standard.array(forKey: examWeeksKey) as? [Double] ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: examWeeksKey) }
    }

    public static func weekStart(of date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    public static func isManualExamWeek(_ date: Date, calendar: Calendar = .current) -> Bool {
        manualExamWeeks.contains(weekStart(of: date, calendar: calendar).timeIntervalSince1970)
    }

    public static func setManualExamWeek(_ date: Date, _ on: Bool, calendar: Calendar = .current) {
        let key = weekStart(of: date, calendar: calendar).timeIntervalSince1970
        var weeks = manualExamWeeks.filter { $0 >= Date.now.addingTimeInterval(-60 * 86_400).timeIntervalSince1970 }
        if on { weeks.insert(key) } else { weeks.remove(key) }
        manualExamWeeks = weeks
    }

    /// An exam week: marked by hand, or a school/team calendar has an exam in it.
    public static func isExamWeek(_ date: Date, calendar: Calendar = .current) -> Bool {
        if isManualExamWeek(date, calendar: calendar) { return true }
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return false }
        return !imported.exams(in: week).isEmpty
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}

// MARK: - Exam weeks

/// Exam weeks get fewer, shorter gym sessions: at most two, one set less of
/// everything. Enough to keep what was built, with time and sleep left for
/// studying.
public enum ExamWeek {
    public static func lighten(_ week: GeneratedWeek) -> GeneratedWeek {
        guard !week.sessions.isEmpty else { return week }
        // Two at most, as far apart as the week allows.
        let kept = week.sessions.count > 2 ? [week.sessions[0], week.sessions[week.sessions.count - 1]] : week.sessions
        let lighter = kept.map { session in
            GeneratedSession(
                date: session.date, title: session.title, focusQualities: session.focusQualities,
                estimatedMinutes: max(15, Int((Double(session.estimatedMinutes) * 0.7).rounded())),
                items: session.items.map { item in
                    var dose = item.dose
                    dose.sets = max(1, dose.sets - 1)
                    return GeneratedPlannedItem(itemSlug: item.itemSlug, order: item.order, dose: dose, restSec: item.restSec,
                                                rationale: item.rationale, quality: item.quality)
                }
            )
        }
        return GeneratedWeek(phase: week.phase, weekStart: week.weekStart, sessions: lighter)
    }
}
