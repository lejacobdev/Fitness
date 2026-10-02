import Foundation

// V6 workout engine, part 1: the decision (docs/VERSION-6.md §4–§9, §24).
//
//   athlete + sport demands + season + schedule + recent load + check-in
//     → SessionDecision (what kind of session, how long, what for, what to avoid, why)
//     → SessionBuilder (which exercises, in which order, how much)
//     → PlanExplanation (the same decision in plain words)
//
// Pure and deterministic: every input is a parameter.

public enum SessionType: String, Codable, Sendable, CaseIterable {
    /// Short supplemental work after team practice (15–35 min).
    case afterPractice
    /// The main development session on a day without practice (45–75 min).
    case gymDevelopment
    /// The day before a game: short, sharp, low fatigue.
    case primer
    /// A programmed conditioning session.
    case conditioning
    /// Easy movement after a game or a hard stretch.
    case recovery
    /// Mobility with a purpose (5–20 min).
    case mobility
    /// Away from home: no equipment.
    case travel
    /// Rest is part of the plan.
    case rest

    public var title: String {
        switch self {
        case .afterPractice: "After-practice strength"
        case .gymDevelopment: "Gym development day"
        case .primer: "Game-eve primer"
        case .conditioning: "Conditioning"
        case .recovery: "Recovery session"
        case .mobility: "Mobility"
        case .travel: "Travel session"
        case .rest: "Rest day"
        }
    }
}

public enum MobilityPurpose: String, Codable, Sendable {
    case preTraining, targeted, recovery, eveningDownshift

    public var title: String {
        switch self {
        case .preTraining: "Movement prep"
        case .targeted: "Targeted mobility"
        case .recovery: "Recovery movement"
        case .eveningDownshift: "Evening downshift"
        }
    }
}

/// Things that are good exercise but wrong for today (§8).
public enum AvoidToday: String, Codable, Sendable, CaseIterable {
    case heavyLowerBody = "heavy_lower_body"
    case highVolumeLowerBody = "high_volume_lower_body"
    case hardConditioning = "hard_conditioning"
    case highImpact = "high_impact"
    case maxSprinting = "max_sprinting"
    case newHardExercises = "new_hard_exercises"
    case heavyUpperBody = "heavy_upper_body"

    public var phrase: String {
        switch self {
        case .heavyLowerBody: "heavy lower-body lifting"
        case .highVolumeLowerBody: "a lot of leg volume"
        case .hardConditioning: "hard conditioning"
        case .highImpact: "jumping and other high-impact work"
        case .maxSprinting: "all-out sprinting"
        case .newHardExercises: "hard new exercises"
        case .heavyUpperBody: "heavy upper-body work"
        }
    }
}

/// Why the plan looks the way it does. Codes first; words in PlanExplanation.
public enum PlanReason: String, Codable, Sendable, CaseIterable {
    case practiceToday = "PRACTICE_TODAY"
    case hardTeamPractice = "HARD_TEAM_PRACTICE"
    case lightTeamPractice = "LIGHT_TEAM_PRACTICE"
    case noPracticeToday = "NO_PRACTICE_TODAY"
    case gameToday = "GAME_TODAY"
    case gameTomorrow = "GAME_TOMORROW"
    case gameWithin48h = "GAME_WITHIN_48H"
    case gameYesterday = "GAME_YESTERDAY"
    case lowReadiness = "LOW_READINESS"
    case belowNormalReadiness = "BELOW_NORMAL_READINESS"
    case soreLegs = "SORE_LEGS"
    case painReported = "PAIN_REPORTED"
    case returnAfterIllness = "RETURN_AFTER_ILLNESS"
    case examOrLongDay = "EXAM_OR_LONG_SCHOOL_DAY"
    case manyDaysInARow = "MANY_DAYS_IN_A_ROW"
    case inSeason = "IN_SEASON"
    case preSeason = "PRE_SEASON"
    case offSeason = "OFF_SEASON"
    case postSeason = "POST_SEASON"
    case limitedTime = "LIMITED_TIME"
    case sportProvidesConditioning = "SPORT_PROVIDES_CONDITIONING"
    case conditioningGap = "CONDITIONING_GAP"
    case lowerBodyTrainedRecently = "LOWER_BODY_TRAINED_RECENTLY"
    case plannedRestDay = "PLANNED_REST_DAY"
    case reflectionVeryHard = "REFLECTION_VERY_HARD"
    case reflectionSomethingHurt = "REFLECTION_SOMETHING_HURT"
    case beginner = "NEW_TO_LIFTING"
    case developmentGoal = "DEVELOPMENT_GOAL"
    case travelling = "TRAVELLING"
    case youngAthlete = "YOUNG_ATHLETE"
}

/// How the athlete feels this morning (from the check-in).
public enum ReadinessLevel: Int, Codable, Sendable, Comparable {
    case low = 0, belowNormal = 1, normal = 2, good = 3
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum PracticeIntensity: Int, Codable, Sendable {
    case light = 1, normal = 2, hard = 3
}

/// One past day, for the fatigue budget and weekly balance.
public struct DayLoad: Sendable, Equatable, Codable {
    public var daysAgo: Int
    public var practice: PracticeIntensity?
    public var game: Bool
    /// The session's capacity exposure (1 per capacity trained as a target).
    public var capacities: [Capacity]
    /// Main lower-body pattern trained ("squat", "hinge"…), for alternation.
    public var lowerPattern: String?
    /// Main upper-body pattern trained ("push", "pull").
    public var upperPattern: String?
    public var heavyLower: Bool
    public var conditioningMinutes: Int
    public var sessionType: SessionType?

    public init(daysAgo: Int, practice: PracticeIntensity? = nil, game: Bool = false, capacities: [Capacity] = [],
                lowerPattern: String? = nil, upperPattern: String? = nil, heavyLower: Bool = false,
                conditioningMinutes: Int = 0, sessionType: SessionType? = nil) {
        self.daysAgo = daysAgo
        self.practice = practice
        self.game = game
        self.capacities = capacities
        self.lowerPattern = lowerPattern
        self.upperPattern = upperPattern
        self.heavyLower = heavyLower
        self.conditioningMinutes = conditioningMinutes
        self.sessionType = sessionType
    }
}

public struct RecentLoad: Sendable, Equatable, Codable {
    /// The last 7 days (daysAgo 1…7), any order.
    public var days: [DayLoad]

    public init(days: [DayLoad] = []) { self.days = days }

    var week: [DayLoad] { days.filter { $0.daysAgo >= 1 && $0.daysAgo <= 7 } }

    public func exposure(_ capacity: Capacity) -> Int { week.reduce(0) { $0 + ($1.capacities.contains(capacity) ? 1 : 0) } }
    public var conditioningMinutes: Int { week.reduce(0) { $0 + $1.conditioningMinutes } }
    public var practiceDays: Int { week.filter { $0.practice != nil }.count }
    public var gymSessions: Int { week.filter { $0.sessionType == .gymDevelopment }.count }
    public var daysSinceHeavyLower: Int? { week.filter(\.heavyLower).map(\.daysAgo).min() }
    /// The most recent main lower / upper pattern.
    public var lastLowerPattern: String? { week.filter { $0.lowerPattern != nil }.min { $0.daysAgo < $1.daysAgo }?.lowerPattern }
    public var lastUpperPattern: String? { week.filter { $0.upperPattern != nil }.min { $0.daysAgo < $1.daysAgo }?.upperPattern }
    public var yesterday: DayLoad? { days.first { $0.daysAgo == 1 } }
}

/// What last night's reflection told the engine (§18).
public struct ReflectionSignal: Sendable, Equatable, Codable {
    /// 1 easy … 4 very hard.
    public var dayFelt: Int?
    /// 1 good … 3 very tired; 4 something hurt.
    public var bodyFelt: Int?

    public init(dayFelt: Int? = nil, bodyFelt: Int? = nil) {
        self.dayFelt = dayFelt
        self.bodyFelt = bodyFelt
    }

    public var veryHard: Bool { (dayFelt ?? 0) >= 4 || bodyFelt == 3 }
    public var somethingHurt: Bool { bodyFelt == 4 }
}

/// Everything the engine knows about today.
public struct TrainingDay: Sendable {
    public var date: Date
    public var phase: SeasonPhase
    public var age: Int
    public var experience: TrainingExperience
    public var demands: SportDemands
    /// The athlete's development goals, most important first.
    public var goals: [Capacity]
    /// Team practice today (nil: none).
    public var practice: PracticeIntensity?
    public var gameToday: Bool
    /// 1 = a game tomorrow. Nil: none in the next week.
    public var daysToNextGame: Int?
    /// 1 = a game yesterday.
    public var daysSinceLastGame: Int?
    public var readiness: ReadinessLevel
    public var soreLegs: Bool
    public var painAreas: Set<PainArea>
    /// 1…5 after being sick (nil: not returning).
    public var illnessReturnDay: Int?
    public var examOrLongDay: Bool
    public var daysTrainedInARow: Int
    /// Minutes the athlete has (nil: not limited).
    public var availableMinutes: Int?
    public var recent: RecentLoad
    public var reflection: ReflectionSignal?
    /// Whether the week plan has a gym session on this day.
    public var plannedGymDay: Bool
    public var travelling: Bool
    /// Time of day: before today's practice or game, or the evening.
    public var beforeSession: Bool
    public var evening: Bool

    public init(date: Date, phase: SeasonPhase, age: Int, experience: TrainingExperience, demands: SportDemands,
                goals: [Capacity] = [], practice: PracticeIntensity? = nil, gameToday: Bool = false,
                daysToNextGame: Int? = nil, daysSinceLastGame: Int? = nil, readiness: ReadinessLevel = .normal,
                soreLegs: Bool = false, painAreas: Set<PainArea> = [], illnessReturnDay: Int? = nil,
                examOrLongDay: Bool = false, daysTrainedInARow: Int = 0, availableMinutes: Int? = nil,
                recent: RecentLoad = RecentLoad(), reflection: ReflectionSignal? = nil, plannedGymDay: Bool = true,
                travelling: Bool = false, beforeSession: Bool = false, evening: Bool = false) {
        self.beforeSession = beforeSession
        self.evening = evening
        self.date = date
        self.phase = phase
        self.age = age
        self.experience = experience
        self.demands = demands
        self.goals = goals
        self.practice = practice
        self.gameToday = gameToday
        self.daysToNextGame = daysToNextGame
        self.daysSinceLastGame = daysSinceLastGame
        self.readiness = readiness
        self.soreLegs = soreLegs
        self.painAreas = painAreas
        self.illnessReturnDay = illnessReturnDay
        self.examOrLongDay = examOrLongDay
        self.daysTrainedInARow = daysTrainedInARow
        self.availableMinutes = availableMinutes
        self.recent = recent
        self.reflection = reflection
        self.plannedGymDay = plannedGymDay
        self.travelling = travelling
    }
}

/// §24: the structured decision. The UI and any language layer only explain it.
public struct SessionDecision: Sendable, Equatable, Codable {
    public var sessionType: SessionType
    public var mobilityPurpose: MobilityPurpose?
    /// Minutes the session should take.
    public var durationTarget: Int
    public var primaryTargets: [Capacity]
    public var maintain: [Capacity]
    public var avoidToday: [AvoidToday]
    public var reasons: [PlanReason]
    /// A conditioning block or session, when programmed.
    public var conditioning: ConditioningType?
    public var conditioningMinutes: Int
    /// 0 … 3: how much leg loading is allowed today.
    public var legBudget: Int
    /// Main lower / upper pattern to train (alternates through the week).
    public var lowerPattern: String?
    public var upperPattern: String?

    public func avoids(_ avoid: AvoidToday) -> Bool { avoidToday.contains(avoid) }
}

public enum SessionPlanner {
    /// The main session for today. `requested` asks for a specific kind (the
    /// athlete opened "Mobility"), which still respects every safety rule.
    public static func decide(_ day: TrainingDay, requested: SessionType? = nil) -> SessionDecision {
        var reasons: [PlanReason] = []
        var avoid: Set<AvoidToday> = []
        func add(_ reason: PlanReason) { if !reasons.contains(reason) { reasons.append(reason) } }

        switch day.phase {
        case .inSeason: add(.inSeason)
        case .preSeason: add(.preSeason)
        case .offSeason: add(.offSeason)
        case .postSeason: add(.postSeason)
        }
        if day.experience == .beginner { add(.beginner); avoid.insert(.newHardExercises) }
        if day.age < 15 { add(.youngAthlete) }

        // Signals that make the day easier.
        if day.readiness == .low { add(.lowReadiness) }
        if day.readiness == .belowNormal { add(.belowNormalReadiness) }
        if day.soreLegs { add(.soreLegs); avoid.formUnion([.heavyLowerBody, .highImpact]) }
        if !day.painAreas.isEmpty { add(.painReported) }
        if let reflection = day.reflection {
            if reflection.veryHard { add(.reflectionVeryHard) }
            if reflection.somethingHurt { add(.reflectionSomethingHurt) }
        }
        if let illness = day.illnessReturnDay {
            add(.returnAfterIllness)
            avoid.formUnion([.hardConditioning, .heavyLowerBody, .maxSprinting])
            if illness <= 2 { avoid.insert(.highVolumeLowerBody) }
        }
        if day.examOrLongDay { add(.examOrLongDay) }
        if day.daysTrainedInARow >= 6 { add(.manyDaysInARow) }
        if let next = day.daysToNextGame {
            if next == 1 {
                add(.gameTomorrow)
                avoid.formUnion([.heavyLowerBody, .highVolumeLowerBody, .hardConditioning, .highImpact])
            } else if next == 2 {
                add(.gameWithin48h)
                avoid.formUnion([.highVolumeLowerBody, .hardConditioning])
            }
        }
        if day.daysSinceLastGame == 1 { add(.gameYesterday); avoid.formUnion([.heavyLowerBody, .highImpact, .maxSprinting]) }
        if let since = day.recent.daysSinceHeavyLower, since <= 1 { add(.lowerBodyTrainedRecently); avoid.insert(.heavyLowerBody) }

        let mustRecover = day.readiness == .low || (day.reflection?.somethingHurt ?? false) || day.daysTrainedInARow >= 7
            || (day.illnessReturnDay.map { $0 <= 2 } ?? false)

        // 1. What kind of session.
        var type: SessionType
        var purpose: MobilityPurpose?
        if day.travelling {
            add(.travelling)
            type = .travel
        } else if day.gameToday {
            add(.gameToday)
            type = .mobility
            purpose = .preTraining
        } else if let practice = day.practice {
            add(.practiceToday)
            if practice == .hard { add(.hardTeamPractice) }
            if practice == .light { add(.lightTeamPractice) }
            type = mustRecover ? .mobility : .afterPractice
            if mustRecover { purpose = .recovery }
            // Practice already gave the conditioning and the running.
            avoid.formUnion([.hardConditioning, .maxSprinting, .highImpact])
        } else {
            add(.noPracticeToday)
            if mustRecover || day.daysSinceLastGame == 1 {
                type = .recovery
            } else if day.daysToNextGame == 1 {
                type = .primer
            } else if day.plannedGymDay {
                type = .gymDevelopment
            } else if conditioningRemaining(day) >= 20, day.readiness >= .normal, !avoid.contains(.hardConditioning) || day.demands.need == .aerobicBase {
                type = .conditioning
            } else {
                add(.plannedRestDay)
                type = .rest
            }
        }
        if let requested, requested != type {
            switch requested {
            case .mobility:
                type = .mobility
                if purpose == nil {
                    if day.beforeSession && (day.gameToday || day.practice != nil) { purpose = .preTraining }
                    else if day.evening { purpose = .eveningDownshift }
                    else if day.practice != nil || day.gameToday { purpose = .recovery }
                    else { purpose = .targeted }
                }
            case .gymDevelopment, .afterPractice, .primer, .conditioning:
                // Asked for training on a day that says otherwise: the safe version of it.
                if !mustRecover && !day.gameToday { type = requested }
            default:
                type = requested
            }
        }

        // 2. How much leg loading is allowed.
        var legBudget = 3
        if let practice = day.practice {
            let practiceLegs = min(3, max(0, day.demands.practiceLegLoad + (practice == .hard ? 1 : practice == .light ? -1 : 0)))
            legBudget = max(0, 2 - practiceLegs + (practice == .light ? 1 : 0))
        }
        if avoid.contains(.heavyLowerBody) { legBudget = min(legBudget, 1) }
        if day.daysToNextGame == 1 || day.soreLegs || day.readiness == .low { legBudget = min(legBudget, day.practice == nil ? 1 : 0) }
        if legBudget <= 1 { avoid.insert(.highVolumeLowerBody) }
        if legBudget <= 1, day.practice != nil { add(.lowerBodyTrainedRecently) }

        // 3. How long.
        let duration = durationTarget(type: type, day: day, add: add)

        // 4. What for.
        var (primary, maintain) = targets(type: type, day: day, legBudget: legBudget, avoid: avoid)
        if !day.goals.isEmpty, primary.contains(where: day.goals.contains) || maintain.contains(where: day.goals.contains) { add(.developmentGoal) }

        // 5. Conditioning.
        var conditioning: ConditioningType?
        var conditioningMinutes = 0
        let remaining = conditioningRemaining(day)
        if day.demands.practiceConditioning >= 2, day.practice != nil || day.recent.practiceDays >= 3 { add(.sportProvidesConditioning) }
        switch type {
        case .conditioning:
            conditioning = conditioningType(day, avoid: avoid)
            conditioningMinutes = min(max(remaining, 20), duration - 8)
            add(.conditioningGap)
        case .gymDevelopment where remaining >= 10 && duration >= 50:
            let kind = conditioningType(day, avoid: avoid)
            if !(avoid.contains(.hardConditioning) && kind != .aerobicBase && kind != .recovery) {
                conditioning = kind
                conditioningMinutes = min(remaining, kind == .aerobicBase ? 20 : 12, max(8, duration / 5))
                add(.conditioningGap)
                if !primary.contains(.aerobic) && !primary.contains(.repeatedEffort) {
                    maintain.append(kind == .aerobicBase || kind == .tempo ? .aerobic : .repeatedEffort)
                }
            }
        case .recovery:
            conditioning = .recovery
            conditioningMinutes = max(10, duration - 10)
        default:
            break
        }

        // 6. Which patterns (alternate through the week).
        let lower = day.recent.lastLowerPattern == "squat" ? "hinge" : "squat"
        let upper = day.recent.lastUpperPattern == "push" ? "pull" : "push"

        primary = Array(primary.prefix(3))
        return SessionDecision(
            sessionType: type, mobilityPurpose: type == .mobility ? (purpose ?? .targeted) : nil,
            durationTarget: duration, primaryTargets: primary,
            maintain: Array(maintain.filter { !primary.contains($0) }.prefix(3)),
            avoidToday: AvoidToday.allCases.filter(avoid.contains), reasons: reasons,
            conditioning: conditioning, conditioningMinutes: conditioningMinutes, legBudget: legBudget,
            lowerPattern: [.gymDevelopment, .afterPractice, .travel].contains(type) ? lower : nil,
            upperPattern: [.gymDevelopment, .afterPractice, .primer, .travel].contains(type) ? upper : nil
        )
    }

    /// Conditioning minutes still to program this week.
    static func conditioningRemaining(_ day: TrainingDay) -> Int {
        let practiceDays = day.recent.practiceDays + (day.practice != nil ? 1 : 0)
        let target = day.demands.conditioningMinutes(practiceDays: practiceDays, phase: day.phase)
        return max(0, target - day.recent.conditioningMinutes)
    }

    static func conditioningType(_ day: TrainingDay, avoid: Set<AvoidToday>) -> ConditioningType {
        if avoid.contains(.hardConditioning) || day.readiness < .normal || day.illnessReturnDay != nil { return .aerobicBase }
        // Off-season builds the base first; the sport's own kind comes closer to the season.
        if day.phase == .offSeason, day.demands.need != .aerobicBase, day.recent.exposure(.aerobic) == 0 { return .aerobicBase }
        if day.age < 14, day.demands.need == .anaerobic { return .aerobicPower }
        return day.demands.need
    }

    static func durationTarget(type: SessionType, day: TrainingDay, add: (PlanReason) -> Void) -> Int {
        var minutes: Int
        switch type {
        case .gymDevelopment:
            minutes = [.beginner: 45, .intermediate: 55, .experienced: 65][day.experience] ?? 55
            switch day.phase {
            case .offSeason: minutes += 10
            case .preSeason: minutes += 5
            case .inSeason: minutes -= 10
            case .postSeason: minutes -= 15
            }
            if day.age < 15 { minutes -= 5 }
            if day.readiness == .belowNormal { minutes -= 10 }
            if day.daysToNextGame == 2 { minutes -= 10 }
            if let illness = day.illnessReturnDay { minutes -= illness <= 3 ? 20 : 10 }
            if day.examOrLongDay { minutes -= 15 }
            minutes = min(75, max(35, minutes))
        case .afterPractice:
            minutes = day.phase == .inSeason ? 22 : 28
            if day.practice == .hard { minutes -= 5 }
            if day.practice == .light { minutes += 5 }
            if day.experience == .experienced { minutes += 5 }
            if day.readiness == .belowNormal || day.daysToNextGame == 1 { minutes -= 5 }
            if day.examOrLongDay { minutes -= 5 }
            minutes = min(35, max(15, minutes))
        case .primer: minutes = 20
        case .conditioning: minutes = day.phase == .offSeason ? 40 : 30
        case .recovery: minutes = 25
        case .mobility: minutes = day.gameToday ? 10 : 12
        case .travel: minutes = 20
        case .rest: minutes = 0
        }
        if let available = day.availableMinutes, available < minutes, type != .rest {
            add(.limitedTime)
            minutes = max(10, available)
        }
        return minutes
    }

    /// Development value: the sport's weight, the athlete's goals on top,
    /// less what was already trained this week.
    static func priority(_ capacity: Capacity, day: TrainingDay) -> Double {
        var value = day.demands.weights[capacity] ?? 0.3
        if let rank = day.goals.firstIndex(of: capacity) { value += rank == 0 ? 0.6 : 0.35 }
        let exposure = day.recent.exposure(capacity)
        value *= exposure == 0 ? 1.0 : exposure == 1 ? 0.75 : 0.5
        // Practice already trains speed and agility in field and court sports.
        if [.coordination, .speed, .acceleration, .deceleration].contains(capacity), day.demands.practiceLegLoad >= 3,
           day.phase == .inSeason || day.phase == .preSeason {
            value *= 0.6
        }
        return value
    }

    static func ranked(_ candidates: [Capacity], day: TrainingDay) -> [Capacity] {
        candidates.sorted { lhs, rhs in
            let l = priority(lhs, day: day), r = priority(rhs, day: day)
            return l != r ? l > r : lhs.rawValue < rhs.rawValue
        }
    }

    static func targets(type: SessionType, day: TrainingDay, legBudget: Int, avoid: Set<AvoidToday>) -> (primary: [Capacity], maintain: [Capacity]) {
        switch type {
        case .gymDevelopment:
            var primary: [Capacity] = []
            if legBudget >= 2 { primary.append(.strength) } else { primary.append(.upperStrength) }
            let speedPower = ranked([.power, .acceleration, .speed], day: day)
            if !avoid.contains(.highImpact) || !avoid.contains(.maxSprinting), day.readiness >= .normal, let first = speedPower.first {
                primary.append(first)
            }
            let others = ranked([.upperStrength, .coordination, .deceleration, .balance, .mobility], day: day).filter { !primary.contains($0) }
            if let goal = day.goals.first(where: { !primary.contains($0) && ![.aerobic, .repeatedEffort].contains($0) }) {
                primary.append(goal)
            } else if let next = others.first, primary.count < 3, legBudget >= 2 {
                primary.append(next == .upperStrength && primary.contains(.upperStrength) ? .trunk : next)
            }
            let maintain = ranked([.trunk, .resilience, .upperStrength, .mobility], day: day).filter { !primary.contains($0) }
            return (primary, Array(maintain.prefix(2)))
        case .afterPractice:
            var primary: [Capacity] = [.upperStrength, .trunk]
            if legBudget >= 2 { primary.insert(.strength, at: 1) }
            var maintain: [Capacity] = [.resilience]
            if let goal = day.goals.first, [.mobility, .balance, .trunk, .upperStrength].contains(goal), !primary.contains(goal) { maintain.append(goal) }
            return (primary, maintain)
        case .primer:
            return ([.power, .acceleration], [.trunk, .mobility])
        case .conditioning:
            let kind = conditioningType(day, avoid: avoid)
            return ([kind == .aerobicBase || kind == .tempo || kind == .aerobicPower ? .aerobic : .repeatedEffort], [.mobility])
        case .recovery:
            return ([.mobility], [.aerobic])
        case .mobility:
            return ([.mobility], [.balance])
        case .travel:
            return ([.strength, .upperStrength], [.trunk])
        case .rest:
            return ([], [])
        }
    }
}

/// The week's shape: which days without practice get a gym session.
public enum WeekPlanner {
    /// How many gym sessions this athlete should do in a week.
    public static func gymSessions(phase: SeasonPhase, experience: TrainingExperience, practiceDays: Int, override: Int? = nil) -> Int {
        if let override { return min(max(override, 1), 5) }
        var count: Int
        switch phase {
        case .offSeason: count = 3
        case .preSeason: count = practiceDays >= 4 ? 2 : 3
        case .inSeason: count = practiceDays >= 5 ? 1 : 2
        case .postSeason: count = 2
        }
        if experience == .beginner { count = min(count, 2) }
        return count
    }

    /// The gym days of a 7-day week (0 = the first day): days without practice
    /// or games first, never the day before a game, spread out.
    /// `days[i]` is (practice, game) for day i.
    public static func gymDays(days: [(practice: Bool, game: Bool)], count: Int) -> Set<Int> {
        guard count > 0 else { return [] }
        let n = days.count
        func score(_ i: Int) -> Int {
            if days[i].game { return -100 }
            var s = days[i].practice ? 0 : 10
            if i + 1 < n, days[i + 1].game { s -= 50 }
            if i > 0, days[i - 1].game { s -= 5 }
            return s
        }
        var chosen: [Int] = []
        let order = (0..<n).sorted { score($0) != score($1) ? score($0) > score($1) : $0 < $1 }
        for i in order where score(i) > -50 && chosen.count < count {
            // At least a day apart when possible.
            if chosen.contains(where: { abs($0 - i) < 2 }) { continue }
            chosen.append(i)
        }
        if chosen.count < count {
            for i in order where score(i) > -50 && chosen.count < count && !chosen.contains(i) { chosen.append(i) }
        }
        return Set(chosen)
    }
}
