import Foundation
import SwiftData

/// §12's coach engine. "No model, no API, no cost." The engines decide what
/// is true; this decides what to say first and how to word it, from a bank of
/// reviewed templates — so it can never invent a drill, a number, a diagnosis
/// or the injury-risk language §11 forbids.
///
/// Also carries the original app idea's "lately you've only trained arms —
/// try core or legs": muscle balance is computed from the sets actually
/// logged, mapped through each item's own muscle weights.

// MARK: - Inputs and outputs

public struct CoachSet: Sendable {
    public let itemSlug: String
    public let reps: Int?
    public let weightKg: Double?

    public init(itemSlug: String, reps: Int? = nil, weightKg: Double? = nil) {
        self.itemSlug = itemSlug
        self.reps = reps
        self.weightKg = weightKg
    }
}

public struct CoachSession: Sendable {
    public let date: Date
    public let minutes: Int
    public let rpe: Int?
    public let sets: [CoachSet]

    public init(date: Date, minutes: Int, rpe: Int?, sets: [CoachSet]) {
        self.date = date
        self.minutes = minutes
        self.rpe = rpe
        self.sets = sets
    }
}

public struct CoachInput: Sendable {
    public let athleteId: String
    public let now: Date
    public let positionName: String?
    public let sportQualityProfile: [String: Double]
    public let sessions: [CoachSession]
    public let checkIns: [CheckInAnswers]
    public let plannedSessionsLastWeek: Int
    public let catalogue: Catalogue
    /// findingCode → the template index used in last week's report, so two
    /// consecutive weeks never read identically (§12).
    public let previousTemplateIndexes: [String: Int]

    public init(
        athleteId: String, now: Date = .now, positionName: String? = nil, sportQualityProfile: [String: Double],
        sessions: [CoachSession], checkIns: [CheckInAnswers], plannedSessionsLastWeek: Int,
        catalogue: Catalogue, previousTemplateIndexes: [String: Int] = [:]
    ) {
        self.athleteId = athleteId
        self.now = now
        self.positionName = positionName
        self.sportQualityProfile = sportQualityProfile
        self.sessions = sessions
        self.checkIns = checkIns
        self.plannedSessionsLastWeek = plannedSessionsLastWeek
        self.catalogue = catalogue
        self.previousTemplateIndexes = previousTemplateIndexes
    }
}

public struct CoachRecommendation: Sendable, Equatable, Codable {
    public let itemSlug: String
    public let reason: String
}

public struct CoachReportContent: Sendable, Equatable {
    public let headline: String
    public let headlineCode: String
    public let observations: [String]
    public let recommendations: [CoachRecommendation]
    public let encouragement: String
    public let templateIndexes: [String: Int]
    /// Share of the last 14 days' logged volume per body region, 0...1.
    public let muscleBalance: [MuscleRegion: Double]
}

// MARK: - The engine

public enum CoachEngine {
    public static let templateSetVersion = 1

    /// The big regions a balanced programme should touch every fortnight.
    static let majorRegions: [MuscleRegion] = [.chest, .upperBack, .shoulder, .arm, .trunk, .hip, .quadriceps, .hamstrings, .calf]

    struct Finding {
        let code: String
        let score: Double
        let tier: Int
        let topic: String
        let slots: [String: String]
        let recommendationRegion: MuscleRegion?
        let recommendationQuality: String?
    }

    public static func report(_ input: CoachInput) -> CoachReportContent {
        let calendar = Calendar.current
        let balance = muscleBalance(sessions: input.sessions, catalogue: input.catalogue, now: input.now)
        var findings = candidateFindings(input, balance: balance, calendar: calendar)
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.code < $1.code }

        if findings.isEmpty {
            findings = [Finding(code: "getting-started", score: 1, tier: 0, topic: "start", slots: [:], recommendationRegion: nil, recommendationQuality: nil)]
        }

        // Pick: headline, then up to two observations on different topics.
        var picked: [Finding] = []
        var topics = Set<String>()
        for finding in findings where !topics.contains(finding.topic) {
            picked.append(finding)
            topics.insert(finding.topic)
            if picked.count == 3 { break }
        }

        var indexes: [String: Int] = [:]
        let isoWeek = calendar.component(.weekOfYear, from: input.now)
        let lines = picked.map { finding -> String in
            let pool = CoachTemplates.pool(code: finding.code, tier: finding.tier)
            let index = templateIndex(
                poolSize: pool.count, seed: "\(input.athleteId)-\(isoWeek)-\(finding.code)",
                avoiding: input.previousTemplateIndexes[finding.code]
            )
            indexes[finding.code] = index
            return CoachTemplates.render(pool[index], slots: finding.slots)
        }

        let recommendations = recommend(for: picked, input: input)
        let mood = weekMood(picked)
        let encouragementPool = CoachTemplates.encouragement[mood] ?? []
        let encouragementIndex = templateIndex(
            poolSize: encouragementPool.count, seed: "\(input.athleteId)-\(isoWeek)-encouragement-\(mood)",
            avoiding: input.previousTemplateIndexes["encouragement-\(mood)"]
        )
        indexes["encouragement-\(mood)"] = encouragementIndex

        return CoachReportContent(
            headline: lines[0], headlineCode: picked[0].code,
            observations: Array(lines.dropFirst()),
            recommendations: recommendations,
            encouragement: encouragementPool.isEmpty ? "" : encouragementPool[encouragementIndex],
            templateIndexes: indexes,
            muscleBalance: balance
        )
    }

    // MARK: Scoring

    /// §12: "a fixed severity weight multiplied by a streak multiplier,
    /// 1 + 0.3 × min(consecutiveWeeks, 4)... Good news carries a fixed high
    /// score so it is never buried under a warning."
    static func score(severity: Double, consecutiveWeeks: Int) -> Double {
        severity * (1 + 0.3 * Double(min(consecutiveWeeks, 4)))
    }

    static func tier(forWeeks weeks: Int) -> Int {
        weeks >= 4 ? 2 : (weeks >= 2 ? 1 : 0)
    }

    static let goodNewsScore = 9.0

    static func candidateFindings(_ input: CoachInput, balance: [MuscleRegion: Double], calendar: Calendar) -> [Finding] {
        var findings: [Finding] = []
        let today = calendar.startOfDay(for: input.now)
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let recent = input.sessions.filter { $0.date >= twoWeeksAgo }
        let recentSetCount = recent.reduce(0) { $0 + $1.sets.count }

        // 1. Muscle balance — "you've mostly trained arms, try legs".
        if recentSetCount >= 6, let dominant = balance.max(by: { $0.value < $1.value }), dominant.value >= 0.35 {
            // Prefer a skipped region the library can actually do something
            // about, so the headline always comes with a recommendation.
            let neglected = majorRegions.filter { (balance[$0] ?? 0) == 0 }
            let libraryItems = Array(input.catalogue.itemsBySlug.values)
            let actionable = neglected.first { region in libraryItems.contains { regions(of: $0).contains(region) } }
            if let first = actionable ?? neglected.first {
                let weeks = weeksUntrained(region: first, input: input, calendar: calendar)
                findings.append(Finding(
                    code: "neglected-region", score: score(severity: 6, consecutiveWeeks: weeks), tier: tier(forWeeks: weeks),
                    topic: "region-\(first.rawValue)",
                    slots: ["dominant": dominant.key.coachName, "neglected": first.coachName, "weeks": "\(max(weeks, 2))"],
                    recommendationRegion: first, recommendationQuality: nil
                ))
            }
        }

        // 2. The sport's most important quality, untrained lately.
        let trainedQualities = qualitiesTrained(sessions: recent, catalogue: input.catalogue)
        if let top = input.sportQualityProfile.sorted(by: { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }).first(where: { !trainedQualities.contains($0.key) }),
           let quality = qualitiesBySlug[top.key], !recent.isEmpty {
            let weeks = weeksUntrained(quality: top.key, input: input, calendar: calendar)
            findings.append(Finding(
                code: "neglected-quality", score: score(severity: 5 * top.value, consecutiveWeeks: weeks), tier: tier(forWeeks: weeks),
                topic: "quality-\(top.key)",
                slots: ["quality": quality.name.lowercased(), "position": input.positionName?.lowercased() ?? "your sport", "weeks": "\(max(weeks, 2))"],
                recommendationRegion: nil, recommendationQuality: top.key
            ))
        }

        // 3. Load spike (§11 framing — load, never injury).
        let load = LoadCalculator.summarize(input.sessions.map { LoadSample(date: $0.date, minutes: $0.minutes, rpe: $0.rpe) }, now: input.now, calendar: calendar)
        if load.isSharpJump, let change = load.change {
            findings.append(Finding(
                code: "load-spike", score: score(severity: 7, consecutiveWeeks: 0), tier: 0, topic: "load",
                slots: ["percent": "\(Int((change * 100).rounded()))"], recommendationRegion: nil, recommendationQuality: nil
            ))
        }

        // 4. Sleep — "the one thing that actually moves" (§11).
        let lastWeekCheckIns = input.checkIns.filter { $0.date >= (calendar.date(byAdding: .day, value: -7, to: today) ?? today) }
        if lastWeekCheckIns.count >= 3 {
            let averageSleep = Double(lastWeekCheckIns.reduce(0) { $0 + $1.sleepQuality }) / Double(lastWeekCheckIns.count)
            if averageSleep <= 2.5 {
                findings.append(Finding(
                    code: "sleep-low", score: score(severity: 6.5, consecutiveWeeks: 0), tier: 0, topic: "sleep",
                    slots: [:], recommendationRegion: nil, recommendationQuality: nil
                ))
            }
            // 5. §13: very low energy alongside a heavy week → eat more, talk to an adult.
            let averageEnergy = Double(lastWeekCheckIns.reduce(0) { $0 + $1.energy }) / Double(lastWeekCheckIns.count)
            if averageEnergy <= 2, load.acute >= 1200 {
                findings.append(Finding(
                    code: "under-fuelling", score: score(severity: 7.5, consecutiveWeeks: 0), tier: 0, topic: "fuel",
                    slots: [:], recommendationRegion: nil, recommendationQuality: nil
                ))
            }
        }

        // 6. Last week's sessions vs. plan.
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: calendar.dateInterval(of: .weekOfYear, for: input.now)?.start ?? today) ?? today
        let lastWeekEnd = calendar.date(byAdding: .day, value: 7, to: lastWeekStart) ?? today
        let doneLastWeek = input.sessions.filter { $0.date >= lastWeekStart && $0.date < lastWeekEnd }.count
        if input.plannedSessionsLastWeek > 0 {
            if doneLastWeek >= input.plannedSessionsLastWeek {
                findings.append(Finding(
                    code: "full-week", score: goodNewsScore, tier: 0, topic: "week",
                    slots: ["done": "\(doneLastWeek)"], recommendationRegion: nil, recommendationQuality: nil
                ))
            } else if doneLastWeek * 2 < input.plannedSessionsLastWeek, !input.sessions.isEmpty {
                findings.append(Finding(
                    code: "missed-sessions", score: score(severity: 4, consecutiveWeeks: 0), tier: 0, topic: "week",
                    slots: ["done": "\(doneLastWeek)", "planned": "\(input.plannedSessionsLastWeek)"],
                    recommendationRegion: nil, recommendationQuality: nil
                ))
            }
        }

        // 7. Personal best in the last 7 days.
        if let best = personalBest(input: input, calendar: calendar) {
            findings.append(Finding(
                code: "personal-best", score: goodNewsScore + 0.5, tier: 0, topic: "best",
                slots: ["exercise": best.name, "weight": best.weight], recommendationRegion: nil, recommendationQuality: nil
            ))
        }

        // 8. A consistency streak.
        let streakDays = consecutiveActiveDays(input: input, calendar: calendar)
        if streakDays >= 3 {
            findings.append(Finding(
                code: "streak", score: goodNewsScore - 0.5, tier: 0, topic: "streak",
                slots: ["days": "\(streakDays)"], recommendationRegion: nil, recommendationQuality: nil
            ))
        }

        return findings
    }

    // MARK: Muscle balance

    /// Share of logged volume per region over the last 14 days. Each set
    /// contributes its item's muscle weights, so a trap-bar deadlift counts
    /// mostly toward hips and hamstrings, a little toward the back.
    public static func muscleBalance(sessions: [CoachSession], catalogue: Catalogue, now: Date = .now, days: Int = 14) -> [MuscleRegion: Double] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) ?? now
        var totals: [MuscleRegion: Double] = [:]
        for session in sessions where session.date >= cutoff {
            for set in session.sets {
                guard let item = catalogue.item(set.itemSlug) else { continue }
                for (muscle, weight) in item.muscles {
                    guard let region = musclesBySlug[muscle]?.region else { continue }
                    totals[region, default: 0] += weight
                }
            }
        }
        let sum = totals.values.reduce(0, +)
        guard sum > 0 else { return [:] }
        return totals.mapValues { $0 / sum }
    }

    static func regions(of item: CatalogueItem) -> Set<MuscleRegion> {
        Set(item.muscles.filter { $0.value >= 0.5 }.compactMap { musclesBySlug[$0.key]?.region })
    }

    static func qualitiesTrained(sessions: [CoachSession], catalogue: Catalogue) -> Set<String> {
        var trained = Set<String>()
        for session in sessions {
            for set in session.sets {
                guard let item = catalogue.item(set.itemSlug) else { continue }
                trained.formUnion(item.qualities.filter { $0.value >= 0.7 }.keys)
            }
        }
        return trained
    }

    static func weeksUntrained(region: MuscleRegion, input: CoachInput, calendar: Calendar) -> Int {
        weeksSince(input: input, calendar: calendar) { set in
            input.catalogue.item(set.itemSlug).map { regions(of: $0).contains(region) } ?? false
        }
    }

    static func weeksUntrained(quality: String, input: CoachInput, calendar: Calendar) -> Int {
        weeksSince(input: input, calendar: calendar) { set in
            (input.catalogue.item(set.itemSlug)?.qualities[quality] ?? 0) >= 0.7
        }
    }

    /// Whole weeks (capped at 4) since a set matching `matches` was logged —
    /// the "consecutiveWeeks" that escalates a finding's tone (§12).
    static func weeksSince(input: CoachInput, calendar: Calendar, matches: (CoachSet) -> Bool) -> Int {
        let last = input.sessions.filter { $0.sets.contains(where: matches) }.map(\.date).max()
        guard let last else {
            let earliest = input.sessions.map(\.date).min() ?? input.now
            return min(4, (calendar.dateComponents([.day], from: earliest, to: input.now).day ?? 0) / 7)
        }
        return min(4, (calendar.dateComponents([.day], from: last, to: input.now).day ?? 0) / 7)
    }

    static func personalBest(input: CoachInput, calendar: Calendar) -> (name: String, weight: String)? {
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: input.now) ?? input.now
        var bestBefore: [String: Double] = [:]
        var bestRecent: [String: Double] = [:]
        for session in input.sessions {
            for set in session.sets {
                guard let weight = set.weightKg, weight > 0 else { continue }
                if session.date >= weekAgo {
                    bestRecent[set.itemSlug] = max(bestRecent[set.itemSlug] ?? 0, weight)
                } else {
                    bestBefore[set.itemSlug] = max(bestBefore[set.itemSlug] ?? 0, weight)
                }
            }
        }
        let improvements = bestRecent.compactMap { slug, weight -> (String, Double, Double)? in
            guard let previous = bestBefore[slug], weight > previous else { return nil }
            return (slug, weight, weight - previous)
        }
        guard let top = improvements.max(by: { $0.2 < $1.2 }) else { return nil }
        let name = input.catalogue.item(top.0)?.name ?? displayName(forSlug: top.0)
        return (name, top.1.formatted(.number.precision(.fractionLength(0...1))) + " kg")
    }

    static func consecutiveActiveDays(input: CoachInput, calendar: Calendar) -> Int {
        let active = Set((input.sessions.map(\.date) + input.checkIns.map(\.date)).map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: input.now)
        if !active.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var count = 0
        while active.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    // MARK: Picking and rendering

    /// §12: "seeded on hash(userId + isoWeek + findingCode) so it is
    /// reproducible and testable, and the index used last week for that
    /// finding is excluded."
    static func templateIndex(poolSize: Int, seed: String, avoiding previous: Int?) -> Int {
        guard poolSize > 0 else { return 0 }
        var rng = SeededGenerator(seed: seed)
        var index = Int(rng.next() % UInt64(poolSize))
        if poolSize > 1, index == previous {
            index = (index + 1) % poolSize
        }
        return index
    }

    /// Up to three items the library already has — "this engine never
    /// chooses an exercise itself" beyond ranking what the catalogue offers
    /// for the finding in question.
    static func recommend(for findings: [Finding], input: CoachInput) -> [CoachRecommendation] {
        var result: [CoachRecommendation] = []
        var used = Set<String>()
        let items = input.catalogue.itemsBySlug.values.sorted { $0.slug < $1.slug }
        for finding in findings {
            if let region = finding.recommendationRegion {
                let matches = items
                    .filter { regions(of: $0).contains(region) && !used.contains($0.slug) }
                    .sorted { regionWeight($0, region) > regionWeight($1, region) }
                for item in matches.prefix(2) {
                    result.append(CoachRecommendation(itemSlug: item.slug, reason: "Trains your \(region.coachName)."))
                    used.insert(item.slug)
                }
            }
            if let quality = finding.recommendationQuality {
                let matches = items
                    .filter { ($0.qualities[quality] ?? 0) >= 0.7 && !used.contains($0.slug) }
                    .sorted { ($0.qualities[quality] ?? 0) > ($1.qualities[quality] ?? 0) }
                for item in matches.prefix(2) {
                    let name = qualitiesBySlug[quality]?.name.lowercased() ?? quality
                    result.append(CoachRecommendation(itemSlug: item.slug, reason: "Builds \(name)."))
                    used.insert(item.slug)
                }
            }
            if result.count >= 3 { break }
        }
        return Array(result.prefix(3))
    }

    static func regionWeight(_ item: CatalogueItem, _ region: MuscleRegion) -> Double {
        item.muscles.filter { musclesBySlug[$0.key]?.region == region }.values.reduce(0, +)
    }

    static func weekMood(_ findings: [Finding]) -> String {
        let good: Set<String> = ["full-week", "personal-best", "streak"]
        let goodCount = findings.filter { good.contains($0.code) }.count
        if goodCount == findings.count { return "good" }
        return goodCount > 0 ? "mixed" : "poor"
    }
}

// MARK: - Template bank

/// Every sentence the coach can say. Written for a 15-year-old in a locker
/// room. §11/§13's lint rule runs over this whole bank in the test suite: no
/// template may mention injury, risk, damage, safe/unsafe, or anything
/// about weight loss, body shape or appearance.
public enum CoachTemplates {
    /// findingCode → streak tier (0 first time, 1 two-three weeks, 2 four+)
    /// → a pool of 4–6 sentences.
    public static let bank: [String: [[String]]] = [
        "neglected-region": [
            [
                "Most of your recent sets went to your {dominant}, and none to your {neglected}. Add some {neglected} work this week.",
                "Plenty of {dominant} work lately. Zero {neglected} work. Balance it out with a couple of exercises.",
                "Nice volume on your {dominant}. Next up: {neglected} work, which you've skipped for two weeks.",
                "Your training has leaned hard on your {dominant}. Add some {neglected} work so your whole body keeps up.",
            ],
            [
                "It's been about {weeks} weeks since any {neglected} work, while {dominant} work gets it all. Time to switch it up.",
                "{weeks} weeks without {neglected} work now. Give the rest of your body some attention this week.",
                "No {neglected} work for {weeks} weeks straight. Start your next session with it.",
                "Still no {neglected} work in {weeks} weeks. A balanced body moves better — add two exercises for it next time.",
            ],
            [
                "A month with zero {neglected} work while {dominant} work gets everything. This is the one thing to fix this week.",
                "Four weeks, no {neglected} work. That gap is now the biggest thing holding your training back — make it the first thing you do next session.",
                "Your {neglected} training has been left out for a month. Put it at the top of your next three sessions.",
                "It's been four weeks without {neglected} work. Today's the day to change that.",
            ],
        ],
        "neglected-quality": [
            [
                "You haven't trained {quality} lately — for {position}, that's a quality your game leans on.",
                "No {quality} work in the last two weeks. For {position}, it's one of the things that matters most.",
                "Your plan is missing {quality} lately. Add a little back in — {position} needs it.",
                "Quick gap to close: {quality}. It's high on the list for {position}.",
            ],
            [
                "You've trained {quality} once or less in {weeks} weeks — for {position}, that's the quality your game leans on most.",
                "{weeks} weeks light on {quality}. For {position}, that's worth fixing this week.",
                "{quality} keeps slipping off your list — {weeks} weeks now. Your game will notice.",
                "It's been {weeks} weeks since real {quality} work. Put one exercise for it in every session this week.",
            ],
            [
                "A month without {quality}. For {position}, that's the biggest gap in your training right now.",
                "Four weeks and no {quality}. Make it the first thing in every session until it's back.",
                "{quality} has been missing for a month. This week, it's non-negotiable.",
                "A whole month light on {quality} — for {position}, closing this gap will pay off fastest.",
            ],
        ],
        "load-spike": [[
            "Your training load is up {percent}% on your four-week average — that's a big jump. Consider easing the next couple of days.",
            "This week's load is {percent}% above your usual. Big jumps are worth smoothing out — keep the next two days lighter.",
            "You've added {percent}% on top of your normal week. Nice effort — now let your body catch up with an easier couple of days.",
            "Load is up {percent}% on your four-week average. Hold it steady rather than pushing higher this week.",
        ]],
        "sleep-low": [[
            "Your sleep scores have been low all week. Sleep is where training turns into progress — aim for an earlier night tonight.",
            "You've been sleeping badly this week. Teens need 8–10 hours; getting closer to that will help more than any extra session.",
            "Rough sleep all week. Try putting the phone away 30 minutes earlier — it's the easiest win you've got.",
            "Low sleep scores this week. Nothing you do in the gym beats a good night's sleep for recovery.",
        ]],
        "under-fuelling": [[
            "Your energy has been very low during a heavy week. You might need to eat more around training — and it's worth mentioning to a parent or coach.",
            "Low energy plus a big training week often means you need more food. Add a snack before and after sessions, and tell an adult how you're feeling.",
            "You've felt drained all week while training hard. Eat a bit more, especially carbs around sessions, and talk to someone you trust about it.",
            "Heavy week, very low energy. Make sure you're eating enough to fuel it — and let a parent or coach know.",
        ]],
        "missed-sessions": [[
            "You got {done} of {planned} sessions in last week. No stress — pick the two that matter most this week and nail those.",
            "Last week was {done} out of {planned}. Busy weeks happen; aim for one more session this week than last.",
            "{done} of {planned} sessions last week. Short on time? Even a 20-minute version keeps the habit alive.",
            "Only {done} of {planned} last week. Check the Plan tab and lock in the days that actually work for you.",
        ]],
        "full-week": [[
            "Every planned session done last week. That consistency is exactly how you get better.",
            "You hit all {done} sessions last week. Keep that rhythm going.",
            "A full week, done. That's the habit that builds real athletes.",
            "All {done} sessions completed last week — that's the hard part, and you did it.",
        ]],
        "personal-best": [[
            "New best: {weight} on {exercise}. That's real progress.",
            "You just moved {weight} on {exercise} — more than ever before. Nice.",
            "{exercise} at {weight} — a new personal best this week.",
            "Personal best on {exercise}: {weight}. The work is paying off.",
        ]],
        "streak": [[
            "{days} days in a row checking in or training. That's how habits are built.",
            "A {days}-day streak — keep showing up.",
            "{days} straight days. Consistency beats intensity every time.",
            "You've shown up {days} days running. Keep the chain going tomorrow.",
        ]],
        "getting-started": [[
            "Log your first session and check in each morning — the coach gets smarter every day you do.",
            "Welcome in. Do today's session and your first check-in, and your weekly coaching starts from there.",
            "Start with today's plan. After a few sessions, you'll get feedback on what to train next.",
            "Your coach needs a little data to work with. Log a session and check in tomorrow morning.",
        ]],
    ]

    /// §12: "a closing line drawn from an encouragement pool gated by
    /// whether the week was good, mixed, or poor."
    public static let encouragement: [String: [String]] = [
        "good": [
            "Great week. Keep stacking them.",
            "You're doing the work. It shows.",
            "That's what progress looks like.",
            "Strong week — rest well and go again.",
        ],
        "mixed": [
            "Some wins, some gaps. That's normal — keep going.",
            "Good pieces this week. Fix one thing and you're flying.",
            "Solid base. A small adjustment makes it great.",
            "Progress isn't a straight line. Keep showing up.",
        ],
        "poor": [
            "Every athlete has weeks like this. Tomorrow's a fresh start.",
            "Small steps count. One good session changes the week.",
            "Reset, refocus, go again.",
            "Don't worry about last week. Win today.",
        ],
    ]

    /// The words §11/§13 forbid anywhere in the bank.
    public static let bannedWords = [
        "injury", "injured", "risk", "damage", "unsafe", "safe", "diagnos", "red-s",
        "weight loss", "lose weight", "fat", "skinny", "thin", "body shape", "calorie deficit", "diet",
    ]

    public static func pool(code: String, tier: Int) -> [String] {
        guard let tiers = bank[code], !tiers.isEmpty else { return [""] }
        return tiers[min(tier, tiers.count - 1)]
    }

    public static func render(_ template: String, slots: [String: String]) -> String {
        var result = template
        for (key, value) in slots {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        // Sentence-case a line that opens with a slot ("{quality} keeps…").
        guard let first = result.first else { return result }
        return first.uppercased() + result.dropFirst()
    }
}

// MARK: - Wiring to the store

@MainActor
enum CoachStore {
    /// Computes this week's report from the athlete's own data and persists
    /// it (one row per week, §14's `CoachReport`), so next week can avoid
    /// repeating the same sentences.
    static func reportForThisWeek(athlete: Athlete, sessions: [Session], catalogue: Catalogue, context: ModelContext, now: Date = .now) -> CoachReportContent {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let previous = athlete.coachReports.first { calendar.isDate($0.weekStart, inSameDayAs: previousWeekStart) }
        let previousIndexes = previous.flatMap { try? JSONDecoder().decode([String: Int].self, from: Data($0.templateIndexesJSON.utf8)) } ?? [:]

        let athleteSport = athlete.sports.first
        let sportInfo = athleteSport.flatMap { allSportsBySlug[$0.sportSlug] }
        let positionName = athleteSport?.positionSlug.flatMap { slug in sportInfo?.positions.first { $0.slug == slug }?.name }
        var plannedLastWeek = 0
        if let athleteSport {
            let phase = PhaseCalculator.phase(today: previousWeekStart, seasonStart: athleteSport.seasonStart, seasonEnd: athleteSport.seasonEnd)
            plannedLastWeek = (phase == .inSeason || phase == .postSeason) ? 2 : 3
        }

        let input = CoachInput(
            athleteId: athlete.id, now: now, positionName: positionName,
            sportQualityProfile: sportInfo?.qualityProfile ?? [:],
            sessions: sessions.map { session in
                CoachSession(
                    date: session.startedAt, minutes: session.minutes, rpe: session.sessionRPE,
                    sets: session.sets.map { CoachSet(itemSlug: $0.itemSlug, reps: $0.reps, weightKg: $0.weightKg) }
                )
            },
            checkIns: athlete.checkIns.map {
                CheckInAnswers(date: $0.date, sleepQuality: $0.sleepQuality, soreness: $0.soreness, energy: $0.energy, stress: $0.stress)
            },
            plannedSessionsLastWeek: plannedLastWeek,
            catalogue: catalogue,
            previousTemplateIndexes: previousIndexes
        )
        let content = CoachEngine.report(input)

        let observationsJSON = (try? String(data: JSONEncoder().encode(content.observations), encoding: .utf8)) ?? "[]"
        let recommendationsJSON = (try? String(data: JSONEncoder().encode(content.recommendations), encoding: .utf8)) ?? "[]"
        let indexesJSON = (try? String(data: JSONEncoder().encode(content.templateIndexes), encoding: .utf8)) ?? "{}"
        if let existing = athlete.coachReports.first(where: { calendar.isDate($0.weekStart, inSameDayAs: weekStart) }) {
            existing.headline = content.headline
            existing.observationsJSON = observationsJSON
            existing.recommendationsJSON = recommendationsJSON
            existing.encouragement = content.encouragement
            existing.templateIndexesJSON = indexesJSON
        } else {
            context.insert(CoachReport(
                weekStart: weekStart, templateSetVersion: CoachEngine.templateSetVersion,
                headline: content.headline, observationsJSON: observationsJSON,
                recommendationsJSON: recommendationsJSON, encouragement: content.encouragement,
                templateIndexesJSON: indexesJSON, athlete: athlete
            ))
        }
        try? context.save()
        return content
    }
}

extension MuscleRegion {
    /// How the coach says it in a sentence: "your quads", "your core".
    var coachName: String {
        switch self {
        case .neck: "neck"
        case .shoulder: "shoulders"
        case .upperBack: "upper back"
        case .chest: "chest"
        case .lowerBack: "lower back"
        case .arm: "arms"
        case .forearm: "forearms"
        case .trunk: "core"
        case .hip: "hips"
        case .quadriceps: "quads"
        case .hamstrings: "hamstrings"
        case .calf: "calves"
        case .foot: "feet"
        }
    }
}
