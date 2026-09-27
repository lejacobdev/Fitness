import Foundation

/// How long the athlete has been lifting (Me → Training Setup). New lifters
/// get fewer sets, moderate reps, fewer jumps and no explosive or one-leg
/// variants; experienced lifters get an extra set, still inside the youth
/// envelope. Kept as a `profile.` setting, so it's backed up with the rest.
public enum TrainingExperience: String, CaseIterable, Codable, Sendable {
    case beginner
    case intermediate
    case experienced

    static let key = "profile.trainingExperience"

    /// What the athlete picked; nil until they pick (the plan then treats
    /// them as `.intermediate`, which is how it always built plans).
    public static var saved: TrainingExperience? {
        get { UserDefaults.standard.string(forKey: key).flatMap(TrainingExperience.init(rawValue:)) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: key) }
    }

    public static var current: TrainingExperience { saved ?? .intermediate }

    public var title: String {
        switch self {
        case .beginner: "New to lifting"
        case .intermediate: "Some experience"
        case .experienced: "Experienced"
        }
    }

    public var detail: String {
        switch self {
        case .beginner: "Less than 6 months in the gym"
        case .intermediate: "6 months to 2 years"
        case .experienced: "More than 2 years, good technique"
        }
    }

    /// New lifters learn the base movement first: no explosive, one-leg or
    /// constraint versions, and nothing that needs a coach watching.
    public func allows(_ item: CatalogueItem) -> Bool {
        guard self == .beginner else { return true }
        if item.isCoached { return false }
        guard let variant = item.variant else { return true }
        switch variant.axis {
        case "unilateral", "constraint": return false
        case "tempo": return variant.tempo != "explosive"
        default: return true
        }
    }

    /// Sets and reps for this experience, applied after the youth clamp.
    public func adjusted(_ dose: Dose, isYouthEnvelope: Bool) -> Dose {
        var dose = dose
        switch self {
        case .beginner:
            dose.sets = min(dose.sets, 2)
            if dose.kind == "reps", let reps = dose.reps { dose.reps = min(max(reps, 8), 12) }
            if dose.kind == plyometricDoseKind, let contacts = dose.contacts { dose.contacts = max(1, contacts * 2 / 3) }
        case .intermediate:
            break
        case .experienced:
            if dose.kind == "reps" { dose.sets = min(dose.sets + 1, isYouthEnvelope ? 3 : 4) }
        }
        return dose
    }

    /// The weekly jump-contact ceiling scales with training history (§10).
    public func contactCap(_ base: Int) -> Int {
        switch self {
        case .beginner: base * 3 / 4
        case .intermediate: base
        case .experienced: base * 6 / 5
        }
    }
}
