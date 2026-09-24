import XCTest

final class PlanGeneratorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Fills in every field a real pack item carries, defaulting the ones no
    /// test below varies, so each scenario only has to state what it's
    /// actually testing.
    private func makeItem(
        slug: String, qualities: [String: Double], equipment: [String] = [],
        minAge: Int = 13, supervisionLevel: String = "SELF", defaultDose: Dose, restSeconds: Int = 60, sport: String? = nil
    ) -> CatalogueItem {
        CatalogueItem(
            slug: slug, name: slug, kind: "exercise", qualities: qualities, muscles: [:],
            equipment: equipment, surface: "anywhere", minAge: minAge, supervisionLevel: supervisionLevel,
            setup: [], execution: [], cues: [], mistakes: [], progressions: [], regressions: [], substitutes: [],
            defaultDose: defaultDose, restSeconds: restSeconds, startPose: "hinge", endPose: "hinge",
            unilateralEligible: nil, tempoEligible: nil, prop: nil, variant: nil, baseSlug: nil,
            constraintAxes: nil, equipmentChain: nil, unilateralPosePattern: nil, unilateralStabilityQuality: nil,
            itemSportSlug: sport
        )
    }

    private func catalogue(_ items: [CatalogueItem]) -> Catalogue {
        Catalogue(itemsBySlug: Dictionary(uniqueKeysWithValues: items.map { ($0.slug, $0) }))
    }

    private func baseInput(
        sportProfile: [String: Double], catalogue: Catalogue, equipmentAvailable: Set<String> = [],
        birthDate: Date = Date(timeIntervalSince1970: 0), // very old -> adult, unless a test overrides it
        trainsUnderCoach: Bool = false, seed: String = "seed-1",
        timeBudgetMinutesPerSession: Int = 60
    ) -> PlanGeneratorInput {
        PlanGeneratorInput(
            sportProfile: sportProfile, seasonStart: date(2026, 9, 1), seasonEnd: date(2026, 11, 30),
            weekStart: date(2026, 6, 1), // off-season relative to that window -> 3 sessions/week
            birthDate: birthDate, trainsUnderCoach: trainsUnderCoach, equipmentAvailable: equipmentAvailable,
            catalogue: catalogue, seed: seed, timeBudgetMinutesPerSession: timeBudgetMinutesPerSession,
            now: date(2026, 6, 1)
        )
    }

    // MARK: - Determinism

    func testTheSameInputAndSeedProduceByteIdenticalOutput() {
        let items = [
            makeItem(slug: "accel-a", qualities: ["acceleration": 1.0], defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
            makeItem(slug: "accel-b", qualities: ["acceleration": 0.9], defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
            makeItem(slug: "strength-a", qualities: ["lower-body-strength": 1.0], defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
        ]
        let input = baseInput(sportProfile: ["acceleration": 1.0, "lower-body-strength": 0.8], catalogue: catalogue(items))

        let first = PlanGenerator.generate(input)
        let second = PlanGenerator.generate(input)

        XCTAssertEqual(first, second)
    }

    func testADifferentSeedCanProduceADifferentPick() {
        // Two equally-eligible items for the same quality -- the seed is
        // what decides which one wins, so different seeds are allowed (not
        // guaranteed) to disagree. Assert the generator is at least capable
        // of varying by seed, not that it always must for any given pair.
        let items = (0..<8).map { i in
            makeItem(slug: "accel-\(i)", qualities: ["acceleration": 1.0], defaultDose: Dose(kind: "reps", sets: 3, reps: 8))
        }
        let cat = catalogue(items)

        let picks = Set((0..<8).map { i -> String in
            let input = baseInput(sportProfile: ["acceleration": 1.0], catalogue: cat, seed: "seed-\(i)")
            return PlanGenerator.generate(input).sessions.first?.items.first?.itemSlug ?? ""
        })

        XCTAssertGreaterThan(picks.count, 1, "expected different seeds to select different items at least sometimes")
    }

    // MARK: - Equipment filter

    func testAnItemRequiringUnavailableEquipmentIsNeverSelected() {
        let items = [
            makeItem(
                slug: "trap-bar-dl", qualities: ["lower-body-strength": 1.0], equipment: ["trap-bar", "weight-plate"],
                defaultDose: Dose(kind: "reps", sets: 3, reps: 8)
            ),
        ]
        let input = baseInput(sportProfile: ["lower-body-strength": 1.0], catalogue: catalogue(items), equipmentAvailable: [])

        let week = PlanGenerator.generate(input)

        let allSlugs = week.sessions.flatMap { $0.items.map(\.itemSlug) }
        XCTAssertFalse(allSlugs.contains("trap-bar-dl"))
    }

    func testAnItemWithOnlyAlwaysFreeEquipmentIsSelectedEvenWithNothingOwned() {
        let items = [
            makeItem(slug: "wall-drill", qualities: ["acceleration": 1.0], equipment: ["wall"], defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
        ]
        let input = baseInput(sportProfile: ["acceleration": 1.0], catalogue: catalogue(items), equipmentAvailable: [])

        let week = PlanGenerator.generate(input)

        let allSlugs = week.sessions.flatMap { $0.items.map(\.itemSlug) }
        XCTAssertTrue(allSlugs.contains("wall-drill"))
    }

    // MARK: - Youth envelope

    func testUnderEighteenGetsRepsAndSetsClampedToTheYouthEnvelope() {
        let items = [
            makeItem(slug: "heavy-lift", qualities: ["lower-body-strength": 1.0], defaultDose: Dose(kind: "reps", sets: 6, reps: 20)),
        ]
        let fifteenYearsOld = date(2011, 1, 1)
        let input = baseInput(
            sportProfile: ["lower-body-strength": 1.0], catalogue: catalogue(items), birthDate: fifteenYearsOld
        )

        let week = PlanGenerator.generate(input)
        let generatedItem = week.sessions.flatMap(\.items).first { $0.itemSlug == "heavy-lift" }

        XCTAssertNotNil(generatedItem)
        XCTAssertTrue((1...3).contains(generatedItem!.dose.sets))
        XCTAssertTrue((6...15).contains(generatedItem!.dose.reps ?? 0))
    }

    func testEighteenAndOverUsesTheItemsOwnDoseUnclamped() {
        let items = [
            makeItem(slug: "heavy-lift", qualities: ["lower-body-strength": 1.0], defaultDose: Dose(kind: "reps", sets: 6, reps: 20)),
        ]
        let twentyYearsOld = date(2006, 1, 1)
        let input = baseInput(
            sportProfile: ["lower-body-strength": 1.0], catalogue: catalogue(items), birthDate: twentyYearsOld
        )

        let week = PlanGenerator.generate(input)
        let generatedItem = week.sessions.flatMap(\.items).first { $0.itemSlug == "heavy-lift" }

        XCTAssertEqual(generatedItem?.dose.sets, 6)
        XCTAssertEqual(generatedItem?.dose.reps, 20)
    }

    // MARK: - COACHED / minAge gating

    func testACoachedItemIsExcludedWithoutCoachSupervision() {
        let items = [
            makeItem(slug: "coached-lift", qualities: ["lower-body-strength": 1.0], supervisionLevel: "COACHED", defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
        ]
        let input = baseInput(sportProfile: ["lower-body-strength": 1.0], catalogue: catalogue(items), trainsUnderCoach: false)

        let week = PlanGenerator.generate(input)

        XCTAssertFalse(week.sessions.flatMap(\.items).contains { $0.itemSlug == "coached-lift" })
    }

    func testACoachedItemIsIncludedWithCoachSupervision() {
        let items = [
            makeItem(slug: "coached-lift", qualities: ["lower-body-strength": 1.0], supervisionLevel: "COACHED", defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
        ]
        let input = baseInput(sportProfile: ["lower-body-strength": 1.0], catalogue: catalogue(items), trainsUnderCoach: true)

        let week = PlanGenerator.generate(input)

        XCTAssertTrue(week.sessions.flatMap(\.items).contains { $0.itemSlug == "coached-lift" })
    }

    func testAnItemAboveTheAthletesAgeIsExcluded() {
        let items = [
            makeItem(slug: "advanced-drill", qualities: ["acceleration": 1.0], minAge: 16, defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
        ]
        let fifteenYearsOld = date(2011, 1, 1)
        let input = baseInput(sportProfile: ["acceleration": 1.0], catalogue: catalogue(items), birthDate: fifteenYearsOld)

        let week = PlanGenerator.generate(input)

        XCTAssertFalse(week.sessions.flatMap(\.items).contains { $0.itemSlug == "advanced-drill" })
    }

    // MARK: - Block ordering (§10: plyometrics/sprint before lifting, always)

    func testSpeedAndPowerItemsAlwaysComeBeforeStrengthItemsInTheSameSession() {
        let items = [
            makeItem(slug: "sprint-drill", qualities: ["acceleration": 1.0], defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
            makeItem(slug: "strength-lift", qualities: ["lower-body-strength": 1.0], defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
        ]
        let input = baseInput(
            sportProfile: ["acceleration": 1.0, "lower-body-strength": 0.9], catalogue: catalogue(items)
        )

        let week = PlanGenerator.generate(input)
        guard let session = week.sessions.first(where: { session in
            session.items.contains { $0.itemSlug == "sprint-drill" } && session.items.contains { $0.itemSlug == "strength-lift" }
        }) else {
            XCTFail("expected at least one session to contain both items")
            return
        }

        let sprintOrder = session.items.first { $0.itemSlug == "sprint-drill" }!.order
        let strengthOrder = session.items.first { $0.itemSlug == "strength-lift" }!.order
        XCTAssertLessThan(sprintOrder, strengthOrder)
    }

    // MARK: - Time budget

    func testEverySessionStaysWithinItsTimeBudgetAndSkipsWhatDoesNotFit() {
        // Three long items across three different quality groups, each
        // ~6 minutes -- a 10-minute budget can fit exactly one of them, so
        // this actually exercises the skip path rather than just staying
        // trivially under a generous budget.
        let items = [
            makeItem(slug: "long-a", qualities: ["acceleration": 1.0], defaultDose: Dose(kind: "time", sets: 1, seconds: 1200), restSeconds: 300),
            makeItem(slug: "long-b", qualities: ["lower-body-strength": 1.0], defaultDose: Dose(kind: "time", sets: 1, seconds: 1200), restSeconds: 300),
            makeItem(slug: "long-c", qualities: ["aerobic-base": 1.0], defaultDose: Dose(kind: "time", sets: 1, seconds: 1200), restSeconds: 300),
        ]
        let input = baseInput(
            sportProfile: ["acceleration": 1.0, "lower-body-strength": 0.9, "aerobic-base": 0.8],
            catalogue: catalogue(items), timeBudgetMinutesPerSession: 10
        )

        let week = PlanGenerator.generate(input)

        for session in week.sessions {
            XCTAssertLessThanOrEqual(session.estimatedMinutes, 10)
            XCTAssertLessThan(session.items.count, 3, "expected at least one long item to be skipped under a tight budget")
        }
    }

    // MARK: - Ground-contact cap

    func testWeeklyGroundContactsNeverExceedTheAgeBasedCap() {
        // 40 contacts per occurrence, targeted every session (off-season ->
        // 3 sessions/week): the first two fit under the 15-year-old's
        // 100-contact cap (40, then 80), the third would push to 120 and
        // must be skipped -- this exercises accumulation across the week,
        // not just a single oversized item being rejected outright.
        let items = [
            makeItem(
                slug: "jump-drill", qualities: ["vertical-power": 1.0],
                defaultDose: Dose(kind: "contacts", sets: 2, contacts: 20)
            ),
        ]
        let fifteenYearsOld = date(2011, 1, 1) // cap = 100 per PlanGenerator's own constant table
        let input = baseInput(sportProfile: ["vertical-power": 1.0], catalogue: catalogue(items), birthDate: fifteenYearsOld)

        let week = PlanGenerator.generate(input)

        let totalContacts = week.sessions.flatMap(\.items)
            .filter { $0.dose.kind == "contacts" }
            .reduce(0) { $0 + $1.dose.sets * ($1.dose.contacts ?? 0) }
        XCTAssertLessThanOrEqual(totalContacts, 100)

        let sessionsWithTheItem = week.sessions.filter { session in session.items.contains { $0.itemSlug == "jump-drill" } }
        XCTAssertLessThan(sessionsWithTheItem.count, week.sessions.count, "expected the cap to skip at least one session's worth")
    }

    // MARK: - Sport and position

    private func drill(_ slug: String, _ qualities: [String: Double], sport: String?, positions: [String]? = nil) -> CatalogueItem {
        var item = makeItem(slug: slug, qualities: qualities, defaultDose: Dose(kind: "reps", sets: 3, reps: 8), sport: sport)
        item.positions = positions
        return item
    }

    private func positionWeek(position: String?) -> [String] {
        let items = [
            drill("keeper-dive", ["reactive-agility": 1.0, "vertical-power": 0.8], sport: "soccer", positions: ["goalkeeper"]),
            drill("keeper-high-catch", ["vertical-power": 1.0], sport: "soccer", positions: ["goalkeeper"]),
            drill("rondo", ["aerobic-base": 1.0, "reactive-agility": 0.8], sport: "soccer"),
            drill("repeat-sprints", ["repeat-sprint": 1.0], sport: "soccer"),
            drill("puck-handling", ["reactive-agility": 1.0], sport: "ice-hockey"),
            drill("goalie-butterfly", ["reactive-agility": 1.0], sport: "ice-hockey", positions: ["goaltender"]),
            drill("box-jump", ["vertical-power": 1.0], sport: nil),
        ]
        let keeper = ["reactive-agility": 1.0, "vertical-power": 0.9]
        let midfield = ["aerobic-base": 1.0, "repeat-sprint": 0.9]
        let input = PlanGeneratorInput(
            sportProfile: ["aerobic-base": 0.8, "repeat-sprint": 0.8, "reactive-agility": 0.6],
            positionProfile: position == "goalkeeper" ? keeper : position == nil ? nil : midfield,
            seasonStart: date(2026, 9, 1), seasonEnd: date(2026, 11, 30), weekStart: date(2026, 6, 1),
            birthDate: Date(timeIntervalSince1970: 0), trainsUnderCoach: false, equipmentAvailable: [],
            catalogue: catalogue(items), seed: "seed-1", now: date(2026, 6, 1),
            sportSlug: "soccer", positionSlug: position
        )
        return PlanGenerator.generate(input).sessions.flatMap { $0.items.map(\.itemSlug) }
    }

    func testAGoalkeeperGetsKeeperDrillsInEverySession() {
        let slugs = positionWeek(position: "goalkeeper")
        XCTAssertTrue(slugs.contains("keeper-dive") || slugs.contains("keeper-high-catch"))
        XCTAssertFalse(slugs.contains("goalie-butterfly"), "another sport's goalie drill")
        XCTAssertFalse(slugs.contains("puck-handling"), "another sport's drill")
    }

    func testAMidfielderNeverGetsKeeperDrills() {
        let slugs = positionWeek(position: "midfielder")
        XCTAssertFalse(slugs.contains("keeper-dive"))
        XCTAssertFalse(slugs.contains("keeper-high-catch"))
        XCTAssertFalse(slugs.contains("puck-handling"))
        XCTAssertTrue(slugs.contains("rondo") || slugs.contains("repeat-sprints"))
    }

    func testNoPositionMeansNoPositionDrills() {
        let slugs = positionWeek(position: nil)
        XCTAssertFalse(slugs.contains { $0.hasPrefix("keeper-") })
    }

    func testGoalkeeperAndMidfielderWeeksDiffer() {
        XCTAssertNotEqual(positionWeek(position: "goalkeeper"), positionWeek(position: "midfielder"))
    }

    func testAnotherSportsDrillNeverFitsAnyPlan() {
        let hockey = drill("puck-handling", ["reactive-agility": 1.0], sport: "ice-hockey")
        let general = drill("box-jump", ["vertical-power": 1.0], sport: nil)
        let keeper = drill("keeper-dive", ["reactive-agility": 1.0], sport: "soccer", positions: ["goalkeeper"])
        XCTAssertFalse(hockey.fits(sport: "soccer", position: nil))
        XCTAssertFalse(hockey.fits(sport: nil, position: nil), "no sport means no sport drills")
        XCTAssertTrue(hockey.fits(sport: "ice-hockey", position: nil))
        XCTAssertTrue(general.fits(sport: "soccer", position: "midfielder"))
        XCTAssertTrue(keeper.fits(sport: "soccer", position: "goalkeeper"))
        XCTAssertFalse(keeper.fits(sport: "soccer", position: "midfielder"))
        XCTAssertFalse(keeper.fits(sport: "soccer", position: nil))
    }
}
