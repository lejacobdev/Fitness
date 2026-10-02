import Foundation

/// V6 exercise knowledge (docs/VERSION-6.md §10): what an exercise is for
/// the planner. Authored in content/src/profiles.js and shipped in the packs.
public struct ExerciseProfile: Codable, Sendable, Hashable {
    public struct Conditioning: Codable, Sendable, Hashable {
        /// aerobic-base · aerobic-power · tempo · repeated-sprint · anaerobic
        public let type: String
        /// run · bike · row · rope · bodyweight · stairs · sled
        public let modality: String
    }

    /// squat · hinge · push · pull · carry · rotation · anti-rotation ·
    /// unilateral-lower · jump · throw · sprint · deceleration ·
    /// change-of-direction · locomotion · conditioning · mobility · isolation ·
    /// balance · breathing · skill
    public let pattern: String
    /// prep · power · speed · primary · secondary · accessory · trunk ·
    /// conditioning · mobility · recovery · skill
    public let role: String
    /// lower · upper · trunk
    public let regions: [String]
    /// 1 (barely any) … 5 (a heavy compound, a hard interval set).
    public let fatigue: Int
    /// 0 none … 3 high (jumps, max sprints).
    public let impact: Int
    /// 1 simple … 3 needs coaching.
    public let technique: Int
    /// 0 … 3: how much it adds to tired legs.
    public let legLoad: Int
    /// Exercises in the same group can stand in for each other.
    public let group: String
    public let conditioning: Conditioning?

    public init(pattern: String, role: String, regions: [String], fatigue: Int, impact: Int, technique: Int,
                legLoad: Int, group: String, conditioning: Conditioning? = nil) {
        self.pattern = pattern
        self.role = role
        self.regions = regions
        self.fatigue = fatigue
        self.impact = impact
        self.technique = technique
        self.legLoad = legLoad
        self.group = group
        self.conditioning = conditioning
    }

    public var isLower: Bool { regions.contains("lower") }
    public var isUpper: Bool { regions.contains("upper") }
}

extension CatalogueItem {
    /// The pack's profile, or — for a pack downloaded before profiles
    /// existed — a conservative one from the item's qualities.
    public var planProfile: ExerciseProfile {
        if let profile { return profile }
        let top = qualities.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key ?? ""
        let jumps = defaultDose.kind == plyometricDoseKind
        if kind == "drill" {
            return ExerciseProfile(pattern: "skill", role: "skill", regions: ["lower"], fatigue: 2, impact: jumps ? 3 : 1,
                                   technique: 2, legLoad: 2, group: "skill-\(itemSportSlug ?? "general")")
        }
        switch top {
        case "acceleration", "max-velocity", "change-of-direction", "lateral-power", "deceleration":
            return ExerciseProfile(pattern: "sprint", role: "speed", regions: ["lower"], fatigue: 2, impact: 2, technique: 1, legLoad: 2, group: "speed")
        case "vertical-power", "horizontal-power", "rotational-power", "overhead-power", "reactive-strength":
            return ExerciseProfile(pattern: jumps ? "jump" : "throw", role: "power", regions: ["lower"], fatigue: 2, impact: jumps ? 3 : 0,
                                   technique: 1, legLoad: jumps ? 2 : 1, group: "power")
        case "aerobic-base", "anaerobic-capacity", "repeat-sprint":
            return ExerciseProfile(pattern: "conditioning", role: "conditioning", regions: ["lower"], fatigue: 3, impact: 2, technique: 1,
                                   legLoad: 2, group: "conditioning-interval", conditioning: .init(type: "aerobic-power", modality: "run"))
        case "lower-body-strength":
            return ExerciseProfile(pattern: "squat", role: "secondary", regions: ["lower"], fatigue: 3, impact: 0, technique: 1, legLoad: 2, group: "squat-bilateral")
        case "upper-body-push":
            return ExerciseProfile(pattern: "push", role: "secondary", regions: ["upper"], fatigue: 2, impact: 0, technique: 1, legLoad: 0, group: "push-horizontal")
        case "upper-body-pull":
            return ExerciseProfile(pattern: "pull", role: "secondary", regions: ["upper"], fatigue: 2, impact: 0, technique: 1, legLoad: 0, group: "pull-horizontal")
        case "trunk-anti-rotation":
            return ExerciseProfile(pattern: "anti-rotation", role: "trunk", regions: ["trunk"], fatigue: 1, impact: 0, technique: 1, legLoad: 0, group: "anti-rotation")
        case "hip-mobility":
            return ExerciseProfile(pattern: "mobility", role: "mobility", regions: ["lower"], fatigue: 1, impact: 0, technique: 1, legLoad: 0, group: "mobility-hip")
        default:
            return ExerciseProfile(pattern: "isolation", role: "accessory", regions: ["lower"], fatigue: 1, impact: 0, technique: 1, legLoad: 1, group: "accessory")
        }
    }
}
