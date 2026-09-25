import Foundation

// MARK: - What kind of workout a logged session was

/// The kinds of workout, each with its colour on the Progress calendar.
public enum WorkoutKind: String, Codable, Sendable, CaseIterable {
    /// A full gym day (no team practice that day).
    case gym
    /// The short extra workout after team practice.
    case afterPractice
    /// Stretching and mobility.
    case mobility
    /// The anywhere workout on travel days.
    case travel
    /// A workout the coach sent.
    case coach
}

/// Which kind each logged session was, by the session's `clientId`
/// (kept under `progress.` so it's backed up with the settings).
public enum SessionKinds {
    static let key = "progress.sessionKinds"

    public static var all: [String: WorkoutKind] {
        get { UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([String: WorkoutKind].self, from: $0) } ?? [:] }
        set {
            // Keep it from growing forever: the newest 1500 are plenty.
            let kept = newValue.count > 1500 ? Dictionary(uniqueKeysWithValues: newValue.sorted { $0.key < $1.key }.suffix(1500).map { ($0.key, $0.value) }) : newValue
            UserDefaults.standard.set(try? JSONEncoder().encode(kept), forKey: key)
        }
    }

    public static func record(_ clientId: String, _ kind: WorkoutKind?) {
        guard let kind else { return }
        var map = all
        map[clientId] = kind
        all = map
    }

    public static func kind(of clientId: String) -> WorkoutKind? { all[clientId] }
}

// MARK: - Team practice

/// How much detail the athlete wants to log about team practice.
public enum TrackingLevel: String, Codable, Sendable, CaseIterable {
    /// How hard, how it went, mood afterwards.
    case easy
    /// Plus which muscles are tired and how each part of the game went.
    case exact

    static let key = "progress.trackingLevel"

    public static var current: TrackingLevel {
        get { UserDefaults.standard.string(forKey: key).flatMap(TrackingLevel.init(rawValue:)) ?? .easy }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

/// One team practice, as the athlete logged it.
public struct PracticeLog: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    /// YYYY-MM-DD
    public var day: String
    public var sportSlug: String
    /// What the practice was made of ("Range session", "Putting"…).
    public var types: [String]
    /// 1 (easy) … 5 (exhausting)
    public var hard: Int
    /// 1 (badly) … 5 (great)
    public var went: Int
    /// 1 … 5, how the athlete felt afterwards
    public var mood: Int
    public var minutes: Int?
    /// Exact tracking: muscle groups that feel worked.
    public var tiredMuscles: [String]
    /// Exact tracking: each part of the game (club, stroke, skill) → 1 poor … 4 great.
    public var ratings: [String: Int]
    public var note: String?

    public init(id: String = UUID().uuidString, day: String, sportSlug: String, types: [String], hard: Int, went: Int, mood: Int,
                minutes: Int? = nil, tiredMuscles: [String] = [], ratings: [String: Int] = [:], note: String? = nil) {
        self.id = id
        self.day = day
        self.sportSlug = sportSlug
        self.types = types
        self.hard = hard
        self.went = went
        self.mood = mood
        self.minutes = minutes
        self.tiredMuscles = tiredMuscles
        self.ratings = ratings
        self.note = note
    }
}

public enum PracticeLogStore {
    static let key = "progress.practiceLogs"

    public static var logs: [PracticeLog] {
        get { UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([PracticeLog].self, from: $0) } ?? [] }
        set {
            let kept = Array(newValue.sorted { $0.day > $1.day }.prefix(600))
            UserDefaults.standard.set(try? JSONEncoder().encode(kept), forKey: key)
        }
    }

    /// One log per day and sport: saving again replaces it.
    public static func save(_ log: PracticeLog) {
        var all = logs.filter { $0.id != log.id && !($0.day == log.day && $0.sportSlug == log.sportSlug) }
        all.append(log)
        logs = all
    }

    public static func delete(_ log: PracticeLog) {
        logs = logs.filter { $0.id != log.id }
    }

    public static func log(on day: String, sportSlug: String? = nil) -> PracticeLog? {
        logs.first { $0.day == day && (sportSlug == nil || $0.sportSlug == sportSlug) }
    }
}

/// What a team practice is made of, per sport — so the athlete can see what
/// they practised most and least.
public enum SportPractice {
    public static func types(for sportSlug: String?) -> [String] {
        switch sportSlug {
        case "golf": return ["Range session", "Chipping", "Pitching", "Bunker", "Putting", "Course play", "Tournament round"]
        case "tennis": return ["Serve", "Groundstrokes", "Volleys & net", "Return", "Footwork", "Match play", "Fitness"]
        case "badminton": return ["Footwork", "Clears & drops", "Smash", "Net play", "Serve & return", "Match play", "Fitness"]
        case "basketball": return ["Shooting", "Ball handling", "Passing", "Defense", "Rebounding", "Plays", "Scrimmage", "Conditioning"]
        case "soccer": return ["Passing & first touch", "Shooting", "Dribbling", "Small-sided games", "Tactics", "Set pieces", "Scrimmage", "Conditioning"]
        case "football", "flag-football": return ["Position drills", "Routes & catching", "Blocking", "Tackling", "Plays", "Film", "Scrimmage", "Conditioning"]
        case "volleyball": return ["Serving", "Passing", "Setting", "Attacking", "Blocking", "Defense", "Scrimmage", "Conditioning"]
        case "baseball", "softball": return ["Hitting", "Fielding", "Throwing", "Pitching", "Base running", "Bunting", "Scrimmage"]
        case "ice-hockey", "field-hockey", "lacrosse": return ["Stickhandling", "Passing", "Shooting", "Skating / footwork", "Defense", "Systems", "Scrimmage", "Conditioning"]
        case "swimming-diving": return ["Aerobic set", "Sprint set", "Kick", "Pull", "Technique", "Starts & turns", "Race pace"]
        case "track-and-field", "indoor-track-and-field": return ["Starts & acceleration", "Speed", "Speed endurance", "Technique", "Jumps", "Throws", "Tempo run", "Hurdles"]
        case "cross-country": return ["Easy run", "Long run", "Tempo", "Intervals", "Hills", "Race"]
        case "wrestling": return ["Takedowns", "Top", "Bottom", "Live wrestling", "Drilling", "Conditioning"]
        case "gymnastics": return ["Floor", "Vault", "Bars", "Beam", "Rings / pommel", "Conditioning", "Flexibility"]
        case "competitive-spirit": return ["Stunts", "Tumbling", "Jumps", "Dance", "Full routine", "Conditioning"]
        case "rowing": return ["Steady state", "Intervals", "Technique", "On water", "Erg test"]
        case "water-polo": return ["Swimming", "Passing", "Shooting", "Eggbeater", "Defense", "Scrimmage"]
        case "rugby": return ["Passing", "Tackling", "Rucks & mauls", "Set piece", "Plays", "Scrimmage", "Conditioning"]
        case "bowling": return ["Strike ball", "Spare shooting", "Lane play", "Game", "Tournament"]
        case "weightlifting": return ["Snatch", "Clean & jerk", "Squats", "Pulls", "Technique", "Max day"]
        case "skiing", "snowboarding": return ["Technique", "Gates / course", "Freeride", "Park", "Race training"]
        case "mountain-biking": return ["Endurance ride", "Intervals", "Technical skills", "Downhill", "Race"]
        default: return ["Technique", "Skills drills", "Tactics", "Game play", "Conditioning", "Strength"]
        }
    }

    /// The parts of the game an exact log rates, e.g. golf clubs.
    public static func components(for sportSlug: String?) -> (title: String, items: [String]) {
        switch sportSlug {
        case "golf": return ("How each club went", ["Driver", "Woods & hybrids", "Irons", "Wedges", "Putter"])
        case "tennis", "badminton": return ("How each stroke went", ["Serve", "Forehand", "Backhand", "Volley / net", "Return"])
        case "basketball": return ("How each skill went", ["Shooting", "Free throws", "Ball handling", "Passing", "Defense"])
        case "soccer": return ("How each skill went", ["First touch", "Passing", "Shooting", "Dribbling", "Defending"])
        case "volleyball": return ("How each skill went", ["Serve", "Pass", "Set", "Attack", "Block"])
        case "baseball", "softball": return ("How each skill went", ["Hitting", "Fielding", "Throwing", "Pitching", "Base running"])
        case "swimming-diving": return ("How each part went", ["Starts", "Turns", "Freestyle", "Other strokes", "Kick"])
        case "track-and-field", "indoor-track-and-field", "cross-country": return ("How each part went", ["Start", "Acceleration", "Top speed", "Technique", "Endurance"])
        case "football", "flag-football", "rugby": return ("How each skill went", ["Catching", "Passing", "Tackling / blocking", "Speed", "Reading the play"])
        case "ice-hockey", "field-hockey", "lacrosse": return ("How each skill went", ["Stickhandling", "Passing", "Shooting", "Skating / footwork", "Defense"])
        default: return ("How each part went", ["Technique", "Fitness", "Tactics", "Focus"])
        }
    }

    public static let ratingWords = ["Poor", "Okay", "Good", "Great"]
}

public enum PracticeStats {
    /// How often each kind of practice was done, most first.
    public static func counts(_ logs: [PracticeLog], since day: String? = nil) -> [(type: String, count: Int)] {
        var counts: [String: Int] = [:]
        for log in logs where day.map({ log.day >= $0 }) ?? true {
            for type in log.types { counts[type, default: 0] += 1 }
        }
        return counts.map { (type: $0.key, count: $0.value) }.sorted { $0.count != $1.count ? $0.count > $1.count : $0.type < $1.type }
    }

    /// Average rating (1–4) of each part of the game, from exact logs.
    public static func ratings(_ logs: [PracticeLog], since day: String? = nil) -> [(item: String, average: Double, times: Int)] {
        var totals: [String: (sum: Int, n: Int)] = [:]
        for log in logs where day.map({ log.day >= $0 }) ?? true {
            for (item, value) in log.ratings {
                let current = totals[item] ?? (0, 0)
                totals[item] = (current.sum + value, current.n + 1)
            }
        }
        return totals.map { (item: $0.key, average: Double($0.value.sum) / Double($0.value.n), times: $0.value.n) }
            .sorted { $0.average != $1.average ? $0.average > $1.average : $0.item < $1.item }
    }

    /// "Putting: only 2 of your last 20 practices." — the least practised
    /// type, when it's clearly behind.
    public static func insight(_ counts: [(type: String, count: Int)], allTypes: [String]) -> String? {
        guard let top = counts.first, top.count >= 4 else { return nil }
        let counted = Dictionary(uniqueKeysWithValues: counts.map { ($0.type, $0.count) })
        let least = allTypes.map { (type: $0, count: counted[$0] ?? 0) }.min { $0.count < $1.count }
        guard let least, least.count * 3 <= top.count else { return nil }
        return least.count == 0
            ? "You haven't logged any \(least.type.lowercased()) yet — \(top.type.lowercased()) \(top.count) times. If \(least.type.lowercased()) feels weak, that may be why."
            : "\(least.type): \(least.count) times, against \(top.count) for \(top.type.lowercased()). If \(least.type.lowercased()) feels weak, that may be why."
    }
}

// MARK: - Practice times and extra events

/// The time team practice starts and ends on each practice weekday.
public struct PracticeTime: Codable, Sendable, Equatable {
    /// Minutes after midnight.
    public var start: Int
    public var end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    public var label: String {
        func text(_ minutes: Int) -> String {
            let date = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
            return date.formatted(date: .omitted, time: .shortened)
        }
        return "\(text(start)) – \(text(end))"
    }
}

public enum PracticeTimes {
    static let key = "schedule.practiceTimes"

    /// Weekday (1 = Sunday) → time.
    public static var all: [Int: PracticeTime] {
        get {
            let raw = UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([String: PracticeTime].self, from: $0) } ?? [:]
            return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in Int(key).map { ($0, value) } })
        }
        set {
            let raw = Dictionary(uniqueKeysWithValues: newValue.map { (String($0.key), $0.value) })
            UserDefaults.standard.set(try? JSONEncoder().encode(raw), forKey: key)
        }
    }
}

/// A one-off team training on a given day (a Saturday session, a camp).
public struct ExtraPractice: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    /// YYYY-MM-DD
    public var day: String
    public var title: String
    public var time: PracticeTime?

    public init(id: String = UUID().uuidString, day: String, title: String, time: PracticeTime? = nil) {
        self.id = id
        self.day = day
        self.title = title
        self.time = time
    }
}

public enum ExtraPractices {
    static let key = "schedule.extraPractices"

    public static var all: [ExtraPractice] {
        get { UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([ExtraPractice].self, from: $0) } ?? [] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue.sorted { $0.day < $1.day }), forKey: key) }
    }

    public static func on(_ day: String) -> [ExtraPractice] { all.filter { $0.day == day } }
}

public enum DayKey {
    /// YYYY-MM-DD in the athlete's calendar.
    public static func of(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - Struggles

/// What the athlete wants to fix — the plan leans towards it.
public enum Struggle: String, Codable, Sendable, CaseIterable, Identifiable {
    case speed, endurance, strength, power, agility, mobility, balance, core
    case loseWeight, gainMuscle, injuryComeback, nerves, sleep

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .speed: "Speed"
        case .endurance: "Stamina / endurance"
        case .strength: "Strength"
        case .power: "Jumping & power"
        case .agility: "Agility & change of direction"
        case .mobility: "Flexibility & mobility"
        case .balance: "Balance & stability"
        case .core: "Core"
        case .loseWeight: "Losing weight"
        case .gainMuscle: "Gaining muscle"
        case .injuryComeback: "Coming back from an injury"
        case .nerves: "Nerves & focus"
        case .sleep: "Sleep & recovery"
        }
    }

    public var systemImage: String {
        switch self {
        case .speed: "hare.fill"
        case .endurance: "lungs.fill"
        case .strength: "dumbbell.fill"
        case .power: "arrow.up.to.line"
        case .agility: "arrow.triangle.turn.up.right.diamond.fill"
        case .mobility: "figure.flexibility"
        case .balance: "figure.stand"
        case .core: "figure.core.training"
        case .loseWeight: "scalemass.fill"
        case .gainMuscle: "figure.strengthtraining.traditional"
        case .injuryComeback: "bandage.fill"
        case .nerves: "brain.head.profile"
        case .sleep: "moon.zzz.fill"
        }
    }

    /// What the app does about it, in one line.
    public var whatChanges: String {
        switch self {
        case .speed: "More acceleration and top-speed work, and springy lower legs."
        case .endurance: "More conditioning for repeated sprints and a bigger engine."
        case .strength: "More leg, push and pull strength."
        case .power: "More jumping and explosive work."
        case .agility: "More braking, cutting and side-to-side power."
        case .mobility: "Longer daily mobility and more hip and shoulder range."
        case .balance: "More single-leg strength and ankle control."
        case .core: "More trunk work that resists twisting and bending."
        case .loseWeight: "More conditioning. The app never counts calories or sets a diet — talk to a doctor or sports dietitian first, especially if you're under 18."
        case .gainMuscle: "More strength work and a reminder to eat enough protein and carbs around training."
        case .injuryComeback: "More landing, braking and single-leg control. Follow your physio or athletic trainer first."
        case .nerves: "Your Mindset tools come first: breathing, visualization and a reset word."
        case .sleep: "Evening mobility and breathing to wind down, and bedtime reminders in your reflection."
        }
    }

    /// Extra weight for training qualities in the plan.
    public var boosts: [String: Double] {
        switch self {
        case .speed: ["acceleration": 1, "max-velocity": 1, "reactive-strength": 0.6, "ankle-stiffness": 0.5]
        case .endurance: ["aerobic-base": 1, "repeat-sprint": 0.8, "anaerobic-capacity": 0.6]
        case .strength: ["lower-body-strength": 1, "upper-body-push": 0.8, "upper-body-pull": 0.8]
        case .power: ["vertical-power": 1, "horizontal-power": 0.8, "reactive-strength": 0.7]
        case .agility: ["change-of-direction": 1, "deceleration": 0.8, "lateral-power": 0.7]
        case .mobility: ["hip-mobility": 1, "shoulder-stability": 0.5]
        case .balance: ["single-leg-stability": 1, "ankle-stiffness": 0.6]
        case .core: ["trunk-anti-rotation": 1]
        case .loseWeight: ["aerobic-base": 0.8, "repeat-sprint": 0.6, "anaerobic-capacity": 0.6]
        case .gainMuscle: ["lower-body-strength": 0.8, "upper-body-push": 0.8, "upper-body-pull": 0.8]
        case .injuryComeback: ["landing-mechanics": 0.8, "single-leg-stability": 0.8, "deceleration": 0.6]
        case .nerves, .sleep: [:]
        }
    }
}

public enum Struggles {
    static let key = "profile.struggles"
    public static let maximum = 3

    public static var selected: [Struggle] {
        get { (UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(Struggle.init(rawValue:)) }
        set { UserDefaults.standard.set(Array(newValue.prefix(maximum)).map(\.rawValue), forKey: key) }
    }

    /// A position (or sport) profile with the struggles' qualities added on
    /// top, so the plan leans towards them without losing the sport.
    public static func profile(base: [String: Double], struggles: [Struggle]) -> [String: Double] {
        guard !struggles.isEmpty else { return base }
        var merged = base
        for struggle in struggles {
            for (quality, weight) in struggle.boosts {
                merged[quality] = (merged[quality] ?? 0) + weight * 0.6
            }
        }
        return merged
    }

    /// The training quality to add an exercise for after practice.
    public static func topQuality(_ struggles: [Struggle]) -> String? {
        struggles.lazy.compactMap { $0.boosts.max { $0.value < $1.value }?.key }.first
    }
}
