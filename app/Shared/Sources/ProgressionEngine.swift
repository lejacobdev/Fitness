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

/// Where an exercise is (Backend Knowledge System §14): progress follows
/// steady sessions, not the passing of time; pain pauses it.
public enum ProgressionState: String, Sendable, Equatable {
    case introduce, consolidate, progress, hold, pauseForReview, deload
}

/// What to aim for this time, and one short line saying why.
public struct ProgressionTarget: Sendable, Equatable {
    public var reps: Int?
    public var weightKg: Double?
    public var seconds: Int?
    public var note: String
    public var state: ProgressionState = .hold
}

/// Progressive overload, the conservative way: one variable steps up only
/// after two steady sessions in a row — every set reached the target and
/// neither session was maximal (RPE 9–10). One steady session consolidates;
/// missed reps hold; reported pain pauses progression. Bodyweight moves add
/// a rep, holds add five seconds. A deload week takes a little off.
public enum ProgressionEngine {
    public static func next(
        last sets: [LoggedSet], dose: Dose, sessionRPE: Int?, isYouth: Bool, stepKg: Double, deload: Bool = false,
        previous: [LoggedSet]? = nil, previousRPE: Int? = nil, painInArea: Bool = false
    ) -> ProgressionTarget? {
        guard !sets.isEmpty else { return nil }
        func steady(_ sets: [LoggedSet], _ rpe: Int?) -> Bool {
            guard (rpe ?? 7) <= 8, !sets.isEmpty else { return false }
            switch dose.kind {
            case "reps":
                let target = dose.reps ?? sets.compactMap(\.reps).max() ?? 8
                return sets.allSatisfy { ($0.reps ?? 0) >= target }
            case "time":
                let target = dose.seconds ?? 30
                return sets.allSatisfy { ($0.seconds ?? 0) >= target }
            default:
                return false
            }
        }
        let steadyNow = steady(sets, sessionRPE)
        let twoSteady = steadyNow && previous.map { steady($0, previousRPE) } == true
        // Why it doesn't step up: pain first, then not enough steady sessions.
        func holding(_ reps: Int?, _ kg: Double?, _ secs: Int?, _ same: String) -> ProgressionTarget {
            if painInArea {
                return ProgressionTarget(reps: reps, weightKg: kg, seconds: secs,
                                         note: "Pain reported: no step up today. Stop if it hurts.", state: .pauseForReview)
            }
            if steadyNow {
                return ProgressionTarget(reps: reps, weightKg: kg, seconds: secs,
                                         note: "Steady last time. One more steady session, then a step up.",
                                         state: previous == nil ? .introduce : .consolidate)
            }
            return ProgressionTarget(reps: reps, weightKg: kg, seconds: secs, note: same, state: .hold)
        }
        switch dose.kind {
        case "reps":
            let target = dose.reps ?? sets.compactMap(\.reps).max() ?? 8
            let weight = sets.compactMap(\.weightKg).max() ?? 0
            if weight > 0 {
                if deload {
                    return ProgressionTarget(reps: target, weightKg: rounded(weight * 0.9, step: stepKg), seconds: nil,
                                             note: "Deload week: a bit lighter on purpose.", state: .deload)
                }
                if twoSteady && !painInArea {
                    return ProgressionTarget(reps: target, weightKg: weight + stepKg, seconds: nil,
                                             note: "Two steady sessions in a row: one step heavier.", state: .progress)
                }
                return holding(target, weight, nil, "Same weight: aim for \(target) on every set.")
            }
            let best = sets.compactMap(\.reps).min() ?? target
            if deload { return ProgressionTarget(reps: max(1, best - 2), weightKg: nil, seconds: nil, note: "Deload week: a few reps fewer.", state: .deload) }
            let cap = isYouth ? 15 : 20
            if twoSteady && !painInArea && best < cap {
                return ProgressionTarget(reps: best + 1, weightKg: nil, seconds: nil, note: "Two steady sessions: one more rep.", state: .progress)
            }
            return holding(max(best, target), nil, nil, "Match last time with clean reps.")
        case "time":
            let target = dose.seconds ?? 30
            let shortest = sets.compactMap(\.seconds).min() ?? target
            if deload { return ProgressionTarget(reps: nil, weightKg: nil, seconds: max(10, shortest - 10), note: "Deload week: a bit shorter.", state: .deload) }
            if twoSteady && !painInArea && shortest < 90 {
                return ProgressionTarget(reps: nil, weightKg: nil, seconds: shortest + 5, note: "Two steady sessions: five seconds longer.", state: .progress)
            }
            return holding(nil, nil, max(shortest, 10), "Hold as long as last time.")
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
                var lighterItem = GeneratedPlannedItem(itemSlug: item.itemSlug, order: item.order, dose: dose, restSec: item.restSec,
                                                       rationale: item.rationale, quality: item.quality)
                lighterItem.block = item.block
                return lighterItem
            }
            let minutes = session.decision != nil
                ? max(5, items.reduce(0) { $0 + SessionBuilder.seconds($1) } / 60)
                : items.reduce(0) { $0 + PlanGenerator.estimatedMinutes(dose: $1.dose, restSec: $1.restSec) }
            var lighter = GeneratedSession(date: session.date, title: session.title, focusQualities: session.focusQualities,
                                           estimatedMinutes: minutes, items: items)
            lighter.slot = session.slot
            lighter.decision = session.decision
            lighter.explanation = session.explanation
            return lighter
        }
        return GeneratedWeek(phase: week.phase, weekStart: week.weekStart, sessions: sessions)
    }
}
