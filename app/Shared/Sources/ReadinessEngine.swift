import Foundation

/// §11's readiness engine, pure and deterministic like `PlanGenerator` and
/// `TaperCalculator` — no SwiftData, no I/O. "Readiness is scored against
/// the athlete's own baseline, never a population norm... keep a rolling
/// 28-day mean and standard deviation per item, compute a z-score, and
/// combine into a readiness band — green, amber, or red — only once at
/// least 7 days of history exist. Before that, the app shows the raw
/// answers and says it is still learning their baseline, rather than
/// inventing a score from nothing."
public struct CheckInAnswers: Sendable {
    public let date: Date
    public let sleepQuality: Int
    public let soreness: Int
    public let energy: Int
    public let stress: Int

    public init(date: Date, sleepQuality: Int, soreness: Int, energy: Int, stress: Int) {
        self.date = date
        self.sleepQuality = sleepQuality
        self.soreness = soreness
        self.energy = energy
        self.stress = stress
    }
}

public enum ReadinessEngine {
    /// §23-style named, changeable constants: the combined z-score below
    /// which a day reads amber or red. Not derived from any external norm —
    /// there's nothing published for a four-item teenage-athlete check-in —
    /// chosen so a single mildly-off metric doesn't tip the whole day, but a
    /// broad slump does.
    private static let amberThreshold = -0.3
    private static let redThreshold = -1.0
    private static let minimumHistoryDays = 7

    /// `history` is every PRIOR check-in (never including the one being
    /// scored) — the baseline is computed from history, then today's
    /// answers are scored against it, matching §11 exactly. Returns nil
    /// when fewer than 7 days of history fall inside the trailing 28-day
    /// window: not enough to trust a personal baseline yet.
    public static func score(
        today: CheckInAnswers, history: [CheckInAnswers], now: Date = .now, calendar: Calendar = .current
    ) -> (band: ReadinessBand, z: Double)? {
        let cutoff = calendar.date(byAdding: .day, value: -28, to: now) ?? now
        let recent = history.filter { $0.date >= cutoff }
        guard recent.count >= minimumHistoryDays else { return nil }

        // Soreness and stress are "bad when high" — negate their z-scores so
        // every term means the same thing (positive = better than normal),
        // and the four can be averaged directly.
        let sleepZ = zScore(today.sleepQuality, in: recent.map(\.sleepQuality))
        let sorenessZ = -zScore(today.soreness, in: recent.map(\.soreness))
        let energyZ = zScore(today.energy, in: recent.map(\.energy))
        let stressZ = -zScore(today.stress, in: recent.map(\.stress))
        let combined = (sleepZ + sorenessZ + energyZ + stressZ) / 4

        let band: ReadinessBand = combined <= redThreshold ? .red : (combined <= amberThreshold ? .amber : .green)
        return (band, combined)
    }

    private static func zScore(_ value: Int, in samples: [Int]) -> Double {
        let doubles = samples.map(Double.init)
        guard !doubles.isEmpty else { return 0 }
        let mean = doubles.reduce(0, +) / Double(doubles.count)
        let variance = doubles.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(doubles.count)
        let standardDeviation = variance.squareRoot()
        // A baseline with zero spread (e.g. every prior day scored the same)
        // can't produce a meaningful z-score — treat today as "at baseline"
        // rather than dividing by zero.
        guard standardDeviation > 0 else { return 0 }
        return (Double(value) - mean) / standardDeviation
    }
}
