import Foundation

/// §10's plan generator, pure and deterministic: no SwiftData, no I/O, no
/// `Date.now` unless explicitly passed in — every input is a parameter, so
/// the same `PlanGeneratorInput` always produces byte-identical output
/// (§21's "seeded, so assert exact output"). `PlanMaterializer` is the
/// separate, thin layer that turns this into real `Plan`/`PlannedSession`/
/// `PlannedItem` SwiftData rows.
public struct PlanGeneratorInput: Sendable {
    public let sportProfile: [String: Double]
    public let positionProfile: [String: Double]?
    public let seasonStart: Date
    public let seasonEnd: Date
    public let weekStart: Date
    public let birthDate: Date
    public let trainsUnderCoach: Bool
    public let equipmentAvailable: Set<String>
    public let catalogue: Catalogue
    public let seed: String
    public let timeBudgetMinutesPerSession: Int
    public let now: Date

    public init(
        sportProfile: [String: Double], positionProfile: [String: Double]? = nil,
        seasonStart: Date, seasonEnd: Date, weekStart: Date, birthDate: Date,
        trainsUnderCoach: Bool = false, equipmentAvailable: Set<String> = [],
        catalogue: Catalogue, seed: String, timeBudgetMinutesPerSession: Int = 60,
        now: Date = .now
    ) {
        self.sportProfile = sportProfile
        self.positionProfile = positionProfile
        self.seasonStart = seasonStart
        self.seasonEnd = seasonEnd
        self.weekStart = weekStart
        self.birthDate = birthDate
        self.trainsUnderCoach = trainsUnderCoach
        self.equipmentAvailable = equipmentAvailable
        self.catalogue = catalogue
        self.seed = seed
        self.timeBudgetMinutesPerSession = timeBudgetMinutesPerSession
        self.now = now
    }
}

public struct GeneratedWeek: Sendable, Equatable {
    public let phase: SeasonPhase
    public let weekStart: Date
    public let sessions: [GeneratedSession]
}

public struct GeneratedSession: Sendable, Equatable {
    public let date: Date
    public let title: String
    public let focusQualities: [String]
    public let estimatedMinutes: Int
    public let items: [GeneratedPlannedItem]
}

public struct GeneratedPlannedItem: Sendable, Equatable {
    public let itemSlug: String
    public let order: Int
    public let dose: Dose
    public let restSec: Int
    public let rationale: String
    /// The quality slug this item was selected for — carried through so a
    /// later pass (§10's game-day taper, TaperApplier.swift) can filter by
    /// quality group (e.g. "drop Strength-group items two days out") without
    /// re-deriving which quality an already-picked item was chosen for.
    public let quality: String
}

public enum PlanGenerator {
    public static func generate(_ input: PlanGeneratorInput) -> GeneratedWeek {
        var rng = SeededGenerator(seed: input.seed)

        let phase = PhaseCalculator.phase(
            today: input.weekStart, seasonStart: input.seasonStart, seasonEnd: input.seasonEnd
        )
        let age = ageInYears(birthDate: input.birthDate, now: input.now)
        let isYouthEnvelope = age < 18

        let dates = trainingDates(count: sessionsPerWeek(for: phase), weekStart: input.weekStart)
        let qualityOrder = rankedQualities(sportProfile: input.sportProfile, positionProfile: input.positionProfile)

        var weeklyContacts = 0
        var sessions: [GeneratedSession] = []
        for (index, date) in dates.enumerated() {
            let targetQualities = roundRobinSlice(qualityOrder, offset: index, count: 3)
            sessions.append(buildSession(
                date: date, targetQualities: targetQualities, input: input,
                isYouthEnvelope: isYouthEnvelope, age: age,
                weeklyContacts: &weeklyContacts, rng: &rng
            ))
        }

        return GeneratedWeek(phase: phase, weekStart: input.weekStart, sessions: sessions)
    }

    // MARK: - Week shape

    /// §10: in-season is "two short quality sessions a week" (maintain, not
    /// build); post-season is a deliberate unload, so it gets the same low
    /// count. Off/pre-season use the top of §2's 2–3 nonconsecutive-day
    /// youth envelope, applied here to every athlete for simplicity — the
    /// envelope's REP/SET clamp (not day count) is what's actually
    /// age-gated below.
    private static func sessionsPerWeek(for phase: SeasonPhase) -> Int {
        switch phase {
        case .offSeason, .preSeason: return 3
        case .inSeason, .postSeason: return 2
        }
    }

    /// Fixed, nonconsecutive weekday patterns — Mon/Wed/Fri for three
    /// sessions, Mon/Thu for two — rather than a scheduling solver, since
    /// §10 doesn't ask for anything more elaborate than "nonconsecutive."
    private static func trainingDates(count: Int, weekStart: Date, calendar: Calendar = .current) -> [Date] {
        let offsets: [Int] = count >= 3 ? [0, 2, 4] : (count == 2 ? [0, 3] : [0])
        return offsets.prefix(max(count, 1)).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    // MARK: - Quality targeting

    private static func rankedQualities(sportProfile: [String: Double], positionProfile: [String: Double]?) -> [String] {
        var merged = sportProfile
        if let positionProfile {
            for (quality, weight) in positionProfile {
                merged[quality] = max(merged[quality] ?? 0, weight)
            }
        }
        return merged.sorted { lhs, rhs in
            lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key
        }.map(\.key)
    }

    /// Distributes the ranked qualities across the week's sessions — session
    /// `offset` starts its slice at a different rotation of the list, so a
    /// multi-session week doesn't train the exact same top qualities every
    /// day. Deliberately walks forward by a plain step of 1 (wrapping via
    /// modulo) rather than by `stride`: a previous version stepped by
    /// `stride` and relied on eventually revisiting every index to know when
    /// to stop, which is a REAL infinite loop whenever
    /// `gcd(stride, qualities.count) > 1` — confirmed the hard way, as a CI
    /// run stuck for 7+ minutes on `xcodebuild test` with zero output
    /// (traced by hand: 3 qualities, stride 3, `i` lands on the same index
    /// forever and the loop's exit condition never becomes true). Bounding
    /// this by a `for _ in 0..<qualities.count` loop makes it unconditionally
    /// terminate regardless of what `stride` and `qualities.count` are,
    /// which is the property that actually matters here — not the exact
    /// distribution pattern.
    private static func roundRobinSlice(_ qualities: [String], offset: Int, count: Int) -> [String] {
        guard !qualities.isEmpty, count > 0 else { return [] }
        let target = min(count, qualities.count)
        var result: [String] = []
        var i = offset % qualities.count
        for _ in 0..<qualities.count {
            if result.count == target { break }
            result.append(qualities[i])
            i = (i + 1) % qualities.count
        }
        return result
    }

    // MARK: - Session assembly

    /// §10: "Warm-up matched to the day's qualities → speed or power work
    /// while fresh → strength → conditioning → mobility and prehab...
    /// Ordering is not negotiable: plyometrics and sprint work before
    /// lifting, always." A separate warm-up-specific selection pass isn't
    /// built yet (there's no catalogue field marking an item "warm-up
    /// appropriate"); this enforces the one non-negotiable, testable part of
    /// that ordering — Speed/Power items always precede Strength, which
    /// always precedes Endurance, which always precedes Control.
    private static func buildSession(
        date: Date, targetQualities: [String], input: PlanGeneratorInput,
        isYouthEnvelope: Bool, age: Int, weeklyContacts: inout Int, rng: inout SeededGenerator
    ) -> GeneratedSession {
        var candidates: [(quality: String, item: CatalogueItem)] = []
        for quality in targetQualities {
            let eligible = input.catalogue.itemsBySlug.values
                .filter { item in
                    (item.qualities[quality] ?? 0) >= 0.7
                        && isEligibleForEquipment(item, available: input.equipmentAvailable)
                        && (input.trainsUnderCoach || !item.isCoached)
                        && item.minAge <= age
                }
                .sorted { $0.slug < $1.slug }

            guard !eligible.isEmpty else { continue }
            let picked = eligible[Int(rng.next() % UInt64(eligible.count))]
            candidates.append((quality, picked))
        }

        let blockRank: [QualityGroup: Int] = [.speed: 0, .power: 0, .strength: 1, .endurance: 2, .control: 3]
        let ordered = candidates.sorted { lhs, rhs in
            let lhsRank = qualitiesBySlug[lhs.quality].flatMap { blockRank[$0.group] } ?? 4
            let rhsRank = qualitiesBySlug[rhs.quality].flatMap { blockRank[$0.group] } ?? 4
            return lhsRank != rhsRank ? lhsRank < rhsRank : lhs.item.slug < rhs.item.slug
        }

        var items: [GeneratedPlannedItem] = []
        var totalMinutes = 0
        var order = 0
        for (quality, item) in ordered {
            let dose = clampedDose(item.defaultDose, isYouthEnvelope: isYouthEnvelope)

            if dose.kind == plyometricDoseKind {
                let contactsThisItem = dose.sets * (dose.contacts ?? 0)
                if weeklyContacts + contactsThisItem > weeklyContactCap(age: age) {
                    continue // would exceed the weekly ground-contact cap (§10)
                }
            }

            let minutes = estimatedMinutes(dose: dose, restSec: item.restSeconds)
            if totalMinutes + minutes > input.timeBudgetMinutesPerSession {
                continue // would exceed the session's time budget (§21)
            }

            if dose.kind == plyometricDoseKind {
                weeklyContacts += dose.sets * (dose.contacts ?? 0)
            }
            totalMinutes += minutes
            items.append(GeneratedPlannedItem(
                itemSlug: item.slug, order: order, dose: dose, restSec: item.restSeconds,
                rationale: rationale(for: item, quality: quality), quality: quality
            ))
            order += 1
        }

        return GeneratedSession(
            date: date, title: sessionTitle(for: targetQualities),
            focusQualities: targetQualities, estimatedMinutes: totalMinutes, items: items
        )
    }

    /// `equipmentLevelByTag[tag]` is `EquipmentLevel?` — comparing that
    /// directly against `.none` resolves to `Optional<EquipmentLevel>.none`
    /// (nil, "tag not in the table"), NOT `EquipmentLevel.none` (the enum
    /// case meaning "needs nothing"), because `Optional` has its own `case
    /// none` that shadows the intended one. Every real tag IS in the table,
    /// so that comparison was always false — confirmed by a real CI test
    /// failure (`testAnItemWithOnlyAlwaysFreeEquipmentIsSelectedEvenWithNothingOwned`),
    /// not caught by review. The `[tag, default: .full]` subscript form
    /// returns a non-optional `EquipmentLevel`, which resolves `.none`
    /// unambiguously to the enum case — and defaults an unrecognised tag to
    /// `.full` (never silently free) rather than `.none` (never silently
    /// required), the conservative direction to fail in.
    private static func isEligibleForEquipment(_ item: CatalogueItem, available: Set<String>) -> Bool {
        item.equipment.allSatisfy { tag in
            equipmentLevelByTag[tag, default: .full] == .none || available.contains(tag)
        }
    }

    /// §2: "1–3 sets of 6–15 repetitions... no percentage-of-1RM
    /// prescriptions, no max testing" for under-18s. The latter two are
    /// already structurally impossible — `Dose` has no %1RM concept and
    /// nothing in the catalogue represents a max-testing protocol — so only
    /// the set/rep range needs an active clamp here, and only for
    /// `reps`-kind doses (time/distance/contacts aren't "sets x reps" at
    /// all, so the envelope's wording doesn't apply to them).
    private static func clampedDose(_ dose: Dose, isYouthEnvelope: Bool) -> Dose {
        guard isYouthEnvelope, dose.kind == "reps" else { return dose }
        var clamped = dose
        clamped.sets = min(max(dose.sets, 1), 3)
        if let reps = dose.reps {
            clamped.reps = min(max(reps, 6), 15)
        }
        return clamped
    }

    /// §10: the weekly ceiling "scales with age and training history."
    /// Training history isn't a modeled field yet, so this scales by age
    /// only — conservative, named constants, the one place to change per
    /// §23's "each is changeable later by editing the noted constant."
    private static func weeklyContactCap(age: Int) -> Int {
        switch age {
        case ..<14: return 80
        case 14...15: return 100
        case 16...17: return 120
        default: return 140
        }
    }

    /// A flat, documented estimate — the catalogue doesn't carry per-item
    /// timing data, so this picks one conservative "time under tension per
    /// set" figure rather than guessing at per-exercise numbers. Not
    /// `private`: TaperApplier.swift reuses this exact formula when it
    /// recomputes a session's estimatedMinutes after trimming/reducing items,
    /// so the two never disagree about what a dose "costs."
    static func estimatedMinutes(dose: Dose, restSec: Int) -> Int {
        let secondsPerSet = 40 + restSec
        return Int((Double(dose.sets * secondsPerSet) / 60.0).rounded(.up))
    }

    private static func sessionTitle(for qualities: [String]) -> String {
        guard let first = qualities.first, let info = qualitiesBySlug[first] else { return "Training session" }
        return "\(info.shortName) session"
    }

    /// §10: "the generator surfaces a plain reason for each item... written
    /// by the engine from the profile weights."
    private static func rationale(for item: CatalogueItem, quality: String) -> String {
        let name = qualitiesBySlug[quality]?.name.lowercased() ?? quality
        return "This is here because your sport rewards \(name)."
    }

    private static func ageInYears(birthDate: Date, now: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.year], from: birthDate, to: now).year ?? 0
    }
}
