import Foundation

/// The original app idea: "pick which muscles you want to strengthen and get
/// a complete workout routine for that muscle group." Pure and seeded like
/// every other generator here, and it reuses PlanGenerator's own equipment,
/// supervision, age and youth-dose rules, so a muscle workout can never
/// prescribe something the weekly plan wouldn't.
public struct MuscleWorkoutInput: Sendable {
    public let regions: Set<MuscleRegion>
    public let minutes: Int
    public let birthDate: Date
    public let trainsUnderCoach: Bool
    public let equipmentAvailable: Set<String>
    public let catalogue: Catalogue
    public let seed: String
    public let now: Date
    /// Only general exercises and this sport's (and position's) drills.
    public let sportSlug: String?
    public let positionSlug: String?
    public let formatSlug: String?

    public init(
        regions: Set<MuscleRegion>, minutes: Int, birthDate: Date, trainsUnderCoach: Bool = false,
        equipmentAvailable: Set<String> = [], catalogue: Catalogue, seed: String, now: Date = .now,
        sportSlug: String? = nil, positionSlug: String? = nil, formatSlug: String? = nil
    ) {
        self.sportSlug = sportSlug
        self.positionSlug = positionSlug
        self.formatSlug = formatSlug
        self.regions = regions
        self.minutes = minutes
        self.birthDate = birthDate
        self.trainsUnderCoach = trainsUnderCoach
        self.equipmentAvailable = equipmentAvailable
        self.catalogue = catalogue
        self.seed = seed
        self.now = now
    }
}

public enum MuscleWorkoutGenerator {
    /// A whole-body warm-up quality always opens the session when the
    /// library has one, so a "legs" workout doesn't start cold.
    static let warmUpQualities: Set<String> = ["hip-mobility", "ankle-stiffness", "landing-mechanics"]

    public static func generate(_ input: MuscleWorkoutInput) -> GeneratedSession {
        var rng = SeededGenerator(seed: input.seed)
        let age = PlanGenerator.ageInYears(birthDate: input.birthDate, now: input.now)
        let isYouth = age < 18
        let regions = input.regions.sorted { $0.rawValue < $1.rawValue }

        let eligible = input.catalogue.itemsBySlug.values
            .filter { item in
                item.fits(sport: input.sportSlug, position: input.positionSlug, format: input.formatSlug)
                    && PlanGenerator.isEligibleForEquipment(item, available: input.equipmentAvailable)
                    && (input.trainsUnderCoach || !item.isCoached)
                    && item.minAge <= age
            }
            .sorted { $0.slug < $1.slug }

        func weight(_ item: CatalogueItem, for region: MuscleRegion) -> Double {
            item.muscles.filter { musclesBySlug[$0.key]?.region == region }.values.reduce(0, +)
        }

        // Each region's candidates, strongest match first, with a seeded
        // shuffle among equals so "regenerate" gives a genuinely new session.
        var pools: [MuscleRegion: [CatalogueItem]] = [:]
        for region in regions {
            let matches = eligible.filter { weight($0, for: region) >= 0.5 }
            let shuffled = matches.map { ($0, rng.next()) }
                .sorted { lhs, rhs in
                    let a = weight(lhs.0, for: region), b = weight(rhs.0, for: region)
                    return a != b ? a > b : lhs.1 < rhs.1
                }
                .map(\.0)
            pools[region] = shuffled
        }

        var picked: [(item: CatalogueItem, region: MuscleRegion?)] = []
        var used = Set<String>()
        var minutesUsed = 0

        func cost(_ item: CatalogueItem) -> Int {
            PlanGenerator.estimatedMinutes(dose: PlanGenerator.clampedDose(item.defaultDose, isYouthEnvelope: isYouth), restSec: item.restSeconds)
        }

        // Warm-up first.
        if let warmUp = eligible.first(where: { item in item.qualities.contains { warmUpQualities.contains($0.key) && $0.value >= 0.7 } && item.defaultDose.kind != plyometricDoseKind }),
           cost(warmUp) <= input.minutes / 4 {
            picked.append((warmUp, nil))
            used.insert(warmUp.slug)
            minutesUsed += cost(warmUp)
        }

        // Round-robin across the chosen regions so every one gets work,
        // until the time budget is spent or the pools run dry.
        var progressed = true
        while progressed {
            progressed = false
            for region in regions {
                guard var pool = pools[region] else { continue }
                while let next = pool.first, used.contains(next.slug) { pool.removeFirst() }
                pools[region] = pool
                guard let next = pool.first else { continue }
                let minutes = cost(next)
                if minutesUsed + minutes > input.minutes { continue }
                picked.append((next, region))
                used.insert(next.slug)
                minutesUsed += minutes
                pools[region] = Array(pool.dropFirst())
                progressed = true
            }
        }

        // §10's ordering rule holds here too: explosive work before lifting,
        // lifting before conditioning, mobility last (warm-up stays first).
        let rank: [QualityGroup: Int] = [.speed: 0, .power: 0, .strength: 1, .endurance: 2, .control: 3]
        func groupRank(_ item: CatalogueItem) -> Int {
            item.primaryQuality.flatMap { rank[$0.group] } ?? 4
        }
        let warmUps = picked.filter { $0.region == nil }
        let main = picked.filter { $0.region != nil }.sorted { lhs, rhs in
            let a = groupRank(lhs.item), b = groupRank(rhs.item)
            return a != b ? a < b : lhs.item.slug < rhs.item.slug
        }

        let items = (warmUps + main).enumerated().map { index, entry -> GeneratedPlannedItem in
            let dose = PlanGenerator.clampedDose(entry.item.defaultDose, isYouthEnvelope: isYouth)
            let reason: String
            if let region = entry.region {
                reason = "Targets your \(region.coachName) — one of the areas you picked."
            } else {
                reason = "Warm-up: gets your joints ready before the main work."
            }
            return GeneratedPlannedItem(
                itemSlug: entry.item.slug, order: index, dose: dose, restSec: entry.item.restSeconds,
                rationale: reason, quality: entry.item.primaryQuality?.id ?? ""
            )
        }

        return GeneratedSession(
            date: input.now, title: title(for: regions), focusQualities: Array(Set(items.map(\.quality))).sorted(),
            estimatedMinutes: minutesUsed, items: items
        )
    }

    static func title(for regions: [MuscleRegion]) -> String {
        let names = regions.map { $0.coachName.capitalized }
        switch names.count {
        case 0: return "Full-body workout"
        case 1: return "\(names[0]) workout"
        case 2: return "\(names[0]) + \(names[1]) workout"
        default: return "\(names[0]), \(names[1]) + \(names.count - 2) more"
        }
    }
}
