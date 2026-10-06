import Foundation

/// The Athlete Score: one private number (0–100) for how the athlete is
/// developing over the last four weeks — never how they are today (that is
/// readiness, which stays a word). Only the athlete sees it; nothing is
/// compared with anyone. It is built from four parts, each against the
/// athlete's own history:
///
/// - consistency (30 %): planned sessions done; sick, travel and holiday days
///   are taken out of the plan, so rest never lowers it;
/// - load and recovery (30 %): session-RPE load this week against the
///   four-week normal (a soft range, not a hard threshold) plus sleep,
///   energy, soreness and stress from the check-ins;
/// - development (25 %): tests and lifts against the athlete's own earlier
///   results, counting only changes bigger than everyday noise;
/// - satisfaction (15 %): how training and practice felt, and whether
///   something was learned.
///
/// Pain is never part of it. The score moves at most `maxWeeklyStep` per week.
public struct AthleteScoreInput: Sendable {
    public struct Activity: Sendable {
        public let date: Date
        public let minutes: Int
        /// Session RPE 1…10, if logged.
        public let rpe: Int?
        public let mobility: Bool
        public init(date: Date, minutes: Int, rpe: Int?, mobility: Bool = false) {
            self.date = date
            self.minutes = minutes
            self.rpe = rpe
            self.mobility = mobility
        }
    }

    public struct Practice: Sendable {
        public let date: Date
        public let minutes: Int?
        /// 1 easy … 5 exhausting.
        public let hard: Int
        /// 1 badly … 5 great.
        public let went: Int
        public init(date: Date, minutes: Int?, hard: Int, went: Int) {
            self.date = date
            self.minutes = minutes
            self.hard = hard
            self.went = went
        }
    }

    /// A morning check-in, every answer 1…5.
    public struct Wellness: Sendable {
        public let date: Date
        public let sleep: Int
        public let energy: Int
        public let soreness: Int
        public let stress: Int
        public init(date: Date, sleep: Int, energy: Int, soreness: Int, stress: Int) {
            self.date = date
            self.sleep = sleep
            self.energy = energy
            self.soreness = soreness
            self.stress = stress
        }
    }

    /// An evening reflection.
    public struct Feeling: Sendable {
        public let date: Date
        /// 1 rough … 5 great.
        public let day: Int?
        /// 1 tough … 4 great.
        public let practice: Int?
        public let learned: Bool
        public init(date: Date, day: Int?, practice: Int?, learned: Bool) {
            self.date = date
            self.day = day
            self.practice = practice
            self.learned = learned
        }
    }

    public var now: Date
    public var activities: [Activity]
    public var practices: [Practice]
    public var checkIns: [Wellness]
    public var feelings: [Feeling]
    /// Planned workouts plus team practices in a normal week.
    public var plannedPerWeek: Int
    /// Days (start of day) that were sick, travel, holiday or paused.
    public var pausedDays: Set<Date>
    /// Relative changes of tests and lifts, signed so that positive is
    /// better (0.04 = 4 % better than the earlier result).
    public var developmentChanges: [Double]

    public init(now: Date, activities: [Activity], practices: [Practice], checkIns: [Wellness], feelings: [Feeling],
                plannedPerWeek: Int, pausedDays: Set<Date> = [], developmentChanges: [Double] = []) {
        self.now = now
        self.activities = activities
        self.practices = practices
        self.checkIns = checkIns
        self.feelings = feelings
        self.plannedPerWeek = plannedPerWeek
        self.pausedDays = pausedDays
        self.developmentChanges = developmentChanges
    }
}

public struct AthleteScore: Sendable, Equatable {
    public enum Part: String, Sendable, CaseIterable {
        case consistency, balance, development, satisfaction

        public var title: String {
            switch self {
            case .consistency: "Consistency"
            case .balance: "Load and recovery"
            case .development: "Development"
            case .satisfaction: "How it feels"
            }
        }

        public var weight: Double {
            switch self {
            case .consistency: 0.30
            case .balance: 0.30
            case .development: 0.25
            case .satisfaction: 0.15
            }
        }
    }

    public struct Component: Sendable, Equatable {
        public let part: Part
        /// 0…100, nil when there is nothing to judge it on yet.
        public let value: Int?
        public let detail: String
    }

    public enum Trend: Sendable, Equatable {
        case up, steady, down
    }

    /// What the athlete should lean towards next.
    public enum Direction: Sendable, Equatable {
        case pushMore, holdSteady, easeOff
    }

    /// Still collecting: how far along (0…1) and what is still needed.
    public struct Learning: Sendable, Equatable {
        public let progress: Double
        public let detail: String
    }

    /// nil while learning.
    public let value: Int?
    public let learning: Learning?
    public let components: [Component]
    public let direction: Direction
    public let advice: String
    /// Load this week against the four-week normal (nil: not enough data).
    public let loadRatio: Double?

    public var word: String {
        guard let value else { return "Getting to know you" }
        return AthleteScore.word(for: value)
    }

    public static func word(for value: Int) -> String {
        switch value {
        case ..<40: "Finding rhythm"
        case ..<60: "Building"
        case ..<80: "Developing well"
        default: "Strong phase"
        }
    }
}

public enum AthleteScoreEngine {
    public static let windowDays = 28
    public static let maxWeeklyStep = 8
    static let minDays = 14
    static let minActivities = 6
    static let minCheckIns = 2

    public static func score(_ input: AthleteScoreInput, calendar: Calendar = .current) -> AthleteScore {
        let today = calendar.startOfDay(for: input.now)
        let windowStart = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today
        let firstDay = (input.activities.map(\.date) + input.practices.map(\.date) + input.checkIns.map(\.date))
            .min().map { calendar.startOfDay(for: $0) }
        let daysKnown = firstDay.map { (calendar.dateComponents([.day], from: $0, to: today).day ?? 0) + 1 } ?? 0
        let inWindow = { (date: Date) in date >= windowStart && date < (calendar.date(byAdding: .day, value: 1, to: today) ?? input.now) }

        let activities = input.activities.filter { inWindow($0.date) }
        let practices = input.practices.filter { inWindow($0.date) }
        let checkIns = input.checkIns.filter { inWindow($0.date) }
        let feelings = input.feelings.filter { inWindow($0.date) }

        let consistency = consistencyPart(activities: activities, practices: practices, input: input,
                                          windowStart: windowStart, today: today, daysKnown: daysKnown, calendar: calendar)
        let balance = balancePart(activities: activities, practices: practices, checkIns: checkIns,
                                  today: today, daysKnown: daysKnown, calendar: calendar)
        let development = developmentPart(input.developmentChanges)
        let satisfaction = satisfactionPart(feelings: feelings, practices: practices)
        let components = [consistency, balance.component, development, satisfaction]

        // Cold start: two weeks, six sessions and two check-ins before a number.
        let activityCount = input.activities.filter { !$0.mobility }.count + input.practices.count
        let ready = daysKnown >= minDays && activityCount >= minActivities && input.checkIns.count >= minCheckIns
            && consistency.value != nil && components.filter({ $0.value != nil }).count >= 2
        guard ready else {
            let progress = (min(1, Double(daysKnown) / Double(minDays))
                + min(1, Double(activityCount) / Double(minActivities))
                + min(1, Double(input.checkIns.count) / Double(minCheckIns))) / 3
            var needed: [String] = []
            if activityCount < minActivities {
                let left = minActivities - activityCount
                needed.append(left == 1 ? "1 more session" : "\(left) more sessions")
            }
            if input.checkIns.count < minCheckIns {
                let left = minCheckIns - input.checkIns.count
                needed.append(left == 1 ? "1 more check-in" : "\(left) more check-ins")
            }
            if daysKnown < minDays {
                let left = minDays - daysKnown
                needed.append(left == 1 ? "1 more day" : "\(left) more days")
            }
            if input.plannedPerWeek == 0 { needed.append("a training week in your plan") }
            let detail = needed.isEmpty ? "Almost there." : "Your score appears after " + list(needed) + "."
            return AthleteScore(value: nil, learning: .init(progress: min(progress, 0.95), detail: detail),
                                components: components, direction: .holdSteady,
                                advice: "Train and check in as usual. The score needs a couple of weeks of your normal before it says anything.",
                                loadRatio: balance.ratio)
        }

        let known = components.compactMap { component in component.value.map { (component.part.weight, Double($0)) } }
        let totalWeight = known.reduce(0) { $0 + $1.0 }
        let value = Int((known.reduce(0) { $0 + $1.0 * $1.1 } / totalWeight).rounded())
        let (direction, advice) = guidance(components: components, balance: balance)
        return AthleteScore(value: max(0, min(100, value)), learning: nil, components: components,
                            direction: direction, advice: advice, loadRatio: balance.ratio)
    }

    // MARK: Parts

    static func consistencyPart(activities: [AthleteScoreInput.Activity], practices: [AthleteScoreInput.Practice],
                                input: AthleteScoreInput, windowStart: Date, today: Date, daysKnown: Int,
                                calendar: Calendar) -> AthleteScore.Component {
        let days = min(windowDays, max(daysKnown, 0))
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? windowStart
        let paused = input.pausedDays.filter { $0 >= start && $0 <= today }.count
        let trainingDays = max(0, days - paused)
        let expected = Double(input.plannedPerWeek) * Double(trainingDays) / 7
        let done = activities.filter { !$0.mobility && $0.date >= start }.count + practices.filter { $0.date >= start }.count
        guard expected >= 1 else {
            return .init(part: .consistency, value: nil, detail: paused > 0 ? "Paused days don't count against you" : "No planned week yet")
        }
        let planned = Int(expected.rounded())
        let ratio = Double(done) / expected
        // 90 % of the plan is a full week: life happens.
        let value = Int((min(1, ratio / 0.9) * 100).rounded())
        return .init(part: .consistency, value: value, detail: "\(min(done, planned)) of \(planned) planned sessions in \(days == windowDays ? "4 weeks" : "\(days) days")")
    }

    struct Balance {
        let component: AthleteScore.Component
        let ratio: Double?
        let recovery: Double?
    }

    static func load(_ activity: AthleteScoreInput.Activity) -> Double {
        Double(activity.rpe ?? (activity.mobility ? 2 : 5)) * Double(max(activity.minutes, 0))
    }

    static func load(_ practice: AthleteScoreInput.Practice) -> Double {
        Double(min(10, max(1, practice.hard * 2))) * Double(practice.minutes ?? 75)
    }

    static func balancePart(activities: [AthleteScoreInput.Activity], practices: [AthleteScoreInput.Practice],
                            checkIns: [AthleteScoreInput.Wellness], today: Date, daysKnown: Int,
                            calendar: Calendar) -> Balance {
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let acute = activities.filter { $0.date >= weekStart }.reduce(0) { $0 + load($1) }
            + practices.filter { $0.date >= weekStart }.reduce(0) { $0 + load($1) }
        let total = activities.reduce(0) { $0 + load($1) } + practices.reduce(0) { $0 + load($1) }
        let weeks = Double(min(windowDays, daysKnown)) / 7
        // The four-week normal needs three weeks of history to mean anything.
        let ratio: Double? = (daysKnown >= 21 && total > 0) ? acute / (total / weeks) : nil
        let loadValue: Double? = ratio.map { r in
            switch r {
            case ..<0.3: 55
            case ..<0.8: 55 + (r - 0.3) / 0.5 * 45
            case ...1.3: 100
            case ..<2.0: 100 - (r - 1.3) / 0.7 * 70
            default: 30
            }
        }

        let recent = checkIns.filter { $0.date >= weekStart }
        let recovery: Double? = recent.count >= 2 ? recent.map { c in
            let sleep = Double(min(5, max(1, c.sleep)) - 1) / 4
            let energy = Double(min(5, max(1, c.energy)) - 1) / 4
            let soreness = Double(5 - min(5, max(1, c.soreness))) / 4
            let stress = Double(5 - min(5, max(1, c.stress))) / 4
            return (sleep + energy + soreness + stress) / 4 * 100
        }.reduce(0, +) / Double(recent.count) : nil

        let parts = [loadValue, recovery].compactMap { $0 }
        guard !parts.isEmpty else {
            return Balance(component: .init(part: .balance, value: nil, detail: "Needs a few check-ins and rated sessions"),
                           ratio: ratio, recovery: recovery)
        }
        let value = Int((parts.reduce(0, +) / Double(parts.count)).rounded())
        var bits: [String] = []
        if let ratio {
            bits.append(ratio > 1.3 ? "More load than usual this week" : ratio < 0.8 ? "Lighter week than usual" : "Load in your normal range")
        }
        if let recovery {
            bits.append(recovery >= 65 ? "recovering well" : recovery >= 45 ? "recovery okay" : "sleep and energy low")
        }
        let detail = bits.joined(separator: ", ")
        return Balance(component: .init(part: .balance, value: value, detail: detail.prefix(1).uppercased() + detail.dropFirst()),
                       ratio: ratio, recovery: recovery)
    }

    /// Changes smaller than this are treated as noise (tests are rarely more
    /// repeatable than a few per cent).
    static let noise = 0.025

    static func developmentPart(_ changes: [Double]) -> AthleteScore.Component {
        guard !changes.isEmpty else {
            return .init(part: .development, value: nil, detail: "Do a test day or log weights to see it")
        }
        let better = changes.filter { $0 >= noise }.count
        let worse = changes.filter { $0 <= -noise }.count
        let value = changes.map { $0 >= noise ? 100.0 : ($0 <= -noise ? 35.0 : 65.0) }.reduce(0, +) / Double(changes.count)
        let detail: String
        if better > 0 {
            detail = "\(better) of \(changes.count) \(changes.count == 1 ? "measure" : "measures") improved"
        } else if worse > 0 {
            detail = "Holding or a little down — normal in a hard block"
        } else {
            detail = "Holding steady"
        }
        return .init(part: .development, value: Int(value.rounded()), detail: detail)
    }

    static func satisfactionPart(feelings: [AthleteScoreInput.Feeling], practices: [AthleteScoreInput.Practice]) -> AthleteScore.Component {
        var ratings: [Double] = []
        for feeling in feelings {
            if let day = feeling.day { ratings.append(Double(min(5, max(1, day)) - 1) / 4) }
            if let practice = feeling.practice { ratings.append(Double(min(4, max(1, practice)) - 1) / 3) }
        }
        ratings += practices.map { Double(min(5, max(1, $0.went)) - 1) / 4 }
        guard ratings.count >= 3 else {
            return .init(part: .satisfaction, value: nil, detail: "From your evening reflections and practice logs")
        }
        let average = ratings.reduce(0, +) / Double(ratings.count)
        let learnedShare = feelings.isEmpty ? average : Double(feelings.filter(\.learned).count) / Double(feelings.count)
        let value = Int(((average * 0.85 + learnedShare * 0.15) * 100).rounded())
        let detail = average >= 0.65 ? "Training has felt good" : average >= 0.45 ? "Mixed lately" : "It hasn't felt good lately"
        return .init(part: .satisfaction, value: value, detail: detail)
    }

    // MARK: Guidance

    static func guidance(components: [AthleteScore.Component], balance: Balance) -> (AthleteScore.Direction, String) {
        let value = { (part: AthleteScore.Part) in components.first { $0.part == part }?.value }
        if (balance.ratio ?? 1) > 1.3 {
            return (.easeOff, "A lot on your plate lately. A lighter few days now will make the next weeks stronger.")
        }
        if (balance.recovery ?? 100) < 45 {
            return (.easeOff, "Sleep and energy have been low. Keep sessions easy until they come back.")
        }
        let known = components.compactMap { c in c.value.map { (c.part, $0) } }
        if known.allSatisfy({ $0.1 >= 75 }) {
            return (.holdSteady, "Everything is moving together. Keep doing what you're doing.")
        }
        let weakest = known.min { $0.1 < $1.1 }?.0
        switch weakest {
        case .consistency?:
            return (.holdSteady, "Steady weeks build the most. Aim for the sessions you planned — short ones count.")
        case .balance?:
            if let ratio = balance.ratio, ratio < 0.8, (balance.recovery ?? 70) >= 60 {
                return (.pushMore, "You have more in the tank. Add a little intensity this week.")
            }
            return (.holdSteady, "Keep the load even this week and protect your sleep.")
        case .development?:
            if (value(.consistency) ?? 0) >= 70, (balance.recovery ?? 70) >= 55 {
                return (.pushMore, "You're consistent and recovering well — there's room to push your main lifts a little.")
            }
            return (.holdSteady, "Progress follows steady weeks. Keep going, then retest in a few weeks.")
        case .satisfaction?:
            return (.holdSteady, "The work is getting done, but it hasn't felt good. Notice what made the good days good — and talk to someone if it stays heavy.")
        case nil:
            return (.holdSteady, "Keep training as planned.")
        }
    }

    // MARK: Smoothing

    /// The shown value: never more than `maxWeeklyStep` away from last
    /// week's, so one day can't swing it.
    public static func smoothed(_ raw: Int, lastWeek: Int?) -> Int {
        guard let lastWeek else { return raw }
        return min(lastWeek + maxWeeklyStep, max(lastWeek - maxWeeklyStep, raw))
    }

    /// Against about a month ago (or the oldest week there is, two weeks back at least).
    public static func trend(current: Int, history: [(week: Date, value: Int)], now: Date, calendar: Calendar = .current) -> AthleteScore.Trend {
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let monthAgo = calendar.date(byAdding: .day, value: -28, to: now) ?? now
        let older = history.filter { $0.week <= twoWeeksAgo }.sorted { $0.week < $1.week }
        guard let reference = older.last(where: { $0.week <= monthAgo }) ?? older.first else { return .steady }
        let delta = current - reference.value
        return delta >= 3 ? .up : (delta <= -3 ? .down : .steady)
    }

    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        default: items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
        }
    }
}
