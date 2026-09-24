import Foundation

/// §8's skill menu — the third link in the chain (skill → qualities →
/// items → a dated block). Pure and deterministic like `PlanGenerator`, and
/// deliberately reuses its equipment/age/dose rules rather than
/// re-deriving them, so a skill block can never mean something different
/// from what the weekly plan already means by "eligible" or "youth dose."
///
/// Day structure near the game reuses `TaperCalculator` directly — its
/// `.lastHeavySession`/`.qualityOverQuantity`/`.primer`/`.gameDay` stages
/// already say almost exactly what §8's worked example describes for
/// those same days out ("short, sharp, technical, no lifting to failure,"
/// "a primer... explicitly not a hard session," "the warm-up sequence,
/// nothing else"). The days further out than that rotate through a fixed
/// build-day pattern (strength → sport drill → plyometric → light
/// technical) — a rule applied uniformly, never hand-written per sport, per
/// §8's own "nothing above is hand-written for soccer beyond the
/// skill→quality weights and the drill entries themselves."
public struct SkillMenuInput: Sendable {
    public let sportSlug: String
    public let skillSlug: String
    public let skillName: String
    public let qualityWeights: [String: Double]
    public let today: Date
    public let gameDate: Date
    public let birthDate: Date
    public let trainsUnderCoach: Bool
    public let equipmentAvailable: Set<String>
    public let catalogue: Catalogue
    public let seed: String
    public let now: Date
    /// Drills written for other positions are never picked.
    public let positionSlug: String?

    public init(
        sportSlug: String, skillSlug: String, skillName: String, qualityWeights: [String: Double],
        today: Date, gameDate: Date, birthDate: Date, trainsUnderCoach: Bool = false,
        equipmentAvailable: Set<String> = [], catalogue: Catalogue, seed: String, now: Date = .now,
        positionSlug: String? = nil
    ) {
        self.positionSlug = positionSlug
        self.sportSlug = sportSlug
        self.skillSlug = skillSlug
        self.skillName = skillName
        self.qualityWeights = qualityWeights
        self.today = today
        self.gameDate = gameDate
        self.birthDate = birthDate
        self.trainsUnderCoach = trainsUnderCoach
        self.equipmentAvailable = equipmentAvailable
        self.catalogue = catalogue
        self.seed = seed
        self.now = now
    }
}

public struct GeneratedSkillBlock: Sendable, Equatable {
    public let skillName: String
    /// One session per day, `today...gameDate` inclusive, capped to the
    /// trailing `SkillMenuEngine.maxWindowDays` days when the game is
    /// further out than that — a focused run-in, not a claim that this
    /// replaces the athlete's regular week the whole way out.
    public let days: [GeneratedSession]
    /// §8: "the plan screen says what is actually achievable in the
    /// window" — never oversells a short block to a teenager.
    public let realisticExpectation: String
}

public enum SkillMenuEngine {
    /// §23-style named, changeable constant: the longest run-in this engine
    /// will plan day-by-day. §8 also describes an "8-week version... for the
    /// off-season," which is a separate, not-yet-built feature — this caps
    /// the window rather than silently pretending to cover it.
    public static let maxWindowDays = 13

    private enum BuildDayRole: CaseIterable {
        case strength, sportDrill, plyometric, lightTechnical
    }

    public static func generate(_ input: SkillMenuInput) -> GeneratedSkillBlock {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: input.today)
        let gameDay = calendar.startOfDay(for: input.gameDate)
        let totalDaysOut = max(0, calendar.dateComponents([.day], from: today, to: gameDay).day ?? 0)
        let windowDays = min(totalDaysOut, maxWindowDays)

        var rng = SeededGenerator(seed: input.seed)
        let age = PlanGenerator.ageInYears(birthDate: input.birthDate, now: input.now)
        let isYouthEnvelope = age < 18
        let rankedQualities = input.qualityWeights
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map(\.key)

        var days: [GeneratedSession] = []
        var buildDayIndex = 0
        for offset in stride(from: -windowDays, through: 0, by: 1) {
            let date = calendar.date(byAdding: .day, value: offset, to: gameDay) ?? gameDay
            let stage = TaperCalculator.stage(for: date, competitions: [gameDay], calendar: calendar)
            let day: GeneratedSession
            if stage == .normal {
                let role = BuildDayRole.allCases[buildDayIndex % BuildDayRole.allCases.count]
                buildDayIndex += 1
                day = buildDay(role: role, date: date, input: input, rankedQualities: rankedQualities,
                                isYouthEnvelope: isYouthEnvelope, age: age, rng: &rng)
            } else {
                day = taperedDay(stage: stage, date: date, input: input, rankedQualities: rankedQualities,
                                  isYouthEnvelope: isYouthEnvelope, age: age, rng: &rng)
            }
            days.append(day)
        }

        return GeneratedSkillBlock(
            skillName: input.skillName, days: days,
            realisticExpectation: expectation(windowDays: windowDays, totalDaysOut: totalDaysOut, skillName: input.skillName)
        )
    }

    // MARK: - Build-phase days (4+ days out, further than the taper reaches)

    private static func buildDay(
        role: BuildDayRole, date: Date, input: SkillMenuInput, rankedQualities: [String],
        isYouthEnvelope: Bool, age: Int, rng: inout SeededGenerator
    ) -> GeneratedSession {
        switch role {
        case .strength:
            let items = pickItems(
                count: 2, from: rankedQualities, groups: [.strength, .power], sportOnly: false,
                input: input, isYouthEnvelope: isYouthEnvelope, age: age, rng: &rng
            )
            return session(date: date, title: "Strength emphasis", items: items)

        case .sportDrill:
            let items = pickItems(
                count: 2, from: rankedQualities, groups: nil, sportOnly: true,
                input: input, isYouthEnvelope: isYouthEnvelope, age: age, rng: &rng
            )
            return session(date: date, title: "Drill day", items: items)

        case .plyometric:
            var items = pickItems(
                count: 1, from: rankedQualities, groups: [.power], plyometricOnly: true,
                input: input, isYouthEnvelope: isYouthEnvelope, age: age, rng: &rng
            )
            // §10: "plus mobility for hips and ankles" — the worked
            // example pairs every plyometric day with control-group work.
            items += pickItems(
                count: 1, from: rankedQualities, groups: [.control], sportOnly: false,
                input: input, isYouthEnvelope: isYouthEnvelope, age: age, rng: &rng
            )
            return session(date: date, title: "Plyometrics and mobility", items: reindexed(items))

        case .lightTechnical:
            let items = pickItems(
                count: 1, from: rankedQualities, groups: nil, sportOnly: false,
                input: input, isYouthEnvelope: isYouthEnvelope, age: age, rng: &rng, halveSets: true
            )
            return session(date: date, title: "Light technical — full recovery emphasis", items: items)
        }
    }

    // MARK: - Taper-phase days (reuses TaperCalculator's stages exactly)

    private static func taperedDay(
        stage: TaperStage, date: Date, input: SkillMenuInput, rankedQualities: [String],
        isYouthEnvelope: Bool, age: Int, rng: inout SeededGenerator
    ) -> GeneratedSession {
        switch stage {
        case .lastHeavySession:
            // §8: "complex pairing: a heavy set followed by an explosive
            // one, then strike volume while fresh."
            var items = pickItems(count: 1, from: rankedQualities, groups: [.strength], sportOnly: false,
                                   input: input, isYouthEnvelope: isYouthEnvelope, age: age, rng: &rng)
            items += pickItems(count: 1, from: rankedQualities, groups: [.power], sportOnly: false,
                                input: input, isYouthEnvelope: isYouthEnvelope, age: age, rng: &rng)
            items += pickItems(count: 1, from: rankedQualities, groups: nil, sportOnly: true,
                                input: input, isYouthEnvelope: isYouthEnvelope, age: age, rng: &rng)
            return session(date: date, title: "Complex pairing — building into game day", items: reindexed(items))

        case .qualityOverQuantity:
            // §10: "short, sharp, technical. No lifting to failure."
            let items = pickItems(count: 1, from: rankedQualities, groups: nil, excludingGroups: [.strength],
                                   sportOnly: true, input: input, isYouthEnvelope: isYouthEnvelope, age: age, rng: &rng)
            return session(date: date, title: "Sharpening only — low volume, full intent", items: items)

        case .primer:
            let items = pickItems(count: 1, from: rankedQualities, groups: [.speed, .power], sportOnly: false,
                                   input: input, isYouthEnvelope: isYouthEnvelope, age: age, rng: &rng, halveSets: true)
            return session(date: date, title: "Primer — short activation, not a hard session", items: items)

        case .gameDay:
            return session(date: date, title: "Warm-up sequence only — game day", items: [])

        case .normal, .postGameRecovery, .betweenGames:
            // The block only ever runs today...gameDate, so a stage that
            // only makes sense relative to a PAST competition never occurs
            // here — TaperCalculator is given exactly one competition date
            // (the target game), and `.normal` is handled by the caller
            // before this function is reached.
            return session(date: date, title: "Training", items: [])
        }
    }

    // MARK: - Item selection

    private static func pickItems(
        count: Int, from rankedQualities: [String], groups: Set<QualityGroup>?,
        excludingGroups: Set<QualityGroup> = [], sportOnly: Bool = false, plyometricOnly: Bool = false,
        input: SkillMenuInput, isYouthEnvelope: Bool, age: Int, rng: inout SeededGenerator, halveSets: Bool = false
    ) -> [GeneratedPlannedItem] {
        var items: [GeneratedPlannedItem] = []

        // Drills written for exactly this skill come first on sport-drill
        // slots — "the best exercises for shooting" — then quality matching
        // fills whatever is left.
        if sportOnly {
            let tagged = input.catalogue.itemsBySlug.values
                .filter { item in
                    item.itemSportSlug == input.sportSlug
                        && item.fits(sport: input.sportSlug, position: input.positionSlug)
                        && (item.skills ?? []).contains(input.skillSlug)
                        && PlanGenerator.isEligibleForEquipment(item, available: input.equipmentAvailable)
                        && (input.trainsUnderCoach || !item.isCoached)
                        && item.minAge <= age
                        && (!plyometricOnly || item.defaultDose.kind == plyometricDoseKind)
                        && !(item.primaryQuality.map { excludingGroups.contains($0.group) } ?? false)
                }
                .sorted { $0.slug < $1.slug }
            if !tagged.isEmpty {
                let picked = tagged[Int(rng.next() % UInt64(tagged.count))]
                var dose = PlanGenerator.clampedDose(picked.defaultDose, isYouthEnvelope: isYouthEnvelope)
                if halveSets { dose.sets = max(1, dose.sets / 2) }
                items.append(GeneratedPlannedItem(
                    itemSlug: picked.slug, order: 0, dose: dose, restSec: picked.restSeconds,
                    rationale: "A \(input.skillName.lowercased()) drill — it trains the skill itself, not just the qualities behind it.",
                    quality: picked.primaryQuality?.id ?? ""
                ))
            }
        }

        for quality in rankedQualities {
            if items.count >= count { break }
            if let groups, let group = qualitiesBySlug[quality]?.group, !groups.contains(group) { continue }
            if let group = qualitiesBySlug[quality]?.group, excludingGroups.contains(group) { continue }

            func eligibleItems(restrictToSport: Bool) -> [CatalogueItem] {
                input.catalogue.itemsBySlug.values
                    .filter { item in
                        (item.qualities[quality] ?? 0) >= 0.7
                            && item.fits(sport: input.sportSlug, position: input.positionSlug)
                            && PlanGenerator.isEligibleForEquipment(item, available: input.equipmentAvailable)
                            && (input.trainsUnderCoach || !item.isCoached)
                            && item.minAge <= age
                            && (!restrictToSport || item.itemSportSlug == input.sportSlug)
                            && (!plyometricOnly || item.defaultDose.kind == plyometricDoseKind)
                    }
                    .sorted { $0.slug < $1.slug }
            }
            // "Drill day" prefers this sport's own tagged drills, but §3's
            // "never an empty session" philosophy still applies while the
            // catalogue's drill coverage is still growing (the §7 volume
            // gap, tracked separately) — a quality with no sport-tagged
            // drill yet still trains something rather than nothing.
            var eligible = sportOnly ? eligibleItems(restrictToSport: true) : []
            if eligible.isEmpty { eligible = eligibleItems(restrictToSport: false) }
            eligible.removeAll { candidate in items.contains { $0.itemSlug == candidate.slug } }
            guard !eligible.isEmpty else { continue }

            let picked = eligible[Int(rng.next() % UInt64(eligible.count))]
            var dose = PlanGenerator.clampedDose(picked.defaultDose, isYouthEnvelope: isYouthEnvelope)
            if halveSets { dose.sets = max(1, dose.sets / 2) }
            if dose.kind == plyometricDoseKind {
                // A single day's plyometric volume never exceeds half the
                // athlete's weekly ground-contact ceiling (§10) — this is a
                // short focused block, not a full week, so the weekly cap
                // is halved rather than tracked cumulatively across days.
                let cap = PlanGenerator.weeklyContactCap(age: age) / 2
                if dose.sets * (dose.contacts ?? 0) > cap, let perSet = dose.contacts, perSet > 0 {
                    dose.sets = max(1, cap / perSet)
                }
            }

            items.append(GeneratedPlannedItem(
                itemSlug: picked.slug, order: items.count, dose: dose, restSec: picked.restSeconds,
                rationale: rationale(for: quality, skillName: input.skillName), quality: quality
            ))
        }
        return items
    }

    private static func reindexed(_ items: [GeneratedPlannedItem]) -> [GeneratedPlannedItem] {
        items.enumerated().map { index, item in
            GeneratedPlannedItem(
                itemSlug: item.itemSlug, order: index, dose: item.dose, restSec: item.restSec,
                rationale: item.rationale, quality: item.quality
            )
        }
    }

    private static func session(date: Date, title: String, items: [GeneratedPlannedItem]) -> GeneratedSession {
        GeneratedSession(
            date: date, title: title, focusQualities: items.map(\.quality),
            estimatedMinutes: items.reduce(0) { $0 + PlanGenerator.estimatedMinutes(dose: $1.dose, restSec: $1.restSec) },
            items: items
        )
    }

    /// §8: "the screen also explains itself... written by the engine from
    /// the skill→quality mapping, so the athlete learns the reasoning
    /// rather than following a black box."
    private static func rationale(for quality: String, skillName: String) -> String {
        let name = qualitiesBySlug[quality]?.name.lowercased() ?? quality
        return "Builds \(name), which \(skillName.lowercased()) depends on."
    }

    /// §8: "seven days of work will not transform a shot... for under two
    /// weeks, the honest answer is 'sharper and better coordinated, not
    /// fundamentally stronger.'"
    private static func expectation(windowDays: Int, totalDaysOut: Int, skillName: String) -> String {
        if totalDaysOut > maxWindowDays {
            return "Your game is \(totalDaysOut) days out — here's a focused \(maxWindowDays + 1)-day run-in. "
                + "In that window, expect \(skillName.lowercased()) to feel sharper and better coordinated, not fundamentally stronger. "
                + "Real physical change needs a longer block in the off-season."
        }
        return "In \(windowDays + 1) days, expect \(skillName.lowercased()) to feel sharper and better coordinated, not fundamentally stronger — real physical change takes a longer block in the off-season."
    }
}
