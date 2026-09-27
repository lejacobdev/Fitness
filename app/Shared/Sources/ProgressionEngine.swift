import Foundation

/// One set as it was logged, for working out the next target.
public struct LoggedSet: Sendable, Equatable {
    public var reps: Int?
    public var weightKg: Double?
    public var seconds: Int?

    public init(reps: Int? = nil, weightKg: Double? = nil, seconds: Int? = nil) {
        self.reps = reps
        self.weightKg = weightKg
        self.seconds = seconds
    }
}

/// What to aim for this time, and one short line saying why.
public struct ProgressionTarget: Sendable, Equatable {
    public var reps: Int?
    public var weightKg: Double?
    public var seconds: Int?
    public var note: String
}

/// Progressive overload, the conservative way ("double progression"): the
/// weight only goes up one step after every set reached the target reps and
/// the session wasn't maximal (RPE 9–10). Missed reps keep the weight.
/// Bodyweight moves add a rep, holds add five seconds. A deload week takes
/// a little off on purpose.
public enum ProgressionEngine {
    public static func next(
        last sets: [LoggedSet], dose: Dose, sessionRPE: Int?, isYouth: Bool, stepKg: Double, deload: Bool = false
    ) -> ProgressionTarget? {
        guard !sets.isEmpty else { return nil }
        let easyEnough = (sessionRPE ?? 7) <= 8
        switch dose.kind {
        case "reps":
            let target = dose.reps ?? sets.compactMap(\.reps).max() ?? 8
            let hitAll = sets.allSatisfy { ($0.reps ?? 0) >= target }
            let weight = sets.compactMap(\.weightKg).max() ?? 0
            if weight > 0 {
                if deload {
                    return ProgressionTarget(reps: target, weightKg: rounded(weight * 0.9, step: stepKg), seconds: nil,
                                             note: "Deload week: a bit lighter on purpose.")
                }
                if hitAll && easyEnough {
                    return ProgressionTarget(reps: target, weightKg: weight + stepKg, seconds: nil,
                                             note: "Every rep last time: one step heavier.")
                }
                return ProgressionTarget(reps: target, weightKg: weight, seconds: nil,
                                         note: "Same weight: aim for \(target) on every set.")
            }
            let best = sets.compactMap(\.reps).min() ?? target
            if deload { return ProgressionTarget(reps: max(1, best - 2), weightKg: nil, seconds: nil, note: "Deload week: a few reps fewer.") }
            let cap = isYouth ? 15 : 20
            if best >= target && easyEnough && best < cap {
                return ProgressionTarget(reps: best + 1, weightKg: nil, seconds: nil, note: "One more rep than last time.")
            }
            return ProgressionTarget(reps: max(best, target), weightKg: nil, seconds: nil, note: "Match last time with clean reps.")
        case "time":
            let target = dose.seconds ?? 30
            let shortest = sets.compactMap(\.seconds).min() ?? target
            if deload { return ProgressionTarget(reps: nil, weightKg: nil, seconds: max(10, shortest - 10), note: "Deload week: a bit shorter.") }
            if shortest >= target && easyEnough && shortest < 90 {
                return ProgressionTarget(reps: nil, weightKg: nil, seconds: shortest + 5, note: "Five seconds longer than last time.")
            }
            return ProgressionTarget(reps: nil, weightKg: nil, seconds: max(shortest, 10), note: "Hold as long as last time.")
        default:
            return nil
        }
    }

    static func rounded(_ kg: Double, step: Double) -> Double {
        guard step > 0 else { return kg }
        return max(step, (kg / step).rounded() * step)
    }
}

/// Deload weeks: in the building phases (off- and pre-season) every fifth
/// week is lighter, so the body catches up with the work. In season the
/// plan is already maintenance-sized.
public enum Deload {
    public static let cycleWeeks = 5

    /// Whether the week starting `weekStart` is a deload week, counting from
    /// the week the athlete started (`anchor`).
    public static func isDeloadWeek(weekStart: Date, anchor: Date, phase: SeasonPhase, calendar: Calendar = .current) -> Bool {
        guard phase == .offSeason || phase == .preSeason else { return false }
        let start = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
        let weeks = (calendar.dateComponents([.day], from: start, to: weekStart).day ?? 0) / 7
        return weeks > 0 && (weeks + 1) % cycleWeeks == 0
    }

    /// A deload week: one set fewer on everything (at least one), 40% fewer
    /// jumps.
    public static func apply(to week: GeneratedWeek) -> GeneratedWeek {
        let sessions = week.sessions.map { session -> GeneratedSession in
            let items = session.items.map { item -> GeneratedPlannedItem in
                var dose = item.dose
                dose.sets = max(1, dose.sets - 1)
                if dose.kind == plyometricDoseKind, let contacts = dose.contacts { dose.contacts = max(1, contacts * 3 / 5) }
                return GeneratedPlannedItem(itemSlug: item.itemSlug, order: item.order, dose: dose, restSec: item.restSec,
                                            rationale: item.rationale, quality: item.quality)
            }
            let minutes = items.reduce(0) { $0 + PlanGenerator.estimatedMinutes(dose: $1.dose, restSec: $1.restSec) }
            var lighter = GeneratedSession(date: session.date, title: session.title, focusQualities: session.focusQualities,
                                           estimatedMinutes: minutes, items: items)
            lighter.slot = session.slot
            return lighter
        }
        return GeneratedWeek(phase: week.phase, weekStart: week.weekStart, sessions: sessions)
    }
}
