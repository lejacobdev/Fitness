import Foundation

/// Campus beyond single lessons: XP per week (for leagues with teammates),
/// spaced review of what's been learned, and badges. Everything lives under
/// `campus.` and is backed up with the athlete's settings.

// MARK: - Weekly log

public enum CampusLog {
    static let weekXPKey = "campus.weekXP"
    static let weekLessonsKey = "campus.weekLessons"
    static let perfectKey = "campus.perfect"
    static let reviewsKey = "campus.reviewsDone"
    static let bestStreakKey = "campus.bestStreak"

    /// The Monday that starts `date`'s week, YYYY-MM-DD — the same for
    /// everyone in a league.
    public static func weekKey(_ date: Date = .now, calendar: Calendar = .current) -> String {
        var cal = calendar
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let c = cal.dateComponents([.year, .month, .day], from: start)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// After a lesson or a review.
    public static func record(xp: Int, lesson: Bool, perfect: Bool, review: Bool, streak: Int,
                              on date: Date = .now, calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        let week = weekKey(date, calendar: calendar)
        var xpLog = dictionary(weekXPKey, defaults)
        xpLog[week, default: 0] += xp
        save(xpLog, weekXPKey, defaults)
        if lesson {
            var lessons = dictionary(weekLessonsKey, defaults)
            lessons[week, default: 0] += 1
            save(lessons, weekLessonsKey, defaults)
        }
        if perfect { defaults.set(defaults.integer(forKey: perfectKey) + 1, forKey: perfectKey) }
        if review { defaults.set(defaults.integer(forKey: reviewsKey) + 1, forKey: reviewsKey) }
        if streak > defaults.integer(forKey: bestStreakKey) { defaults.set(streak, forKey: bestStreakKey) }
    }

    public static func xp(inWeekOf date: Date = .now, calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Int {
        dictionary(weekXPKey, defaults)[weekKey(date, calendar: calendar)] ?? 0
    }

    public static func lessons(inWeekOf date: Date = .now, calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Int {
        dictionary(weekLessonsKey, defaults)[weekKey(date, calendar: calendar)] ?? 0
    }

    public static func perfectLessons(_ defaults: UserDefaults = .standard) -> Int { defaults.integer(forKey: perfectKey) }
    public static func reviewsDone(_ defaults: UserDefaults = .standard) -> Int { defaults.integer(forKey: reviewsKey) }
    public static func bestStreak(_ defaults: UserDefaults = .standard) -> Int { defaults.integer(forKey: bestStreakKey) }

    /// Stored as JSON so the backup (CloudSync) carries it.
    private static func dictionary(_ key: String, _ defaults: UserDefaults) -> [String: Int] {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? [:]
    }

    /// Keeps the last 12 weeks.
    private static func save(_ value: [String: Int], _ key: String, _ defaults: UserDefaults) {
        let kept = Set(value.keys.sorted().suffix(12))
        defaults.set(try? JSONEncoder().encode(value.filter { kept.contains($0.key) }), forKey: key)
    }
}

// MARK: - Spaced review

/// Lessons come back for a quick review after 1, 3, 7, 14, 30 and 60 days
/// (a Leitner box): right answers push a lesson further out, a mistake
/// brings it back to tomorrow. That's what makes knowledge stick.
public enum CampusReview {
    static let key = "campus.review"
    public static let intervals = [1, 3, 7, 14, 30, 60]
    /// Lessons in one review session.
    public static let lessonsPerReview = 3

    struct Card: Codable, Equatable {
        var box: Int
        /// YYYY-MM-DD
        var due: String
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func cards(_ defaults: UserDefaults) -> [String: Card] {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([String: Card].self, from: $0) } ?? [:]
    }

    private static func save(_ cards: [String: Card], _ defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(cards), forKey: key)
    }

    /// A lesson just finished for the first time: review it tomorrow.
    public static func schedule(_ lessonID: String, today: Date = .now, calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        var all = cards(defaults)
        guard all[lessonID] == nil else { return }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        all[lessonID] = Card(box: 0, due: dayKey(tomorrow, calendar: calendar))
        save(all, defaults)
    }

    /// Learned lessons due today (the most overdue first). Lessons learned
    /// before reviews existed count as due.
    public static func due(learned: Set<String>, today: Date = .now, calendar: Calendar = .current,
                           defaults: UserDefaults = .standard) -> [String] {
        let all = cards(defaults)
        let todayKey = dayKey(today, calendar: calendar)
        var due: [(id: String, day: String)] = []
        for id in learned {
            let day: String = all[id]?.due ?? "0000-00-00"
            if day <= todayKey { due.append((id: id, day: day)) }
        }
        due.sort { a, b in a.day == b.day ? a.id < b.id : a.day < b.day }
        return due.map { $0.id }
    }

    /// Two questions from each lesson, different ones from day to day.
    public static func questions(for lessonIDs: [String], today: Date = .now, calendar: Calendar = .current) -> [CampusQuestion] {
        let day = calendar.ordinality(of: .day, in: .era, for: today) ?? 0
        return lessonIDs.flatMap { id -> [CampusQuestion] in
            let pool = campusQuestions[id] ?? []
            guard !pool.isEmpty else { return [] }
            let first = pool[day % pool.count]
            let second = pool[(day + 1) % pool.count]
            return pool.count > 1 ? [first, second] : [first]
        }
    }

    /// Which lesson a question belongs to.
    public static func lesson(of question: CampusQuestion) -> String? {
        campusQuestions.first { $0.value.contains(question) }?.key
    }

    /// After a review: right → the next box, wrong → back to tomorrow.
    public static func record(reviewed: [String], wrong: Set<String>, today: Date = .now, calendar: Calendar = .current,
                              defaults: UserDefaults = .standard) {
        var all = cards(defaults)
        for id in reviewed {
            let box = wrong.contains(id) ? 0 : min((all[id]?.box ?? 0) + 1, intervals.count - 1)
            let next = calendar.date(byAdding: .day, value: intervals[box], to: today) ?? today
            all[id] = Card(box: box, due: dayKey(next, calendar: calendar))
        }
        save(all, defaults)
    }
}

// MARK: - Badges

public struct CampusBadge: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    /// How to earn it, in plain words.
    public let detail: String
    public let systemImage: String
}

/// What the badges are decided from.
public struct CampusStats: Sendable, Equatable {
    public var learned: Set<String>
    public var xp: Int
    public var bestStreak: Int
    public var perfectLessons: Int
    public var reviews: Int
    /// First in a league this week (with at least one teammate who played).
    public var topOfLeague: Bool
    /// Sport guides whose quiz was passed.
    public var guidesPassed: Int

    public init(learned: Set<String>, xp: Int, bestStreak: Int, perfectLessons: Int, reviews: Int,
                topOfLeague: Bool = false, guidesPassed: Int = 0) {
        self.learned = learned
        self.xp = xp
        self.bestStreak = bestStreak
        self.perfectLessons = perfectLessons
        self.reviews = reviews
        self.topOfLeague = topOfLeague
        self.guidesPassed = guidesPassed
    }
}

public enum CampusBadges {
    static let key = "campus.badges"

    public static var all: [CampusBadge] {
        var badges = [
            CampusBadge(id: "first-lesson", title: "First step", detail: "Finish your first lesson.", systemImage: "shoe.fill"),
            CampusBadge(id: "streak-3", title: "Warming up", detail: "Learn 3 days in a row.", systemImage: "flame"),
            CampusBadge(id: "streak-7", title: "On fire", detail: "Learn 7 days in a row.", systemImage: "flame.fill"),
            CampusBadge(id: "streak-30", title: "Unstoppable", detail: "Learn 30 days in a row.", systemImage: "bolt.heart.fill"),
            CampusBadge(id: "xp-100", title: "100 XP", detail: "Earn 100 XP.", systemImage: "bolt.fill"),
            CampusBadge(id: "xp-500", title: "500 XP", detail: "Earn 500 XP.", systemImage: "bolt.circle.fill"),
            CampusBadge(id: "xp-1000", title: "1000 XP", detail: "Earn 1000 XP.", systemImage: "star.circle.fill"),
            CampusBadge(id: "perfect-5", title: "Flawless", detail: "Finish 5 lessons without a single mistake.", systemImage: "checkmark.seal.fill"),
            CampusBadge(id: "review-10", title: "Memory master", detail: "Do 10 reviews.", systemImage: "arrow.triangle.2.circlepath"),
            CampusBadge(id: "league-top", title: "Top of the table", detail: "Be first in a league with your teammates.", systemImage: "trophy.fill"),
            CampusBadge(id: "sport-guide", title: "Know your sport", detail: "Pass the quiz in your sport's guide.", systemImage: "book.closed.fill"),
        ]
        for topic in campusTopics {
            badges.append(CampusBadge(id: "unit-\(topic.id)", title: topic.title, detail: "Finish every lesson in \(topic.title).", systemImage: topic.systemImage))
        }
        badges.append(CampusBadge(id: "all-units", title: "Campus graduate", detail: "Finish every lesson on Campus.", systemImage: "graduationcap.fill"))
        return badges
    }

    /// The badges these stats deserve.
    public static func deserved(_ s: CampusStats) -> Set<String> {
        var ids: Set<String> = []
        if !s.learned.isEmpty { ids.insert("first-lesson") }
        if s.bestStreak >= 3 { ids.insert("streak-3") }
        if s.bestStreak >= 7 { ids.insert("streak-7") }
        if s.bestStreak >= 30 { ids.insert("streak-30") }
        if s.xp >= 100 { ids.insert("xp-100") }
        if s.xp >= 500 { ids.insert("xp-500") }
        if s.xp >= 1000 { ids.insert("xp-1000") }
        if s.perfectLessons >= 5 { ids.insert("perfect-5") }
        if s.reviews >= 10 { ids.insert("review-10") }
        if s.topOfLeague { ids.insert("league-top") }
        if s.guidesPassed >= 1 { ids.insert("sport-guide") }
        var allDone = true
        for topic in campusTopics {
            if topic.lessons.allSatisfy({ s.learned.contains($0.id) }) {
                ids.insert("unit-\(topic.id)")
            } else {
                allDone = false
            }
        }
        if allDone, !campusTopics.isEmpty { ids.insert("all-units") }
        return ids
    }

    /// Earned badges (id → YYYY-MM-DD). Once earned, a badge stays.
    public static func earned(_ defaults: UserDefaults = .standard) -> [String: String] {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    }

    /// Saves any newly deserved badges and returns them (for the celebration).
    @discardableResult
    public static func award(_ stats: CampusStats, today: Date = .now, calendar: Calendar = .current,
                             defaults: UserDefaults = .standard) -> [CampusBadge] {
        var earned = earned(defaults)
        let new = deserved(stats).subtracting(earned.keys)
        guard !new.isEmpty else { return [] }
        let day = CampusReview.dayKey(today, calendar: calendar)
        for id in new { earned[id] = day }
        defaults.set(try? JSONEncoder().encode(earned), forKey: key)
        return all.filter { new.contains($0.id) }
    }
}
