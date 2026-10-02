import Foundation

/// The athletic capacities every athlete develops (docs/VERSION-6.md §4).
/// The sport changes the priorities; it never removes the need for the rest.
public enum Capacity: String, CaseIterable, Codable, Sendable {
    case strength
    case upperStrength
    case power
    case acceleration
    case speed
    case deceleration
    case coordination
    case aerobic
    case repeatedEffort
    case mobility
    case trunk
    case balance
    case resilience

    public var title: String {
        switch self {
        case .strength: "lower-body strength"
        case .upperStrength: "upper-body strength"
        case .power: "power"
        case .acceleration: "acceleration"
        case .speed: "top speed"
        case .deceleration: "braking and landing"
        case .coordination: "change of direction"
        case .aerobic: "aerobic fitness"
        case .repeatedEffort: "repeated-effort fitness"
        case .mobility: "mobility"
        case .trunk: "trunk strength"
        case .balance: "balance and stability"
        case .resilience: "injury resilience"
        }
    }

    /// Which catalogue qualities build it.
    static let fromQuality: [String: Capacity] = [
        "lower-body-strength": .strength,
        "upper-body-push": .upperStrength, "upper-body-pull": .upperStrength, "grip": .upperStrength,
        "vertical-power": .power, "horizontal-power": .power, "rotational-power": .power, "overhead-power": .power, "reactive-strength": .power,
        "acceleration": .acceleration, "max-velocity": .speed,
        "deceleration": .deceleration, "landing-mechanics": .deceleration,
        "change-of-direction": .coordination, "lateral-power": .coordination,
        "aerobic-base": .aerobic, "repeat-sprint": .repeatedEffort, "anaerobic-capacity": .repeatedEffort,
        "hip-mobility": .mobility, "trunk-anti-rotation": .trunk,
        "single-leg-stability": .balance, "ankle-stiffness": .balance,
        "shoulder-stability": .resilience,
    ]
}

/// The kinds of conditioning (§5). Cardio is programmed, never randomly added.
public enum ConditioningType: String, CaseIterable, Codable, Sendable {
    /// Longer, easy work.
    case aerobicBase = "aerobic-base"
    /// Structured harder intervals.
    case aerobicPower = "aerobic-power"
    /// Controlled moderate intensity.
    case tempo
    /// Repeated bursts with recovery.
    case repeatedSprint = "repeated-sprint"
    /// Short, very hard efforts (wrestling, gymnastics).
    case anaerobic
    /// Very light movement.
    case recovery

    public var title: String {
        switch self {
        case .aerobicBase: "Aerobic base"
        case .aerobicPower: "Aerobic intervals"
        case .tempo: "Tempo conditioning"
        case .repeatedSprint: "Repeated sprints"
        case .anaerobic: "Short hard efforts"
        case .recovery: "Recovery cardio"
        }
    }
}

/// What a sport's practice already does to an athlete, and what it needs on top.
public struct SportDemands: Sendable, Equatable {
    /// Conditioning practice provides: 0 none (golf) … 3 enormous (cross country).
    public var practiceConditioning: Int
    /// What kind practice provides (nil: none).
    public var practiceConditioningType: ConditioningType?
    /// How hard practice is on the legs: 0 … 3 (sprinting, cutting, jumping).
    public var practiceLegLoad: Int
    /// The conditioning the sport needs.
    public var need: ConditioningType
    /// Weekly conditioning minutes to program when team practice isn't
    /// providing it (off-season, or a sport whose practice doesn't). 0: the
    /// sport itself is the conditioning — never add random extra running.
    public var weeklyMinutesWithoutPractice: Int
    /// How much each capacity matters, 0…1, with a general-development floor.
    public var weights: [Capacity: Double]

    /// Conditioning minutes to program this week beyond what practice gives.
    public func conditioningMinutes(practiceDays: Int, phase: SeasonPhase) -> Int {
        guard weeklyMinutesWithoutPractice > 0 else { return 0 }
        if phase == .postSeason { return weeklyMinutesWithoutPractice / 2 }
        if practiceDays == 0 { return weeklyMinutesWithoutPractice }
        switch practiceConditioning {
        case 3: return 0
        case 2: return practiceDays >= 3 ? 0 : weeklyMinutesWithoutPractice / 3
        case 1: return weeklyMinutesWithoutPractice / 2
        default: return weeklyMinutesWithoutPractice
        }
    }
}

public enum SportDemandsTable {
    // slug: practiceConditioning practiceType legLoad need weeklyMinutes
    private static let table = """
    archery: 0 none 0 aerobic-base 60
    badminton: 2 repeated-sprint 2 aerobic-power 60
    baseball: 1 repeated-sprint 2 repeated-sprint 45
    basketball: 2 repeated-sprint 3 repeated-sprint 60
    bmx: 1 anaerobic 2 anaerobic 45
    boccia: 0 none 0 aerobic-base 40
    bowling: 0 none 1 aerobic-base 60
    climbing: 1 anaerobic 1 aerobic-base 60
    color-guard: 2 aerobic-base 2 aerobic-power 45
    competitive-dance: 2 aerobic-base 2 aerobic-power 45
    competitive-spirit: 2 anaerobic 3 anaerobic 45
    cross-country: 3 aerobic-base 3 aerobic-base 0
    crossfit-style-conditioning: 3 anaerobic 2 aerobic-power 0
    cycling: 3 aerobic-base 2 aerobic-base 0
    disc-golf: 1 aerobic-base 1 aerobic-base 45
    equestrian: 1 aerobic-base 1 aerobic-base 60
    esports-physical-conditioning: 0 none 0 aerobic-base 75
    fencing: 2 repeated-sprint 2 repeated-sprint 45
    field-hockey: 2 repeated-sprint 3 repeated-sprint 60
    flag-football: 2 repeated-sprint 2 repeated-sprint 60
    football: 2 repeated-sprint 3 repeated-sprint 60
    goalball: 1 anaerobic 1 aerobic-base 60
    golf: 0 none 1 aerobic-base 60
    gymnastics: 2 anaerobic 3 anaerobic 30
    ice-hockey: 2 repeated-sprint 3 repeated-sprint 60
    indoor-track-and-field: 2 anaerobic 3 tempo 30
    judo: 2 anaerobic 2 anaerobic 45
    lacrosse: 2 repeated-sprint 3 repeated-sprint 60
    marching-band-athletics: 2 aerobic-base 2 aerobic-base 45
    mountain-biking: 3 aerobic-base 2 aerobic-base 0
    netball: 2 repeated-sprint 3 repeated-sprint 60
    orienteering: 3 aerobic-base 3 aerobic-base 0
    pickleball: 1 repeated-sprint 1 aerobic-power 60
    powerlifting: 0 none 2 aerobic-base 45
    racquetball: 2 repeated-sprint 2 aerobic-power 45
    rifle: 0 none 0 aerobic-base 60
    rowing: 3 aerobic-base 2 aerobic-base 0
    rugby: 2 repeated-sprint 3 repeated-sprint 60
    sailing: 1 aerobic-base 1 aerobic-base 60
    skateboarding: 1 anaerobic 2 aerobic-base 45
    skiing: 1 anaerobic 2 aerobic-power 60
    snowboarding: 1 anaerobic 2 aerobic-power 60
    soccer: 3 repeated-sprint 3 aerobic-power 60
    softball: 1 repeated-sprint 2 repeated-sprint 45
    spikeball: 1 repeated-sprint 1 aerobic-power 45
    squash: 2 repeated-sprint 2 aerobic-power 45
    step-team: 2 aerobic-base 2 aerobic-power 45
    surfing: 2 aerobic-base 1 aerobic-base 45
    swimming-diving: 3 aerobic-base 1 aerobic-base 0
    table-tennis: 1 repeated-sprint 1 aerobic-base 45
    team-handball: 2 repeated-sprint 3 repeated-sprint 60
    tennis: 2 repeated-sprint 2 aerobic-power 60
    track-and-field: 2 anaerobic 3 tempo 30
    triathlon: 3 aerobic-base 2 aerobic-base 0
    ultimate: 2 repeated-sprint 3 repeated-sprint 60
    unified-sports: 1 repeated-sprint 1 aerobic-base 45
    volleyball: 1 anaerobic 3 repeated-sprint 45
    water-polo: 3 aerobic-base 1 aerobic-power 0
    weightlifting: 0 none 2 aerobic-base 40
    wrestling: 3 anaerobic 2 anaerobic 30
    """

    // sport/position: the same fields, where a position really differs.
    private static let positions = """
    football/lineman: 2 anaerobic 3 anaerobic 45
    football/quarterback: 1 repeated-sprint 2 repeated-sprint 45
    soccer/goalkeeper: 1 anaerobic 2 anaerobic 30
    soccer/midfielder: 3 aerobic-power 3 aerobic-power 75
    field-hockey/goalkeeper: 1 anaerobic 2 anaerobic 30
    ice-hockey/goaltender: 1 anaerobic 2 anaerobic 30
    lacrosse/goalie: 1 anaerobic 2 anaerobic 30
    lacrosse/midfield: 3 repeated-sprint 3 aerobic-power 60
    baseball/pitcher: 1 none 2 tempo 45
    baseball/catcher: 1 none 3 repeated-sprint 45
    softball/pitcher: 1 none 2 tempo 45
    track-and-field/distance: 3 aerobic-base 3 aerobic-base 0
    track-and-field/sprints: 2 anaerobic 3 tempo 30
    track-and-field/throws: 0 none 2 aerobic-base 40
    track-and-field/jumps: 1 anaerobic 3 tempo 30
    indoor-track-and-field/distance: 3 aerobic-base 3 aerobic-base 0
    indoor-track-and-field/throws: 0 none 2 aerobic-base 40
    swimming-diving/diver: 1 none 2 aerobic-base 40
    """

    private struct Row: Sendable {
        let conditioning: Int
        let type: ConditioningType?
        let legLoad: Int
        let need: ConditioningType
        let minutes: Int
    }

    private static func parse(_ text: String) -> [String: Row] {
        var out: [String: Row] = [:]
        for line in text.split(separator: "\n") {
            let halves = line.split(separator: ":", maxSplits: 1)
            guard halves.count == 2 else { continue }
            let f = halves[1].split(separator: " ").map(String.init)
            guard f.count == 5, let c = Int(f[0]), let l = Int(f[2]), let m = Int(f[4]), let need = ConditioningType(rawValue: f[3]) else { continue }
            out[halves[0].trimmingCharacters(in: .whitespaces)] = Row(conditioning: c, type: ConditioningType(rawValue: f[1]), legLoad: l, need: need, minutes: m)
        }
        return out
    }

    private static let sports = parse(table)
    private static let byPosition = parse(positions)

    /// The demands for an athlete's sport and position; a sport not in the
    /// table (a new pack) gets a middle-of-the-road field-sport default.
    public static func demands(sport: SportInfo?, position: String?) -> SportDemands {
        let slug = sport?.slug ?? ""
        let row = position.flatMap { byPosition["\(slug)/\($0)"] } ?? sports[slug]
            ?? Row(conditioning: 1, type: .repeatedSprint, legLoad: 2, need: .aerobicBase, minutes: 45)
        let positionProfile = position.flatMap { p in sport?.positions.first { $0.slug == p }?.qualityProfile }
        return SportDemands(practiceConditioning: row.conditioning, practiceConditioningType: row.type, practiceLegLoad: row.legLoad,
                            need: row.need, weeklyMinutesWithoutPractice: row.minutes,
                            weights: weights(sport: sport?.qualityProfile ?? [:], position: positionProfile))
    }

    /// Capacity weights: the sport's (and position's) quality profile, on top
    /// of a floor every athlete gets — strength and trunk matter for all.
    static func weights(sport: [String: Double], position: [String: Double]?) -> [Capacity: Double] {
        var out: [Capacity: Double] = [:]
        for capacity in Capacity.allCases { out[capacity] = 0.3 }
        out[.strength] = 0.55
        out[.trunk] = 0.5
        out[.upperStrength] = 0.4
        out[.resilience] = 0.4
        var merged = sport
        if let position {
            merged = merged.mapValues { $0 * 0.5 }
            for (quality, weight) in position { merged[quality] = max(merged[quality] ?? 0, weight) }
        }
        for (quality, weight) in merged {
            guard let capacity = Capacity.fromQuality[quality] else { continue }
            out[capacity] = max(out[capacity] ?? 0, min(1, weight))
        }
        return out
    }
}
