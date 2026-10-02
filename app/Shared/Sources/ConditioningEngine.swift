import Foundation

/// A programmed conditioning prescription (docs/VERSION-6.md §5): what to
/// do, how hard, how long, and why — never "some cardio".
public struct ConditioningPrescription: Sendable, Equatable {
    public var type: ConditioningType
    public var itemSlug: String
    /// Total work intervals (a continuous session is 1).
    public var reps: Int
    public var workSeconds: Int
    public var restSeconds: Int
    /// Blocks of reps with a longer break between (repeated sprints).
    public var blocks: Int
    public var blockRestSeconds: Int
    /// How hard, in words an athlete can use.
    public var intensity: String
    public var minutes: Int

    /// "2 × 6 × 6 s fast, 20 s easy between, 3 min between sets"
    public var summary: String {
        if reps == 1 { return "\(workSeconds / 60) min continuous — \(intensity)" }
        let work = workSeconds >= 60 ? "\(workSeconds / 60) min" : "\(workSeconds) s"
        let rest = restSeconds >= 60 ? "\(restSeconds / 60) min" : "\(restSeconds) s"
        let perBlock = reps / max(blocks, 1)
        let structure = blocks > 1 ? "\(blocks) sets × \(perBlock) × \(work)" : "\(reps) × \(work)"
        let between = blocks > 1 ? ", \(blockRestSeconds / 60) min between sets" : ""
        return "\(structure), \(rest) easy between\(between) — \(intensity)"
    }
}

public enum ConditioningEngine {
    /// The protocol for `type` that fits in `minutes`, using what the athlete
    /// can do (`usable`), with low-impact options when impact is limited.
    public static func prescribe(_ type: ConditioningType, minutes: Int, lowImpact: Bool, age: Int,
                                 experience: TrainingExperience, usable: (String) -> Bool) -> ConditioningPrescription? {
        let minutes = max(6, minutes)
        func first(_ slugs: [String]) -> String? { slugs.first(where: usable) }
        let youngOrNew = age < 14 || experience == .beginner

        switch type {
        case .aerobicBase:
            // Long and easy: you can talk in full sentences.
            guard let slug = first(lowImpact ? ["easy-bike-ride", "rowing-machine-intervals", "continuous-easy-run"]
                                             : ["continuous-easy-run", "easy-bike-ride", "fartlek-run", "long-easy-run"]) else { return nil }
            let total = min(minutes, youngOrNew ? 25 : 40)
            return ConditioningPrescription(type: type, itemSlug: slug, reps: 1, workSeconds: total * 60, restSeconds: 0, blocks: 1,
                                            blockRestSeconds: 0, intensity: "easy, you can talk in full sentences", minutes: total)
        case .aerobicPower:
            // Hard but steady intervals with equal or shorter rest.
            if !lowImpact, !youngOrNew, let slug = first(["30-15-intermittent-run"]) {
                let reps = min(24, max(8, minutes * 60 / 45))
                return ConditioningPrescription(type: type, itemSlug: slug, reps: reps, workSeconds: 30, restSeconds: 15, blocks: reps >= 16 ? 2 : 1,
                                                blockRestSeconds: 180, intensity: "hard but steady — the last rep as fast as the first",
                                                minutes: reps * 45 / 60 + (reps >= 16 ? 3 : 0))
            }
            guard let slug = first(lowImpact ? ["bike-intervals", "rowing-machine-intervals", "jump-rope-intervals"]
                                             : ["bike-intervals", "jump-rope-intervals", "rowing-machine-intervals", "box-step-over-conditioning", "30-15-intermittent-run"]) else { return nil }
            let reps = min(10, max(4, minutes / 2))
            return ConditioningPrescription(type: type, itemSlug: slug, reps: reps, workSeconds: 60, restSeconds: 60, blocks: 1, blockRestSeconds: 0,
                                            intensity: "hard — about 8 out of 10, breathing hard but in control", minutes: reps * 2)
        case .tempo:
            // Controlled running: about 70% of top speed, walk back.
            guard let slug = first(lowImpact ? ["bike-intervals", "rowing-machine-intervals"] : ["tempo-200s", "tempo-run", "bike-intervals"]) else { return nil }
            let reps = min(12, max(6, minutes * 60 / 90))
            return ConditioningPrescription(type: type, itemSlug: slug, reps: reps, workSeconds: 30, restSeconds: 60, blocks: reps >= 10 ? 2 : 1,
                                            blockRestSeconds: 120, intensity: "smooth, about 70% of your top speed", minutes: reps * 90 / 60 + 2)
        case .repeatedSprint:
            // Fast efforts, short rest, a long break between sets.
            guard !lowImpact else {
                return prescribe(.aerobicPower, minutes: minutes, lowImpact: true, age: age, experience: experience, usable: usable)
            }
            guard let slug = first(["shuttle-repeat-sprints", "repeat-shuttle-10m", "in-place-suicide-sprints", "bike-intervals"]) else { return nil }
            let blocks = youngOrNew || minutes < 12 ? 2 : 3
            let perBlock = 6
            return ConditioningPrescription(type: type, itemSlug: slug, reps: blocks * perBlock, workSeconds: 6, restSeconds: 20, blocks: blocks,
                                            blockRestSeconds: 180, intensity: "fast — near full speed, stop the set if you slow down a lot",
                                            minutes: blocks * (perBlock * 26 / 60 + 3))
        case .anaerobic:
            guard let slug = first(lowImpact ? ["bike-intervals", "battle-rope-waves", "rowing-machine-intervals"]
                                             : ["hill-sprint-repeats", "bike-intervals", "stair-runs", "burpee"]) else { return nil }
            let reps = youngOrNew ? 5 : min(8, max(5, minutes / 2))
            return ConditioningPrescription(type: type, itemSlug: slug, reps: reps, workSeconds: 15, restSeconds: 90, blocks: 1, blockRestSeconds: 0,
                                            intensity: "very hard for 15 seconds, then walk until your breathing settles", minutes: reps * 105 / 60 + 1)
        case .recovery:
            guard let slug = first(["easy-bike-ride", "continuous-easy-run", "rowing-machine-intervals"]) else { return nil }
            let total = min(minutes, 20)
            return ConditioningPrescription(type: type, itemSlug: slug, reps: 1, workSeconds: total * 60, restSeconds: 0, blocks: 1, blockRestSeconds: 0,
                                            intensity: "very easy — an easy bike, walk or swim; you should feel better after", minutes: total)
        }
    }
}
