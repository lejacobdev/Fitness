import Foundation

// V6 workout engine, part 2: from a decision to a session
// (docs/VERSION-6.md §6–§8). Blocks in a fixed order, few exercises chosen
// for a purpose, doses by role, and a time model that matches real sessions.

/// The parts of a session, in the order they're done.
public enum SessionBlock: String, Codable, Sendable, CaseIterable {
    case prep, power, primaryStrength, secondaryStrength, accessory, conditioning, mobility, cooldown

    public var title: String {
        switch self {
        case .prep: "Movement prep"
        case .power: "Power & speed"
        case .primaryStrength: "Main strength"
        case .secondaryStrength: "Secondary strength"
        case .accessory: "Trunk & resilience"
        case .conditioning: "Conditioning"
        case .mobility: "Mobility"
        case .cooldown: "Cool-down"
        }
    }
}

/// Who the session is for: what they can do and what they own.
public struct AthleteKit: Sendable {
    public var catalogue: Catalogue
    public var sport: SportInfo?
    public var positionSlug: String?
    public var formatSlug: String?
    public var equipment: Set<String>
    public var trainsUnderCoach: Bool
    /// Exercises to leave out when there's another choice (yesterday's).
    public var avoidSlugs: Set<String>
    /// Jump contacts still allowed this week.
    public var contactsLeft: Int
    public var seed: String

    public init(catalogue: Catalogue, sport: SportInfo?, positionSlug: String? = nil, formatSlug: String? = nil,
                equipment: Set<String>, trainsUnderCoach: Bool = false, avoidSlugs: Set<String> = [], contactsLeft: Int = 100,
                seed: String = "") {
        self.catalogue = catalogue
        self.sport = sport
        self.positionSlug = positionSlug
        self.formatSlug = formatSlug
        self.equipment = equipment
        self.trainsUnderCoach = trainsUnderCoach
        self.avoidSlugs = avoidSlugs
        self.contactsLeft = contactsLeft
        self.seed = seed
    }
}

public enum SessionBuilder {
    /// Groups that protect the areas a sport loads most.
    static let resilienceGroups: [String: [String]] = [
        "hamstrings": ["hamstring-eccentric"], "groin": ["hip-adductor"], "hips": ["hip-adductor", "hip-activation"], "hip-flexors": ["hip-adductor"],
        "knees": ["knee-isometric", "knee-eccentric"], "knee": ["knee-isometric"], "front-knee": ["knee-isometric"],
        "ankles": ["calf-ankle"], "shins": ["calf-ankle"], "achilles": ["calf-ankle"],
        "shoulder": ["shoulder-health"], "shoulders": ["shoulder-health"], "elbow": ["shoulder-health"], "elbows": ["shoulder-health"],
        "upper-back": ["shoulder-health"], "lower-back": ["back-extension", "anti-extension"], "neck": ["neck"],
        "wrists": ["grip"], "wrist": ["grip"], "lead-wrist": ["grip"], "forearms": ["grip"], "fingers": ["grip"],
    ]
    static let trunkGroups = ["anti-rotation", "anti-extension", "anti-lateral", "rotation", "carry"]

    public static func build(_ decision: SessionDecision, day: TrainingDay, kit: AthleteKit) -> GeneratedSession {
        var state = BuildState(decision: decision, day: day, kit: kit)
        switch decision.sessionType {
        case .gymDevelopment: state.gymDay()
        case .afterPractice: state.afterPractice()
        case .primer: state.primer()
        case .conditioning: state.conditioningSession()
        case .recovery: state.recovery()
        case .mobility: state.mobility(decision.mobilityPurpose ?? .targeted)
        case .travel: state.travel()
        case .rest: break
        }
        state.fit()
        return state.session()
    }

    /// Seconds one planned item takes, sets, rest and setup included.
    public static func seconds(_ item: GeneratedPlannedItem) -> Int {
        let dose = item.dose
        let sides = dose.perSide == true ? 2 : 1
        let work: Int
        switch dose.kind {
        case "reps": work = (dose.reps ?? 8) * (item.block == .primaryStrength || item.block == .secondaryStrength ? 4 : 3) * sides
        case "time": work = (dose.seconds ?? 30) * sides
        case "distance": work = Int((dose.metres ?? 20) / 4) + 15
        case plyometricDoseKind: work = (dose.contacts ?? 5) * 2 * sides
        default: work = 30
        }
        let setup = item.block == .prep || item.block == .mobility || item.block == .cooldown ? 10
            : item.block == .primaryStrength || item.block == .secondaryStrength ? 75 : 45
        return dose.sets * work + max(0, dose.sets - 1) * item.restSec + setup
    }
}

private struct BuildState {
    let decision: SessionDecision
    let day: TrainingDay
    let kit: AthleteKit
    var rng: SeededGenerator
    var picks: [(item: CatalogueItem, block: SessionBlock, why: String, quality: String)] = []
    var conditioning: ConditioningPrescription?
    var contactsLeft: Int
    let qualityWeight: [String: Double]

    init(decision: SessionDecision, day: TrainingDay, kit: AthleteKit) {
        self.decision = decision
        self.day = day
        self.kit = kit
        rng = SeededGenerator(seed: "\(kit.seed)|\(decision.sessionType.rawValue)")
        contactsLeft = kit.contactsLeft
        var weights = kit.sport?.qualityProfile ?? [:]
        if let position = kit.positionSlug, let profile = kit.sport?.positions.first(where: { $0.slug == position })?.qualityProfile {
            for (q, w) in profile { weights[q] = (weights[q] ?? 0) + w }
        }
        for goal in day.goals {
            for (q, c) in Capacity.fromQuality where c == goal { weights[q] = (weights[q] ?? 0) + 0.6 }
        }
        qualityWeight = weights
    }

    var used: Set<String> { Set(picks.map(\.item.slug)) }

    // MARK: Eligibility

    func eligible(_ item: CatalogueItem) -> Bool {
        let p = item.planProfile
        guard item.fits(sport: kit.sport?.slug, position: kit.positionSlug, format: kit.formatSlug),
              PlanGenerator.isEligibleForEquipment(item, available: kit.equipment),
              kit.trainsUnderCoach || !item.isCoached,
              item.minAge <= day.age,
              day.experience.allows(item),
              !PainFilter.loads(item, areas: day.painAreas),
              !used.contains(item.slug) else { return false }
        let restful = ["prep", "mobility", "recovery"].contains(p.role)
        if !restful {
            let primerStart = decision.sessionType == .primer && p.group == "sprint-accel"
            if p.isLower, p.legLoad > decision.legBudget, p.role != "trunk", !primerStart { return false }
            if decision.avoids(.highImpact), p.impact >= 2, !primerStart { return false }
            if decision.avoids(.maxSprinting), p.group == "sprint-maxv" { return false }
            if decision.avoids(.heavyLowerBody), p.isLower, p.fatigue >= 4 { return false }
            if decision.avoids(.newHardExercises) || day.age < 15, p.technique >= 3 { return false }
        }
        if p.impact >= 3, day.age < 13 { return false }
        if item.defaultDose.kind == plyometricDoseKind, contactsLeft < 12 { return false }
        return true
    }

    func relevance(_ item: CatalogueItem) -> Double {
        var score = 0.0
        for (q, amount) in item.qualities { score += amount * (qualityWeight[q] ?? 0.1) }
        if item.itemSportSlug != nil, item.itemSportSlug == kit.sport?.slug { score += 0.2 }
        // Learn the base movement before its variants.
        if item.baseSlug != nil { score -= day.experience == .experienced ? 0.15 : 0.6 }
        if kit.avoidSlugs.contains(item.slug) { score -= 0.6 }
        return score
    }

    /// Picks one exercise matching `filter`, best for the athlete first, with
    /// a little variety among the top few. Returns whether it found one.
    @discardableResult
    mutating func pick(_ block: SessionBlock, why: String, pool: Int = 3, _ filter: (CatalogueItem, ExerciseProfile) -> Bool) -> Bool {
        // An "explosive" tempo variant is power work, never a strength or trunk exercise.
        let strengthBlock = [.primaryStrength, .secondaryStrength, .accessory].contains(block)
        let candidates = kit.catalogue.itemsBySlug.values
            .filter { !(strengthBlock && $0.variant?.tempo == "explosive") }
            .filter { eligible($0) && filter($0, $0.planProfile) }
            .map { ($0, relevance($0)) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.slug < $1.0.slug }
        guard !candidates.isEmpty else { return false }
        let top = Array(candidates.prefix(pool))
        let item = top[Int(rng.next() % UInt64(top.count))].0
        let quality = item.qualities.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key ?? ""
        picks.append((item, block, why, quality))
        if item.defaultDose.kind == plyometricDoseKind {
            contactsLeft -= (item.defaultDose.contacts ?? 5) * 3
        }
        return true
    }

    @discardableResult
    mutating func pickGroup(_ block: SessionBlock, _ groups: [String], role: String? = nil, why: String, pool: Int = 3) -> Bool {
        for group in groups {
            if pick(block, why: why, pool: pool, { _, p in p.group == group && (role == nil || p.role == role) }) { return true }
        }
        return false
    }

    var loadAreas: [String] { kit.sport?.commonLoadAreas ?? [] }

    // MARK: Session types

    mutating func prep(count: Int, upperFocus: Bool, fast: Bool) {
        pickGroup(.prep, ["mobility-flow"], why: "Opens hips, hamstrings and upper back in one movement.")
        pickGroup(.prep, ["mobility-hip", "mobility-ankle"], role: "prep", why: "Range at the hips and ankles before you load them.")
        if upperFocus {
            pickGroup(.prep, ["shoulder-health", "mobility-shoulder"], role: "prep", why: "Wakes up the shoulder blade before pressing and pulling.")
        } else {
            pickGroup(.prep, ["hip-activation"], why: "Switches on the glutes that keep the knees in line.")
        }
        if count >= 4 {
            if fast, !decision.avoids(.highImpact) {
                pickGroup(.prep, ["sprint-mechanics", "sprint-accel-drill"], why: "Rhythm and posture: the bridge from warm-up to fast work.")
            } else {
                pickGroup(.prep, ["crawl", "hip-activation", "shoulder-health"], why: "Gets the whole body working together.")
            }
        }
    }

    mutating func powerBlock(count: Int) {
        let targets = decision.primaryTargets
        var placed = 0
        if targets.contains(.acceleration), placed < count,
           pickGroup(.power, ["sprint-accel", "sprint-accel-resisted"], why: "Short sprints while you're fresh: acceleration is trained at full speed or not at all.") { placed += 1 }
        if targets.contains(.speed), placed < count,
           pickGroup(.power, ["sprint-maxv"], why: "A few fast runs to build top speed — full rest between.") { placed += 1 }
        if (targets.contains(.power) || placed < count), placed < count {
            let lateral = (day.demands.weights[.coordination] ?? 0) >= 0.7
            let groups = decision.avoids(.highImpact)
                ? ["throw-rotational", "throw-overhead", "throw-chest", "hinge-ballistic"]
                : (lateral ? ["jump-lateral", "jump-vertical", "jump-horizontal"] : ["jump-vertical", "jump-horizontal", "jump-lateral"]) + ["throw-rotational", "throw-overhead"]
            if pickGroup(.power, groups, why: "Explosive work goes first, before fatigue blunts it.") { placed += 1 }
        }
        if placed < count, (day.demands.weights[.power] ?? 0) >= 0.5 || (qualityWeight["rotational-power"] ?? 0) > 0.5 {
            pickGroup(.power, ["throw-rotational", "throw-overhead", "throw-chest"], why: "Throws train power with almost no impact on the legs.")
        }
    }

    func lowerGroups(_ pattern: String?) -> [String] {
        pattern == "hinge" ? ["hinge-bilateral", "hinge-hip-extension", "single-leg-hip", "hinge-ballistic"]
            : ["squat-bilateral", "single-leg-knee", "single-leg-lateral"]
    }

    func upperGroups(_ pattern: String?) -> [String] {
        pattern == "pull" ? ["pull-vertical", "pull-horizontal"] : ["push-horizontal", "push-vertical", "push-incline"]
    }

    mutating func gymDay() {
        let upperOnly = decision.legBudget < 2
        prep(count: 4, upperFocus: upperOnly, fast: !decision.primaryTargets.filter { [.power, .acceleration, .speed].contains($0) }.isEmpty)
        if !decision.primaryTargets.filter({ [.power, .acceleration, .speed].contains($0) }).isEmpty {
            powerBlock(count: decision.durationTarget >= 55 ? 2 : 1)
        }
        // Main strength: one lower pattern and one upper, alternating through the week.
        if !upperOnly {
            if !pickGroup(.primaryStrength, lowerGroups(decision.lowerPattern), role: "primary",
                          why: decision.lowerPattern == "hinge" ? "Hip-hinge strength: the engine for sprinting and jumping." : "Squat strength: the base for acceleration, jumping and landing.") {
                pickGroup(.primaryStrength, lowerGroups(decision.lowerPattern), why: "Lower-body strength for your sport.")
            }
        }
        pickGroup(.primaryStrength, upperGroups(decision.upperPattern), role: "primary",
                  why: decision.upperPattern == "pull" ? "Pulling strength balances all the pushing and throwing in sport." : "Upper-body pressing strength.")
        // Secondary: the other patterns.
        if upperOnly {
            pickGroup(.primaryStrength, upperGroups(decision.upperPattern == "pull" ? "push" : "pull"), role: "primary", why: "The opposite upper-body pattern, so both sides stay balanced.")
        } else if !decision.avoids(.highVolumeLowerBody) {
            let secondaryLower = decision.lowerPattern == "hinge" ? ["single-leg-knee", "single-leg-lateral"] : ["single-leg-hip", "hinge-hip-extension", "hamstring-eccentric"]
            pickGroup(.secondaryStrength, secondaryLower, why: "One leg at a time — how you actually run, cut and land.")
        }
        pickGroup(.secondaryStrength, upperGroups(decision.upperPattern == "pull" ? "push" : "pull"),
                  why: "The opposite upper-body pattern, so both sides stay balanced.")
        trunkAndResilience(count: 2)
        if decision.primaryTargets.contains(.balance) || day.goals.first == .balance {
            pickGroup(.accessory, ["balance"], why: "For your balance goal: control on one leg.")
        }
        conditioningBlock()
    }

    mutating func trunkAndResilience(count: Int) {
        let offset = Int((Calendar.current.ordinality(of: .day, in: .era, for: day.date) ?? 0) % SessionBuilder.trunkGroups.count)
        let rotated = Array(SessionBuilder.trunkGroups[offset...] + SessionBuilder.trunkGroups[..<offset])
        pickGroup(.accessory, rotated, role: "trunk", why: "A trunk that resists movement passes force from legs to arms.")
        guard count > 1 else { return }
        var groups: [String] = []
        for area in loadAreas { for g in SessionBuilder.resilienceGroups[area] ?? [] where !groups.contains(g) { groups.append(g) } }
        if groups.isEmpty { groups = ["hamstring-eccentric", "shoulder-health", "calf-ankle"] }
        let area = loadAreas.first.map { $0.replacingOccurrences(of: "-", with: " ") }
        pickGroup(.accessory, groups, why: area.map { "Protects your \($0), which your sport loads a lot." } ?? "Small strength that prevents common injuries.")
    }

    mutating func conditioningBlock() {
        guard let type = decision.conditioning, decision.conditioningMinutes > 0 else { return }
        let lowImpact = decision.avoids(.highImpact) || decision.legBudget < 2
        let catalogue = kit.catalogue, equipment = kit.equipment, pain = day.painAreas
        let usable: (String) -> Bool = { slug in catalogue.item(slug).map { item in
            PlanGenerator.isEligibleForEquipment(item, available: equipment) && !PainFilter.loads(item, areas: pain)
        } ?? false }
        guard let rx = ConditioningEngine.prescribe(type, minutes: decision.conditioningMinutes, lowImpact: lowImpact, age: day.age,
                                                    experience: day.experience, usable: usable),
              let item = kit.catalogue.item(rx.itemSlug) else { return }
        conditioning = rx
        picks.append((item, .conditioning, "\(type.title): \(rx.summary).", item.qualities.max { $0.value < $1.value }?.key ?? ""))
    }

    mutating func afterPractice() {
        if decision.primaryTargets.contains(.strength), decision.legBudget >= 2 {
            pickGroup(.secondaryStrength, ["single-leg-knee", "single-leg-hip", "hinge-hip-extension"],
                      why: "A little single-leg strength — low volume, because practice already used your legs.")
        }
        if !pickGroup(.primaryStrength, upperGroups(decision.upperPattern), role: "primary", why: "Practice rarely trains the upper body: this is where it gets strong.") {
            pickGroup(.primaryStrength, upperGroups(decision.upperPattern), why: "Upper-body strength practice doesn't give you.")
        }
        pickGroup(.secondaryStrength, upperGroups(decision.upperPattern == "pull" ? "push" : "pull"), why: "The opposite pattern keeps the shoulders balanced.")
        trunkAndResilience(count: 2)
        if decision.legBudget == 1, !loadAreas.contains("hamstrings") {
            pickGroup(.accessory, ["knee-isometric", "calf-ankle"], why: "Gentle strength for knees and ankles that adds little fatigue.")
        }
    }

    mutating func primer() {
        prep(count: 4, upperFocus: false, fast: true)
        pickGroup(.power, ["sprint-accel"], why: "Two or three short, fast starts to feel quick for tomorrow — not to get tired.")
        pickGroup(.power, ["throw-rotational", "throw-overhead", "throw-chest"], why: "A few crisp throws wake up the nervous system with no leg cost.")
        pickGroup(.primaryStrength, upperGroups(decision.upperPattern), why: "Light upper-body strength: maintained, never tiring.")
        pickGroup(.accessory, ["anti-rotation", "anti-extension"], role: "trunk", why: "Trunk control, low effort.")
    }

    mutating func conditioningSession() {
        prep(count: 3, upperFocus: false, fast: decision.conditioning == .repeatedSprint)
        conditioningBlock()
        pickGroup(.cooldown, ["mobility-hip", "mobility-hamstring"], role: "mobility", why: "Easy range after running.")
        pickGroup(.cooldown, ["breathing"], why: "Slow breathing brings the heart rate down.")
    }

    mutating func recovery() {
        conditioningBlock()
        pickGroup(.mobility, ["soft-tissue", "mobility-spine"], why: "Easy movement helps you feel fresher — it isn't training.")
        pickGroup(.mobility, ["mobility-hip"], role: "mobility", why: "Keeps the hips moving after a hard day.")
        pickGroup(.mobility, ["mobility-thoracic", "mobility-hamstring"], why: "Loosens the upper back and hamstrings.")
        pickGroup(.cooldown, ["breathing"], why: "Slow breathing switches your body into recovery mode.")
    }

    mutating func mobility(_ purpose: MobilityPurpose) {
        switch purpose {
        case .preTraining:
            prep(count: 4, upperFocus: loadAreas.contains { ["shoulder", "shoulders", "elbow", "upper-back"].contains($0) }, fast: true)
            pickGroup(.prep, ["sprint-mechanics"], why: "Quick feet before you go.")
        case .targeted:
            for area in loadAreas.prefix(2) {
                let group = ["hamstrings": "mobility-hamstring", "hips": "mobility-hip", "hip-flexors": "mobility-hip", "groin": "mobility-hip",
                             "ankles": "mobility-ankle", "shoulder": "mobility-shoulder", "shoulders": "mobility-shoulder",
                             "upper-back": "mobility-thoracic", "lower-back": "mobility-spine"][area] ?? "mobility-hip"
                pickGroup(.mobility, [group, "mobility-hip"], why: "Range for your \(area.replacingOccurrences(of: "-", with: " ")), which your sport loads.")
            }
            pickGroup(.mobility, ["mobility-flow"], why: "Moves everything once.")
            pickGroup(.mobility, ["mobility-thoracic"], why: "Upper-back rotation for throwing, swinging and breathing.")
            pickGroup(.mobility, ["mobility-ankle", "mobility-hip"], why: "Ankle and hip range for squatting and landing.")
        case .recovery:
            pickGroup(.mobility, ["soft-tissue", "mobility-spine"], why: "Easy movement to feel fresher.")
            pickGroup(.mobility, ["mobility-hip"], role: "mobility", why: "Gentle hip range.")
            pickGroup(.mobility, ["mobility-thoracic"], why: "Opens the upper back.")
            pickGroup(.cooldown, ["breathing"], why: "Slow breathing switches your body into recovery mode.")
        case .eveningDownshift:
            pickGroup(.mobility, ["mobility-spine"], why: "Moves the spine gently after a day of sitting and training.")
            pickGroup(.mobility, ["mobility-thoracic"], why: "Opens the chest and upper back.")
            pickGroup(.mobility, ["mobility-hip"], role: "mobility", why: "A long, easy hold for the hips.")
            pickGroup(.cooldown, ["breathing"], why: "Slow breathing before bed helps you fall asleep.")
        }
    }

    mutating func travel() {
        pickGroup(.prep, ["mobility-flow"], why: "Loosens up after sitting in a car, bus or plane.")
        pickGroup(.primaryStrength, ["single-leg-knee", "squat-bilateral"], why: "Leg strength with no equipment.")
        pickGroup(.primaryStrength, ["push-horizontal"], why: "Push-ups: upper-body strength anywhere.")
        pickGroup(.secondaryStrength, ["hinge-hip-extension", "single-leg-hip"], why: "Glutes and hamstrings, no weights needed.")
        pickGroup(.accessory, ["anti-extension", "anti-lateral"], role: "trunk", why: "Trunk strength on the floor of a hotel room.")
    }

    // MARK: Dosing

    func dose(_ item: CatalogueItem, block: SessionBlock) -> (Dose, Int) {
        let youth = day.age < 18
        var dose = item.defaultDose
        let inSeason = day.phase == .inSeason || day.phase == .postSeason
        let easier = day.readiness == .belowNormal || day.illnessReturnDay != nil
        var rest = 60
        switch block {
        case .prep, .mobility, .cooldown:
            dose.sets = dose.kind == "distance" ? 2 : 1
            if dose.kind == "reps" { dose.reps = min(dose.reps ?? 8, 10) }
            if dose.kind == "time" { dose.seconds = min(dose.seconds ?? 30, block == .prep ? 30 : 60) }
            if block == .mobility, decision.mobilityPurpose != .preTraining { dose.sets = min(item.defaultDose.sets, 2) }
            rest = block == .prep ? 10 : 15
        case .power:
            dose.sets = decision.sessionType == .primer ? 2 : (inSeason ? 3 : 4)
            if dose.kind == "reps" { dose.reps = min(dose.reps ?? 5, 5) }
            if dose.kind == plyometricDoseKind { dose.contacts = min(dose.contacts ?? 5, 6) }
            if dose.kind == "distance" { dose.metres = min(dose.metres ?? 20, 20) }
            rest = item.planProfile.role == "speed" ? 90 : 75
        case .primaryStrength:
            switch day.experience {
            case .beginner: dose.sets = 3; dose.reps = 10; rest = 90
            case .intermediate: dose.sets = 3; dose.reps = 8; rest = 120
            case .experienced: dose.sets = youth ? 3 : 4; dose.reps = youth ? 6 : 5; rest = 150
            }
            if decision.sessionType == .afterPractice || decision.sessionType == .primer || decision.sessionType == .travel { dose.sets = 2; rest = min(rest, 90) }
            if inSeason || easier { dose.sets = max(2, dose.sets - 1) }
            if item.planProfile.isLower, decision.avoids(.highVolumeLowerBody) { dose.sets = 2 }
            if dose.kind != "reps" { dose.reps = item.defaultDose.reps }
        case .secondaryStrength:
            dose.sets = day.experience == .beginner || inSeason || easier || decision.sessionType == .afterPractice ? 2 : 3
            if dose.kind == "reps" { dose.reps = day.experience == .experienced ? 8 : 10 }
            rest = 90
        case .accessory:
            dose.sets = day.experience == .experienced && !inSeason ? 3 : 2
            if dose.kind == "reps" { dose.reps = min(max(dose.reps ?? 10, 8), 15) }
            rest = item.planProfile.role == "trunk" ? 40 : 45
        case .conditioning:
            if let rx = conditioning {
                dose = Dose(kind: "time", sets: rx.reps, seconds: rx.workSeconds)
                rest = rx.restSeconds
            }
        }
        if youth, dose.kind == "reps" {
            dose.sets = min(max(dose.sets, 1), 3)
            if let reps = dose.reps { dose.reps = min(max(reps, block == .prep || block == .power ? 1 : 6), 15) }
        }
        return (dose, rest)
    }

    // MARK: Fitting the time

    func planned() -> [GeneratedPlannedItem] {
        let order: [SessionBlock] = SessionBlock.allCases
        let sorted = picks.enumerated().sorted { lhs, rhs in
            let l = order.firstIndex(of: lhs.element.block) ?? 0, r = order.firstIndex(of: rhs.element.block) ?? 0
            return l != r ? l < r : lhs.offset < rhs.offset
        }.map(\.element)
        return sorted.enumerated().map { index, pick in
            let (dose, rest) = dose(pick.item, block: pick.block)
            var item = GeneratedPlannedItem(itemSlug: pick.item.slug, order: index, dose: dose, restSec: rest, rationale: pick.why, quality: pick.quality)
            item.block = pick.block
            return item
        }
    }

    func minutes(_ items: [GeneratedPlannedItem]) -> Int {
        let seconds = items.reduce(0) { total, item in
            item.block == .conditioning ? total + (conditioning?.minutes ?? 10) * 60 : total + SessionBuilder.seconds(item)
        }
        return Int((Double(seconds) / 60).rounded())
    }

    /// Trims to the target (drop the least important first), or — when
    /// there's lots of room — adds an accessory.
    mutating func fit() {
        let target = decision.durationTarget
        var guardCount = 0
        while minutes(planned()) > target + 4, guardCount < 8 {
            guardCount += 1
            if let i = picks.lastIndex(where: { $0.block == .cooldown }), picks.filter({ $0.block == .cooldown }).count > 1 { picks.remove(at: i); continue }
            if picks.filter({ $0.block == .accessory }).count > 2, let i = picks.lastIndex(where: { $0.block == .accessory }) { picks.remove(at: i); continue }
            if picks.filter({ $0.block == .power }).count > 1, let i = picks.lastIndex(where: { $0.block == .power }) { picks.remove(at: i); continue }
            if picks.filter({ $0.block == .prep }).count > 3, let i = picks.lastIndex(where: { $0.block == .prep }) { picks.remove(at: i); continue }
            if picks.filter({ $0.block == .secondaryStrength }).count > 1, let i = picks.lastIndex(where: { $0.block == .secondaryStrength }) { picks.remove(at: i); continue }
            if picks.filter({ $0.block == .accessory }).count > 1, let i = picks.lastIndex(where: { $0.block == .accessory }) { picks.remove(at: i); continue }
            break
        }
        grow()
    }

    /// Fills a session that came out well short of its target with the
    /// next most useful thing for that kind of session — never filler.
    mutating func grow() {
        let target = decision.durationTarget
        func short(_ margin: Int) -> Bool { minutes(planned()) < target - margin }
        switch decision.sessionType {
        case .gymDevelopment:
            if short(10), !decision.avoids(.highVolumeLowerBody), decision.legBudget >= 2,
               !picks.contains(where: { $0.block == .secondaryStrength && $0.item.planProfile.isLower }) {
                pickGroup(.secondaryStrength, ["single-leg-knee", "single-leg-hip", "single-leg-lateral"], why: "One leg at a time — how you actually run, cut and land.")
            }
            if short(8) { pickGroup(.accessory, ["carry", "hamstring-eccentric", "shoulder-health", "calf-ankle"], why: "Extra resilience work while there's time.") }
            if short(5) { pickGroup(.cooldown, ["mobility-hip", "mobility-thoracic"], role: "mobility", why: "A couple of minutes of easy range to finish.") }
        case .afterPractice:
            if short(6) { pickGroup(.accessory, ["shoulder-health", "grip", "neck"], why: "Small shoulder work that keeps throwing, tackling and falling safe.") }
            if short(6), decision.legBudget >= 1 { pickGroup(.accessory, ["hamstring-eccentric", "calf-ankle"], why: "Low-volume work that protects hamstrings and ankles.") }
            if short(6) { pickGroup(.accessory, ["anti-lateral", "anti-extension", "carry"], role: "trunk", why: "A second trunk exercise from a different direction.") }
            if short(4) { pickGroup(.cooldown, ["mobility-hip", "mobility-thoracic", "breathing"], why: "Easy range and slow breathing to start recovering.") }
            if short(4) { pickGroup(.cooldown, ["breathing", "mobility-spine"], why: "Slow breathing switches your body into recovery mode.") }
        case .primer:
            if short(6) { pickGroup(.cooldown, ["mobility-hip", "mobility-flow"], why: "Easy range to finish, nothing tiring.") }
        case .mobility where decision.mobilityPurpose != .preTraining:
            var guardCount = 0
            while short(3), guardCount < 2 {
                guardCount += 1
                let groups = decision.mobilityPurpose == .preTraining ? ["hip-activation", "sprint-mechanics", "mobility-ankle"]
                    : ["mobility-hamstring", "mobility-ankle", "mobility-shoulder", "mobility-hip", "mobility-spine"]
                if !pickGroup(.mobility, groups, why: "More easy range for the areas your sport loads.") { break }
            }
        default:
            break
        }
    }

    // MARK: Output

    func session() -> GeneratedSession {
        let items = planned()
        let title: String
        switch decision.sessionType {
        case .mobility: title = decision.mobilityPurpose?.title ?? "Mobility"
        case .conditioning: title = decision.conditioning?.title ?? "Conditioning"
        case .gymDevelopment:
            let focus = decision.primaryTargets.first.map { $0 == .strength ? "Strength" : $0 == .upperStrength ? "Upper-body strength" : $0.title.capitalized } ?? "Development"
            title = "\(focus) day"
        default: title = decision.sessionType.title
        }
        var session = GeneratedSession(date: day.date, title: title, focusQualities: decision.primaryTargets.map(\.rawValue),
                                       estimatedMinutes: decision.sessionType == .rest ? 0 : max(5, minutes(items)), items: items)
        session.decision = decision
        session.explanation = PlanExplanation.make(decision: decision, day: day, items: items, catalogue: kit.catalogue, conditioning: conditioning)
        return session
    }
}
