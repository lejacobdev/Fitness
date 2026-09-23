import Foundation

/// §11: "Track acute load (7-day rolling sRPE) against chronic load (28-day),
/// and show the ratio as a trend with a flag when the week jumps sharply...
/// It must never be presented as injury risk." Pure, like every other engine
/// here — the caller passes plain values, not SwiftData rows.
public struct LoadSample: Sendable, Equatable {
    public let date: Date
    public let minutes: Int
    public let rpe: Int?

    public init(date: Date, minutes: Int, rpe: Int?) {
        self.date = date
        self.minutes = minutes
        self.rpe = rpe
    }

    /// Session-RPE load: RPE × minutes (§11's "single most useful number").
    /// A session finished without an RPE counts at a neutral 5 rather than 0,
    /// so skipping the question never makes a hard week look empty.
    public var load: Int { minutes * (rpe ?? 5) }
}

public struct LoadSummary: Sendable, Equatable {
    /// One entry per day, oldest first, for the chart.
    public let daily: [(date: Date, load: Int)]
    /// Sum of the last 7 days.
    public let acute: Int
    /// The last 28 days expressed as an average week (sum / 4).
    public let chronicWeekly: Double
    /// Acute vs. chronic weekly, e.g. 0.4 = "up 40%". nil until there are
    /// 21+ days of history — too little to have a meaningful "normal".
    public let change: Double?

    public static func == (lhs: LoadSummary, rhs: LoadSummary) -> Bool {
        lhs.acute == rhs.acute && lhs.chronicWeekly == rhs.chronicWeekly && lhs.change == rhs.change
            && lhs.daily.map(\.load) == rhs.daily.map(\.load)
    }

    /// §11: flag "when the week jumps sharply."
    public var isSharpJump: Bool { (change ?? 0) >= LoadCalculator.sharpJumpThreshold }

    /// The exact framing §11 prescribes — about load, never about injury.
    public var message: String? {
        guard let change else { return nil }
        let percent = Int((abs(change) * 100).rounded())
        if isSharpJump {
            return "Your training load is up \(percent)% on your four-week average — that's a big jump. Consider easing the next couple of days."
        }
        if change <= -0.3 {
            return "Your training load is down \(percent)% on your four-week average — a lighter week."
        }
        return "Your training load is in line with your four-week average."
    }
}

public enum LoadCalculator {
    /// §23-style named constant: a 30%+ jump on the four-week norm is flagged.
    public static let sharpJumpThreshold = 0.3

    public static func summarize(_ samples: [LoadSample], now: Date = .now, days: Int = 28, calendar: Calendar = .current) -> LoadSummary {
        let today = calendar.startOfDay(for: now)
        var byDay: [Date: Int] = [:]
        for sample in samples {
            byDay[calendar.startOfDay(for: sample.date), default: 0] += sample.load
        }
        let daily: [(date: Date, load: Int)] = (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day, byDay[day] ?? 0)
        }
        let acute = daily.suffix(7).reduce(0) { $0 + $1.load }
        let chronicWeekly = Double(daily.reduce(0) { $0 + $1.load }) / 4

        let earliest = samples.map { calendar.startOfDay(for: $0.date) }.min()
        let historyDays = earliest.map { calendar.dateComponents([.day], from: $0, to: today).day ?? 0 } ?? 0
        let change: Double? = (historyDays >= 21 && chronicWeekly > 0) ? Double(acute) / chronicWeekly - 1 : nil

        return LoadSummary(daily: daily, acute: acute, chronicWeekly: chronicWeekly, change: change)
    }
}
