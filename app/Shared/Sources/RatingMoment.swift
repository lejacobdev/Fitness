import Foundation

/// Asking for an App Store rating only after a good moment (a new personal
/// best, a streak milestone) — never on a day pain was reported, never twice
/// within four months, and not in the first week.
public enum RatingMoment {
    static let lastAskedKey = "rating.lastAsked"
    public static let streakMilestones: Set<Int> = [7, 30, 100]

    public static func shouldAsk(now: Date, firstUse: Date, lastAsked: Date?, painToday: Bool, calendar: Calendar = .current) -> Bool {
        guard !painToday else { return false }
        guard let week = calendar.date(byAdding: .day, value: 7, to: firstUse), now >= week else { return false }
        if let lastAsked, let next = calendar.date(byAdding: .day, value: 120, to: lastAsked), now < next { return false }
        return true
    }

    static let firstUseKey = "rating.firstUse"

    /// The first day the app was opened on this phone (set once).
    public static var firstUse: Date {
        if let date = UserDefaults.standard.object(forKey: firstUseKey) as? Date { return date }
        UserDefaults.standard.set(Date.now, forKey: firstUseKey)
        return .now
    }

    /// Whether to ask now (and remember that we did).
    public static func consume(firstUse: Date, now: Date = .now) -> Bool {
        let last = UserDefaults.standard.object(forKey: lastAskedKey) as? Date
        guard shouldAsk(now: now, firstUse: firstUse, lastAsked: last, painToday: PainStore.report(on: now) != nil) else { return false }
        UserDefaults.standard.set(now, forKey: lastAskedKey)
        return true
    }
}
