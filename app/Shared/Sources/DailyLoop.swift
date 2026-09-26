import Foundation

/// AthleteOS in five steps: PREPARE (morning check-in) → PERFORM (practice
/// and workout) → LEARN (Campus) → REFLECT (evening) → ADAPT (tomorrow's
/// plan). This file is the "adapt" logic that ties them together: today's
/// readiness from the check-in, reported pain and last night's reflection,
/// and the one-sentence reason for today's plan. No scores, no diagnosis.

// MARK: - Pain

public enum PainArea: String, Codable, Sendable, CaseIterable, Identifiable {
    case head, neck, shoulder, arm, back, hip, knee, ankle, other
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .head: "Head"
        case .neck: "Neck"
        case .shoulder: "Shoulder"
        case .arm: "Arm / wrist"
        case .back: "Back"
        case .hip: "Hip / groin"
        case .knee: "Knee"
        case .ankle: "Ankle / foot"
        case .other: "Somewhere else"
        }
    }
}

public enum PainLevel: String, Codable, Sendable, CaseIterable, Identifiable {
    case little, some, lot
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .little: "A little"
        case .some: "Quite a bit"
        case .lot: "A lot"
        }
    }
}

/// Pain or discomfort reported on a day. The app never says what it is —
/// only that training is reduced because of it.
public struct PainReport: Codable, Sendable, Equatable {
    public var day: String
    public var areas: [PainArea]
    public var level: PainLevel

    public init(day: String, areas: [PainArea], level: PainLevel) {
        self.day = day
        self.areas = areas
        self.level = level
    }

    /// A head injury isn't trained through at all.
    public var involvesHead: Bool { areas.contains(.head) }
}

public enum PainStore {
    static let key = "safety.pain"

    public static func all(_ defaults: UserDefaults = .standard) -> [PainReport] {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([PainReport].self, from: $0) } ?? []
    }

    public static func report(on date: Date = .now, calendar: Calendar = .current, _ defaults: UserDefaults = .standard) -> PainReport? {
        let day = DayKey.of(date, calendar: calendar)
        return all(defaults).first { $0.day == day }
    }

    /// Records (or replaces) the day's report; nil clears it. Keeps 60 days.
    public static func set(_ report: PainReport?, on date: Date = .now, calendar: Calendar = .current, _ defaults: UserDefaults = .standard) {
        let day = DayKey.of(date, calendar: calendar)
        var reports = all(defaults).filter { $0.day != day }
        if let report { reports.append(report) }
        reports = Array(reports.sorted { $0.day < $1.day }.suffix(60))
        defaults.set(try? JSONEncoder().encode(reports), forKey: key)
    }
}

// MARK: - The morning answers

/// One answer of the morning check-in and the value it's stored as (the
/// check-in keeps 1–5 scales, so the athlete's own normal still works).
public struct CheckInOption: Hashable, Sendable {
    public let title: String
    public let value: Double

    public init(_ title: String, _ value: Double) {
        self.title = title
        self.value = value
    }

    public var scale: Int { Int(value) }
}

public enum CheckInOptions {
    public static let sleepHours = [
        CheckInOption("Under 6 h", 5.5), CheckInOption("6–7 h", 6.5), CheckInOption("7–8 h", 7.5),
        CheckInOption("8–9 h", 8.5), CheckInOption("9 h or more", 9.5),
    ]
    public static let sleepQuality = [CheckInOption("Poor", 1), CheckInOption("Okay", 3), CheckInOption("Good", 4), CheckInOption("Great", 5)]
    public static let energy = [CheckInOption("Low", 1), CheckInOption("Okay", 3), CheckInOption("Good", 4), CheckInOption("Great", 5)]
    /// 5 is high soreness.
    public static let soreness = [CheckInOption("None", 1), CheckInOption("Mild", 2), CheckInOption("Moderate", 3), CheckInOption("High", 5)]
    /// Stored as stress: 5 is very stressed.
    public static let mood = [CheckInOption("Calm", 1), CheckInOption("Okay", 2), CheckInOption("Stressed", 4), CheckInOption("Very stressed", 5)]

    /// The answer that shows a stored value (an earlier check-in, or hours
    /// from Apple Health).
    public static func nearest(_ value: Double?, in options: [CheckInOption]) -> CheckInOption? {
        guard let value else { return nil }
        return options.min { abs($0.value - value) < abs($1.value - value) }
    }
}

// MARK: - Schedule confirmation

/// "Practice today?" answered in the check-in when the plan got it wrong
/// (a cancelled or an extra practice). Only that day changes.
public enum PracticeOverride {
    static let key = "schedule.dayOverrides"

    /// nil: no override, the schedule decides.
    public static func hasPractice(on day: String, _ defaults: UserDefaults = .standard) -> Bool? {
        let entries = defaults.stringArray(forKey: key) ?? []
        guard let entry = entries.last(where: { $0.hasPrefix(day + "=") }) else { return nil }
        return entry.hasSuffix("=1")
    }

    public static func set(_ hasPractice: Bool?, on day: String, _ defaults: UserDefaults = .standard) {
        var entries = (defaults.stringArray(forKey: key) ?? []).filter { !$0.hasPrefix(day + "=") }
        if let hasPractice { entries.append("\(day)=\(hasPractice ? 1 : 0)") }
        defaults.set(Array(entries.sorted().suffix(60)), forKey: key)
    }
}

// MARK: - The day, done

/// PREPARE → PERFORM → LEARN → REFLECT: what's done today.
public struct DayCompletion: Sendable, Equatable {
    public var checkedIn: Bool
    public var trained: Bool
    public var learned: Bool
    public var reflected: Bool

    public init(checkedIn: Bool, trained: Bool, learned: Bool, reflected: Bool) {
        self.checkedIn = checkedIn
        self.trained = trained
        self.learned = learned
        self.reflected = reflected
    }

    public struct Item: Sendable, Hashable, Identifiable {
        public let title: String
        public let done: Bool
        public var id: String { title }
    }

    public var items: [Item] {
        [Item(title: "Morning check-in", done: checkedIn), Item(title: "Training", done: trained),
         Item(title: "Campus lesson", done: learned), Item(title: "Evening reflection", done: reflected)]
    }

    public var doneCount: Int { items.filter(\.done).count }
}

// MARK: - Readiness

/// Today's readiness in words — never a precise score.
public enum TodayReadiness: Int, Comparable, Sendable {
    case normal = 0, reduced = 1, recovery = 2

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .normal: "Normal"
        case .reduced: "Reduced"
        case .recovery: "Recovery Focus"
        }
    }

    /// The training adjustment it maps to (ReadinessApplier).
    public var band: ReadinessBand {
        switch self {
        case .normal: .green
        case .reduced: .amber
        case .recovery: .red
        }
    }

    init(_ band: ReadinessBand) {
        switch band {
        case .green: self = .normal
        case .amber: self = .reduced
        case .red: self = .recovery
        }
    }
}

/// The morning answers in plain terms (the check-in stores 1–5 scales).
public struct MorningAnswers: Sendable, Equatable {
    /// 1 poor … 5 great.
    public var sleepQuality: Int
    public var sleepHours: Double?
    /// 1 drained … 5 great.
    public var energy: Int
    /// 1 none … 5 high.
    public var soreness: Int
    /// 1 calm … 5 stressed.
    public var stress: Int

    public init(sleepQuality: Int, sleepHours: Double?, energy: Int, soreness: Int, stress: Int) {
        self.sleepQuality = sleepQuality
        self.sleepHours = sleepHours
        self.energy = energy
        self.soreness = soreness
        self.stress = stress
    }
}

/// Last night's reflection, as far as tomorrow's plan cares.
public struct EveningSignal: Sendable, Equatable {
    /// 1 easy … 4 very hard.
    public var hardness: Int?
    /// 1 fresh … 4 very sore / beaten up.
    public var body: Int?

    public init(hardness: Int?, body: Int?) {
        self.hardness = hardness
        self.body = body
    }
}

public enum DailyLoop {
    /// Today's readiness and the one reason that decided it. The most careful
    /// of: the check-in against the athlete's own normal (after a week), the
    /// answers themselves (from day one), reported pain, and how hard
    /// yesterday was.
    public static func readiness(
        answers: MorningAnswers?, personalBand: ReadinessBand?, pain: PainReport?, yesterday: EveningSignal?
    ) -> (level: TodayReadiness, reason: String)? {
        var candidates: [(TodayReadiness, String)] = []
        if let pain {
            let level: TodayReadiness = pain.involvesHead || pain.level != .little ? .recovery : .reduced
            candidates.append((level, "Because you reported pain, your training is reduced today."))
        }
        if let answers {
            var flags = 0
            if (answers.sleepHours ?? 8) < 6 || answers.sleepQuality <= 1 { flags += 1 }
            if answers.energy <= 1 { flags += 1 }
            if answers.soreness >= 5 { flags += 1 }
            if answers.stress >= 5 { flags += 1 }
            if flags >= 2 {
                candidates.append((.recovery, "Low sleep and energy together: a recovery day helps you bounce back."))
            } else if flags == 1 || answers.soreness >= 4 || answers.energy <= 2 {
                let reason = answers.soreness >= 4 ? "You're more sore than usual, so today is a bit lighter."
                    : (answers.energy <= 2 ? "Your energy is low, so today is a bit lighter."
                       : ((answers.sleepHours ?? 8) < 6 ? "Short sleep, so today is a bit lighter." : "You're feeling the load, so today is a bit lighter."))
                candidates.append((.reduced, reason))
            } else {
                candidates.append((.normal, "You're feeling good — train as planned."))
            }
        }
        if let personalBand {
            let level = TodayReadiness(personalBand)
            if level > .normal {
                candidates.append((level, "Below your usual for this time of the season, so today is lighter."))
            }
        }
        if let yesterday, (yesterday.hardness ?? 0) >= 4 || (yesterday.body ?? 0) >= 4 {
            candidates.append((.reduced, "Yesterday was very hard, so today is a bit lighter."))
        }
        guard !candidates.isEmpty else { return nil }
        // The most careful wins; among equals, the first reason (pain first).
        let top = candidates.map(\.0).max() ?? .normal
        return candidates.first { $0.0 == top }.map { ($0.0, $0.1) }
    }

    /// Why today's plan looks the way it does, in one sentence.
    public static func whyThisPlan(
        status: DayStatus, mode: WorkoutMode?, practiceToday: Bool, gameToday: Bool, daysToNextGame: Int?,
        readiness: (level: TodayReadiness, reason: String)?
    ) -> String {
        switch status {
        case .sick: return "You're resting today, so there's no training."
        case .concussion: return "Training is paused until a doctor clears you."
        case .travel: return "A short workout you can do anywhere — only if you feel like it."
        case .holiday: return "Your plan is paused. A light workout is optional."
        case .active: break
        }
        if gameToday { return "Game day: no workout — save your energy for the game." }
        if let readiness, readiness.level > .normal { return readiness.reason }
        if let days = daysToNextGame, days <= 2, mode == .gymDay || mode == .afterPractice {
            return "Game in \(days == 1 ? "1 day" : "\(days) days"), so today stays short and sharp."
        }
        switch mode {
        case .afterPractice?: return "You have practice today, so the gym work is short and complements it."
        case .gymDay?: return "No team practice today, so this is your main strength session."
        case .mobility?: return "A rest day: a few minutes of movement keeps you fresh."
        case .travel?: return "A short workout you can do anywhere."
        case nil: return practiceToday ? "Practice is today's training." : "A rest day — recovery is part of the plan."
        }
    }
}
