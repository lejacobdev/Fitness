import Foundation

/// "Why this plan?" (docs/VERSION-6.md §9): the decision in plain words. It
/// only explains what SessionPlanner decided — it never decides anything.
/// Copy style (§22): a calm performance coach. Simple, precise.
public struct PlanExplanation: Sendable, Equatable, Codable {
    public struct Part: Sendable, Equatable, Codable {
        public var question: String
        public var answer: String
    }

    /// One or two sentences shown on the workout.
    public var summary: String
    /// The ten questions, answered (§9), for "More about this plan".
    public var parts: [Part]

    public static func make(decision: SessionDecision, day: TrainingDay, items: [GeneratedPlannedItem], catalogue: Catalogue,
                            conditioning: ConditioningPrescription?) -> PlanExplanation {
        let r = Set(decision.reasons)
        let targets = list(decision.primaryTargets.map(\.title))
        var parts: [Part] = []
        func add(_ q: String, _ a: String?) { if let a, !a.isEmpty { parts.append(Part(question: q, answer: a)) } }

        // What practice already did.
        var practiceCovered: String?
        if let practice = day.practice {
            var gave: [String] = []
            if day.demands.practiceLegLoad >= 2 || practice == .hard { gave.append(practice == .hard ? "substantial lower-body" : "lower-body") }
            if day.demands.practiceConditioning >= 2 { gave.append("conditioning") }
            practiceCovered = gave.isEmpty ? "Practice trained your sport skills today." : "Practice already gave you \(list(gave)) load today."
        }

        // Summary.
        var summary: String
        switch decision.sessionType {
        case .afterPractice:
            summary = (practiceCovered ?? "You trained with the team today.") + " "
            summary += decision.legBudget >= 2
                ? "This short session adds \(targets) with only a little leg work, so you still recover."
                : "This short session focuses on \(targets) without adding unnecessary leg fatigue."
        case .gymDevelopment:
            summary = "No practice today, so this is your main development session: \(targets)."
            if r.contains(.gameWithin48h) { summary += " Leg volume is lower because you compete in two days." }
            else if r.contains(.lowerBodyTrainedRecently) { summary += " Your legs worked hard recently, so lower-body lifting is lighter." }
            else if r.contains(.belowNormalReadiness) { summary += " Your check-in was below your normal, so there's less volume today." }
            else if r.contains(.returnAfterIllness) { summary += " You're coming back from being sick, so it's lighter than usual." }
            else if r.contains(.inSeason) { summary += " In season the aim is to keep strength, so sets are lower." }
        case .primer:
            summary = "You compete tomorrow. A short, sharp session keeps you feeling quick without adding fatigue."
        case .conditioning:
            summary = "Your sport isn't giving you enough \((decision.conditioning ?? .aerobicBase).title.lowercased()) right now, so this is a programmed conditioning session."
        case .recovery:
            if r.contains(.gameYesterday) { summary = "You played yesterday. Today is easy movement — recovery is part of the plan." }
            else if r.contains(.reflectionSomethingHurt) { summary = "You said something hurt last night, so today is gentle movement only. If it still hurts, tell a coach or athletic trainer." }
            else if r.contains(.lowReadiness) { summary = "Your check-in says you're well below your normal. Easy movement today is the right call." }
            else if r.contains(.manyDaysInARow) { summary = "You've trained many days in a row. Today is easy, so the hard days keep working." }
            else if r.contains(.returnAfterIllness) { summary = "You're just back from being sick. Easy movement first; training builds back up over the next days." }
            else { summary = "Today is easy movement. Recovery is part of the plan." }
        case .mobility:
            switch decision.mobilityPurpose ?? .targeted {
            case .preTraining: summary = r.contains(.gameToday) ? "Game day: a short movement prep, then save everything for the game." : "Movement prep: raise your temperature and get the joints moving before you train."
            case .targeted: summary = "Range for the areas your sport loads most."
            case .recovery: summary = practiceCovered.map { "\($0) Easy movement now helps you feel fresher tomorrow." } ?? "Easy movement to feel fresher. It isn't training."
            case .eveningDownshift: summary = "A calm few minutes before bed: slower movement and slower breathing."
            }
        case .travel:
            summary = "Away from home: strength with no equipment, so the week stays on track."
        case .rest:
            summary = r.contains(.manyDaysInARow) ? "You've trained many days in a row. Rest today is part of the plan."
                : r.contains(.gameTomorrow) ? "You compete tomorrow. Resting today is the best preparation."
                : "Rest is part of the plan today. Doing nothing is the right thing to do."
        }

        // 1. Why train today?
        add("Why train today?", decision.sessionType == .rest ? "Today is a planned rest day: fitness is built in the recovery between sessions."
            : decision.sessionType == .recovery ? "Easy movement helps you recover faster than lying still. It isn't meant to make you tired."
            : day.practice != nil ? "Practice trains your sport. A short supplement fills what practice doesn't train."
            : "There's no practice today, which makes it the best day for development work.")
        // 2. Why this session type?
        add("Why this kind of session?", sessionTypeReason(decision, r))
        // 3. Why this duration?
        add("Why this long?", durationReason(decision, day, r))
        // 4. Why these qualities?
        if !decision.primaryTargets.isEmpty {
            var answer = "Main focus: \(targets)."
            if !decision.maintain.isEmpty { answer += " Kept up with less volume: \(list(decision.maintain.map(\.title)))." }
            add("Why these qualities?", answer)
        }
        // 5. Why these exercises?
        let byBlock = Dictionary(grouping: items.filter { $0.block != nil }, by: { $0.block! })
        let exercises = SessionBlock.allCases.compactMap { block -> String? in
            guard let picked = byBlock[block], let first = picked.first else { return nil }
            let names = picked.compactMap { catalogue.item($0.itemSlug)?.name }
            return "\(block.title) — \(list(names)): \(first.rationale)"
        }
        add("Why these exercises?", exercises.joined(separator: "\n"))
        // 6. Why this order?
        if items.count > 2 {
            add("Why this order?", "Fast and explosive work first, while you're fresh. Then the heaviest strength work, then smaller exercises\(decision.conditioning != nil ? ", and conditioning last so it doesn't blunt the strength work" : "").")
        }
        // 7. What did practice already train?
        add("What did practice already train?", practiceCovered)
        // 8. What are we avoiding?
        if !decision.avoidToday.isEmpty {
            add("What are we avoiding today?", "Not today: \(list(decision.avoidToday.map(\.phrase))). Good exercise, wrong day.")
        }
        // 9. How does it fit your goals?
        if !day.goals.isEmpty {
            let hits = day.goals.filter { decision.primaryTargets.contains($0) || decision.maintain.contains($0) }
            add("How does it fit your goals?", hits.isEmpty
                ? "Your goal of \(day.goals[0].title) gets its turn on another day this week — today's job is different."
                : "It trains \(list(hits.map(\.title))), which you chose as a development goal.")
        }
        // 10. How does it progress?
        add("How does this build on last time?", progression(decision, day))
        if let conditioning {
            add("Conditioning", "\(conditioning.type.title): \(conditioning.summary).")
        }
        return PlanExplanation(summary: summary, parts: parts)
    }

    static func sessionTypeReason(_ d: SessionDecision, _ r: Set<PlanReason>) -> String {
        switch d.sessionType {
        case .afterPractice: return "After practice your legs and lungs have worked. Upper-body strength, trunk and small injury-prevention work are what's missing."
        case .gymDevelopment: return "A day without practice or a game coming up: the time to build strength and power."
        case .primer: return "The day before competition: short, fast and light, so you feel sharp — not tired."
        case .conditioning: return r.contains(.sportProvidesConditioning) ? "Practice gives some conditioning, but not the kind your sport needs most." : "Your sport's practice doesn't build the fitness you need, so it's programmed here."
        case .recovery: return "Hard days only work if easy days are really easy."
        case .mobility: return "Mobility with a purpose: \((d.mobilityPurpose ?? .targeted).title.lowercased())."
        case .travel: return "No gym on the road, so bodyweight strength keeps the habit."
        case .rest: return "Rest is when the body adapts to the training."
        }
    }

    static func durationReason(_ d: SessionDecision, _ day: TrainingDay, _ r: Set<PlanReason>) -> String {
        guard d.durationTarget > 0 else { return "No session today." }
        var why: [String] = []
        switch d.sessionType {
        case .afterPractice: why.append("after practice, 15–35 minutes is enough")
        case .gymDevelopment: why.append("a development day is usually 45–75 minutes")
        default: break
        }
        if r.contains(.inSeason) { why.append("in season it's shorter") }
        if r.contains(.offSeason), d.sessionType == .gymDevelopment { why.append("the off-season has room for more") }
        if r.contains(.beginner) { why.append("you're new to lifting, so less is more") }
        if r.contains(.gameWithin48h) || r.contains(.gameTomorrow) { why.append("competition is close") }
        if r.contains(.belowNormalReadiness) { why.append("your check-in was below normal") }
        if r.contains(.examOrLongDay) { why.append("it's a long school day") }
        if r.contains(.limitedTime) { why.append("you have limited time") }
        return "About \(d.durationTarget) minutes: " + (why.isEmpty ? "the right amount for today" : why.joined(separator: "; ")) + "."
    }

    static func progression(_ d: SessionDecision, _ day: TrainingDay) -> String? {
        guard [.gymDevelopment, .afterPractice].contains(d.sessionType) else { return nil }
        var parts: [String] = []
        if let lower = d.lowerPattern, d.legBudget >= 2 {
            parts.append(day.recent.lastLowerPattern == nil ? "The first \(lower) session of the week."
                : "Last time the main leg exercise was a \(day.recent.lastLowerPattern!); today it's a \(lower), so both get trained each week.")
        }
        if let upper = d.upperPattern {
            parts.append("The main upper-body pattern is \(upper)\(day.recent.lastUpperPattern.map { $0 != upper ? " (last time: \($0))" : "" } ?? "").")
        }
        parts.append("When every set feels smooth, add a little weight or a couple of reps next time.")
        return parts.joined(separator: " ")
    }

    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }
}
