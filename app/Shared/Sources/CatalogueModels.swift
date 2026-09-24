import Foundation

/// §3/§14: the catalogue (sports, items, skills) is deliberately not a
/// SwiftData model (see AthleteModels.swift's own doc comment) — it is
/// read-only, pack-delivered JSON, decoded straight into these plain
/// Codable structs. Every field and shape here was checked directly against
/// a real `content && npm run build` output (`content/dist/*.json`), not
/// assumed from §7's prose description.
///
/// `kind`, `surface`, `supervisionLevel` and `prop` are decoded as plain
/// strings rather than closed Swift enums on purpose: the catalogue is
/// currently far short of §7's ~1,500-item target and is due to grow
/// substantially later, and a closed enum would make the whole pack fail to
/// decode the day a new surface or prop value is authored.

public struct EquipmentChainTier: Codable, Sendable, Hashable {
    public let tier: String
    public let label: String
    public let equipment: [String]
}

/// How an expanded item was derived from its base (§7's expansion axes).
/// Pack JSON carries this as an object — e.g. `{"axis":"tempo","tempo":
/// "eccentric"}` — so it must decode as one; a plain String here made every
/// pack containing an expanded item fail to decode on device.
public struct ItemVariant: Codable, Sendable, Hashable {
    public let axis: String
    public let tier: String?
    public let tempo: String?
    public let values: [String: String]?
}

/// One exercise or drill.
public struct CatalogueItem: Codable, Sendable, Hashable {
    public let slug: String
    public let name: String
    public let kind: String
    public let qualities: [String: Double]
    public let muscles: [String: Double]
    public let equipment: [String]
    public let surface: String
    public let minAge: Int
    public let supervisionLevel: String
    public let setup: [String]
    public let execution: [String]
    public let cues: [String]
    public let mistakes: [String]
    public let progressions: [String]
    public let regressions: [String]
    public let substitutes: [String]
    public let defaultDose: Dose
    public let restSeconds: Int
    public let startPose: String
    public let endPose: String
    public let unilateralEligible: Bool?
    public let tempoEligible: Bool?
    public let prop: String?
    public let variant: ItemVariant?
    public let baseSlug: String?
    public let constraintAxes: [String]?
    public let equipmentChain: [EquipmentChainTier]?
    public let unilateralPosePattern: String?
    public let unilateralStabilityQuality: String?
    /// The item's OWN sport, present only on sport-specific drills — distinct
    /// from `CataloguePack.sport`, the whole pack's sport metadata object.
    /// Renamed at the Swift level to avoid confusing the two.
    public let itemSportSlug: String?
    /// §8: the named skills of the drill's own sport it directly builds —
    /// what "I want to get better at shooting" surfaces first.
    public var skills: [String]? = nil
    /// Positions of the drill's sport it is written for (a goalkeeper's
    /// saves); plans for other positions never pick it. Nil: everyone.
    public var positions: [String]? = nil

    private enum CodingKeys: String, CodingKey {
        case slug, name, kind, qualities, muscles, equipment, surface, minAge, supervisionLevel
        case setup, execution, cues, mistakes, progressions, regressions, substitutes
        case defaultDose, restSeconds, startPose, endPose
        case unilateralEligible, tempoEligible, prop, variant, baseSlug
        case constraintAxes, equipmentChain, unilateralPosePattern, unilateralStabilityQuality
        case itemSportSlug = "sport"
        case skills, positions
    }

    public var isUnilateralEligible: Bool { unilateralEligible ?? false }
    public var isTempoEligible: Bool { tempoEligible ?? false }
    public var isCoached: Bool { supervisionLevel == "COACHED" }
}

public struct SportSkill: Codable, Sendable, Hashable {
    public let slug: String
    public let name: String
    /// §8: "each named skill... carries a weighted list of the physical
    /// qualities that actually underpin it." Hand-authored for a growing
    /// subset of skills (soccer's full menu to start); every other skill
    /// falls back to its sport's own `qualityProfile` — see
    /// content/src/sports.js's `sport()` for why that fallback is real data,
    /// not a guess.
    public let qualityWeights: [String: Double]
}

public struct SportPosition: Codable, Sendable, Hashable {
    public let slug: String
    public let name: String
    public let qualityProfile: [String: Double]
}

public struct SportInfo: Codable, Sendable, Hashable {
    public let slug: String
    public let name: String
    public let governing: [String]
    public let season: String
    public let monthRange: [Int]
    public let qualityProfile: [String: Double]
    public let positions: [SportPosition]
    public let skills: [SportSkill]
    public let commonLoadAreas: [String]
    public let contactLevel: String
    public let typicalSessionLength: Int
    public let typicalWeeklyGames: Int
}

/// The whole decoded shape of one downloaded pack file — the core pack (no
/// `sport`) or one sport pack (`sport` present).
public struct CataloguePack: Codable, Sendable {
    public let slug: String
    public let version: Int
    public let generatedAt: String
    public let qualityModelVersion: Int
    public let muscleModelVersion: Int
    public let poseModelVersion: Int
    public let sport: SportInfo?
    public let items: [CatalogueItem]
}

extension CatalogueItem {
    /// Whether this can go into a plan for an athlete of `sport` playing
    /// `position`: general exercises fit everyone; a sport's drill fits only
    /// that sport's athletes — never anyone else's plan — and a drill written
    /// for positions (a goalkeeper's saves) only those positions.
    public func fits(sport: String?, position: String?) -> Bool {
        if let own = itemSportSlug, own != sport { return false }
        if let positions { return position.map(positions.contains) ?? false }
        return true
    }
}
