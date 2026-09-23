import Foundation

/// §10's game-day periodisation stages, applied per training day relative to
/// the athlete's competition calendar. A separate pass from `PlanGenerator`
/// (see its own doc comment) — this answers "how does THIS day change given
/// what's coming up," not "what's a normal week for this phase."
public enum TaperStage: Sendable, Equatable {
    /// −4 days and earlier: normal loading for the phase.
    case normal
    /// −3 days: last heavy session. Full intensity, reduced volume.
    case lastHeavySession
    /// −2 days: quality over quantity — short, sharp, technical. No lifting to failure.
    case qualityOverQuantity
    /// −1 day: primer only. Brief activation, a few maximal-intent efforts.
    case primer
    /// The competition itself: the warm-up sequence, nothing else.
    case gameDay
    /// +1 day after: recovery emphasis, scaled by the sport's contactLevel.
    case postGameRecovery
    /// Two games in a week: the block between them collapses to primer-and-recover.
    case betweenGames
}

public enum TaperCalculator {
    /// `competitions` need not be sorted or deduplicated.
    public static func stage(for date: Date, competitions: [Date], calendar: Calendar = .current) -> TaperStage {
        guard !competitions.isEmpty else { return .normal }
        let day = calendar.startOfDay(for: date)
        let sorted = competitions.map { calendar.startOfDay(for: $0) }.sorted()

        let next = sorted.first { $0 >= day }
        let previous = sorted.last { $0 <= day }

        let daysToNext = next.map { calendar.dateComponents([.day], from: day, to: $0).day ?? Int.max }
        let daysSincePrevious = previous.map { calendar.dateComponents([.day], from: $0, to: day).day ?? Int.max }

        if daysToNext == 0 { return .gameDay }

        // §10: "Two games in a week: the block between them collapses to
        // primer-and-recover" — a day that's both just after one game and
        // just before the next takes priority over treating it as an
        // ordinary post-game or pre-game day on its own.
        let approachingAnotherGameSoon = (daysToNext ?? Int.max) <= 3
        let justPlayed = (daysSincePrevious ?? Int.max) <= 1
        if justPlayed && approachingAnotherGameSoon {
            return .betweenGames
        }
        if justPlayed { return .postGameRecovery }

        switch daysToNext {
        case 1: return .primer
        case 2: return .qualityOverQuantity
        case 3: return .lastHeavySession
        default: return .normal
        }
    }
}
