import Foundation

/// The last 30 days in numbers, and a few patterns worth noticing. Worded
/// neutrally: what went together, never what caused what.
public struct ThirtyDays: Equatable, Sendable {
    public var trainingDays: Int
    public var workouts: Int
    public var minutes: Int
    public var practices: Int
    public var checkIns: Int
    public var averageSleep: Double?
    public var insights: [String]
}

public enum ProgressInsights {
    public struct CheckInPoint: Sendable {
        public let date: Date
        public let sleepHours: Double?
        public let energy: Int
        public let soreness: Int

        public init(date: Date, sleepHours: Double?, energy: Int, soreness: Int) {
            self.date = date
            self.sleepHours = sleepHours
            self.energy = energy
            self.soreness = soreness
        }
    }

    public static func lastThirtyDays(
        sessions: [(date: Date, minutes: Int)], practiceDays: [String], checkIns: [CheckInPoint],
        needsWork: [[String]], now: Date = .now, calendar: Calendar = .current
    ) -> ThirtyDays {
        let start = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now)) ?? now
        let startKey = DayKey.of(start, calendar: calendar)
        let recentSessions = sessions.filter { $0.date >= start && $0.date <= now }
        let recentPractices = Set(practiceDays.filter { $0 >= startKey && $0 <= DayKey.of(now, calendar: calendar) })
        let recentCheckIns = checkIns.filter { $0.date >= start && $0.date <= now }
        let trainingDays = Set(recentSessions.map { DayKey.of($0.date, calendar: calendar) }).union(recentPractices)
        let hours = recentCheckIns.compactMap(\.sleepHours)

        var insights: [String] = []
        if !trainingDays.isEmpty {
            insights.append("You trained on \(trainingDays.count) of the last 30 days.")
        }
        // Sleep and energy: only with a few mornings on each side.
        let rested = recentCheckIns.filter { ($0.sleepHours ?? 0) >= 8 }.map { Double($0.energy) }
        let short = recentCheckIns.filter { $0.sleepHours.map { $0 < 8 } ?? false }.map { Double($0.energy) }
        if rested.count >= 3, short.count >= 3 {
            let difference = rested.reduce(0, +) / Double(rested.count) - short.reduce(0, +) / Double(short.count)
            if difference >= 0.5 {
                insights.append("On mornings after 8+ hours of sleep, your energy was higher on average.")
            } else if difference <= -0.5 {
                insights.append("On mornings after 8+ hours of sleep, your energy was lower on average.")
            }
        }
        // Soreness the day after training versus after a rest day.
        let afterTraining = recentCheckIns.filter { point in
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: point.date) else { return false }
            return trainingDays.contains(DayKey.of(yesterday, calendar: calendar))
        }.map { Double($0.soreness) }
        let afterRest = recentCheckIns.filter { point in
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: point.date) else { return false }
            return !trainingDays.contains(DayKey.of(yesterday, calendar: calendar))
        }.map { Double($0.soreness) }
        if afterTraining.count >= 3, afterRest.count >= 3 {
            let difference = afterTraining.reduce(0, +) / Double(afterTraining.count) - afterRest.reduce(0, +) / Double(afterRest.count)
            if difference >= 0.75 {
                insights.append("Soreness was usually higher the morning after training than after a rest day.")
            }
        }
        // What came up most in "needs work".
        var counts: [String: Int] = [:]
        for areas in needsWork { for area in areas { counts[area, default: 0] += 1 } }
        if let top = counts.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }), top.value >= 2 {
            insights.append("“\(top.key)” came up most often in what needs work (\(top.value) times).")
        }

        return ThirtyDays(
            trainingDays: trainingDays.count, workouts: recentSessions.count, minutes: recentSessions.reduce(0) { $0 + $1.minutes },
            practices: recentPractices.count, checkIns: recentCheckIns.count,
            averageSleep: hours.isEmpty ? nil : hours.reduce(0, +) / Double(hours.count),
            insights: Array(insights.prefix(3))
        )
    }
}
