import XCTest

final class SkillMenuEngineTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeItem(
        slug: String, qualities: [String: Double], equipment: [String] = [],
        minAge: Int = 13, supervisionLevel: String = "SELF", defaultDose: Dose,
        itemSportSlug: String? = nil
    ) -> CatalogueItem {
        CatalogueItem(
            slug: slug, name: slug, kind: "exercise", qualities: qualities, muscles: [:],
            equipment: equipment, surface: "anywhere", minAge: minAge, supervisionLevel: supervisionLevel,
            setup: [], execution: [], cues: [], mistakes: [], progressions: [], regressions: [], substitutes: [],
            defaultDose: defaultDose, restSeconds: 60, startPose: "hinge", endPose: "hinge",
            unilateralEligible: nil, tempoEligible: nil, prop: nil, variant: nil, baseSlug: nil,
            constraintAxes: nil, equipmentChain: nil, unilateralPosePattern: nil, unilateralStabilityQuality: nil,
            itemSportSlug: itemSportSlug
        )
    }

    private func catalogue(_ items: [CatalogueItem]) -> Catalogue {
        Catalogue(itemsBySlug: Dictionary(uniqueKeysWithValues: items.map { ($0.slug, $0) }))
    }

    /// §8's own worked example: soccer.shooting-power's exact weights.
    private let shootingPowerWeights: [String: Double] = [
        "deceleration": 1.0, "rotational-power": 0.9, "horizontal-power": 0.8, "vertical-power": 0.8,
        "lower-body-strength": 0.7, "ankle-stiffness": 0.7, "reactive-strength": 0.7,
        "hip-mobility": 0.5, "single-leg-stability": 0.5,
    ]

    private func workedExampleCatalogue() -> Catalogue {
        catalogue([
            makeItem(slug: "accel-brake", qualities: ["deceleration": 1.0], defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
            makeItem(slug: "rotate-throw", qualities: ["rotational-power": 1.0], defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
            makeItem(slug: "horiz-jump", qualities: ["horizontal-power": 1.0], defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
            makeItem(slug: "vert-bound", qualities: ["vertical-power": 1.0], defaultDose: Dose(kind: "contacts", sets: 2, contacts: 20)),
            makeItem(slug: "ankle-hops", qualities: ["ankle-stiffness": 1.0], defaultDose: Dose(kind: "reps", sets: 2, reps: 10)),
            makeItem(slug: "trap-bar-dl", qualities: ["lower-body-strength": 1.0], defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
        ])
    }

    private func baseInput(
        gameDate: Date, today: Date, catalogue: Catalogue, birthDate: Date = Date(timeIntervalSince1970: 0),
        equipmentAvailable: Set<String> = [], seed: String = "skill-seed-1"
    ) -> SkillMenuInput {
        SkillMenuInput(
            sportSlug: "soccer", skillSlug: "shooting-power", skillName: "Shooting power",
            qualityWeights: shootingPowerWeights, today: today, gameDate: gameDate, birthDate: birthDate,
            equipmentAvailable: equipmentAvailable, catalogue: catalogue, seed: seed, now: today
        )
    }

    // MARK: - §8's worked example, day by day

    func testSevenDaysOutReproducesTheWorkedExampleDayStructure() {
        let gameDay = date(2026, 10, 8)
        let today = date(2026, 10, 1) // exactly 7 days out
        let input = baseInput(gameDate: gameDay, today: today, catalogue: workedExampleCatalogue())

        let block = SkillMenuEngine.generate(input)

        XCTAssertEqual(block.days.count, 8, "day -7 through game day inclusive")
        let titles = block.days.map(\.title)
        XCTAssertEqual(titles, [
            "Strength emphasis",
            "Drill day",
            "Plyometrics and mobility",
            "Light technical — full recovery emphasis",
            "Complex pairing — building into game day",
            "Sharpening only — low volume, full intent",
            "Primer — short activation, not a hard session",
            "Warm-up sequence only — game day",
        ])
    }

    func testGameDayIsAWarmupOnlyEmptySession() {
        let gameDay = date(2026, 10, 8)
        let input = baseInput(gameDate: gameDay, today: date(2026, 10, 1), catalogue: workedExampleCatalogue())

        let block = SkillMenuEngine.generate(input)

        XCTAssertEqual(block.days.last?.items, [])
        XCTAssertEqual(block.days.last?.date, calendar.startOfDay(for: gameDay))
    }

    func testThePlyometricBuildDayStaysWithinHalfTheAgeBasedWeeklyContactCap() {
        let gameDay = date(2026, 10, 8)
        let fifteenYearsOld = date(2011, 1, 1) // weeklyContactCap = 100 -> half = 50
        let input = baseInput(gameDate: gameDay, today: date(2026, 10, 1), catalogue: workedExampleCatalogue(), birthDate: fifteenYearsOld)

        let block = SkillMenuEngine.generate(input)

        let plyoDay = block.days.first { $0.title == "Plyometrics and mobility" }
        let plyoItem = plyoDay?.items.first { $0.dose.kind == plyometricDoseKind }
        XCTAssertNotNil(plyoItem)
        let contacts = (plyoItem?.dose.sets ?? 0) * (plyoItem?.dose.contacts ?? 0)
        XCTAssertLessThanOrEqual(contacts, 50)
    }

    /// §10: "no lifting to failure" two days out. Isolated to a catalogue
    /// with exactly one item, strength-group, mapped to the skill's only
    /// quality — so if exclusion did nothing, this item would obviously be
    /// picked (it's the only candidate at all); excluding it correctly
    /// leaves the day empty rather than lifting this close to a game.
    func testAnOversizedPlyometricDoseIsActuallyReducedToFitTheCap() {
        let oversized = catalogue([
            makeItem(slug: "vert-bound", qualities: ["vertical-power": 1.0], defaultDose: Dose(kind: "contacts", sets: 5, contacts: 30)),
        ])
        let gameDay = date(2026, 10, 8)
        let fifteenYearsOld = date(2011, 1, 1) // weeklyContactCap = 100 -> half = 50
        let input = SkillMenuInput(
            sportSlug: "soccer", skillSlug: "test-skill", skillName: "Test skill",
            qualityWeights: ["vertical-power": 1.0], today: date(2026, 10, 1), gameDate: gameDay,
            birthDate: fifteenYearsOld, catalogue: oversized, seed: "seed", now: date(2026, 10, 1)
        )

        let block = SkillMenuEngine.generate(input)

        let plyoItem = block.days.flatMap(\.items).first { $0.itemSlug == "vert-bound" }
        XCTAssertNotNil(plyoItem)
        let contacts = (plyoItem?.dose.sets ?? 0) * (plyoItem?.dose.contacts ?? 0)
        XCTAssertLessThanOrEqual(contacts, 50, "150 contacts as authored must be reduced under the 50-contact block cap")
        XCTAssertLessThan(plyoItem!.dose.sets, 5, "sets must actually have been cut, not just coincidentally in range")
    }

    func testQualityOverQuantityDayExcludesStrengthWorkEvenWhenItIsTheOnlyCandidate() {
        let onlyStrength = catalogue([
            makeItem(slug: "trap-bar-dl", qualities: ["lower-body-strength": 1.0], defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
        ])
        let gameDay = date(2026, 10, 8)
        let input = SkillMenuInput(
            sportSlug: "soccer", skillSlug: "test-skill", skillName: "Test skill",
            qualityWeights: ["lower-body-strength": 1.0], today: date(2026, 10, 6), gameDate: gameDay,
            birthDate: Date(timeIntervalSince1970: 0), catalogue: onlyStrength, seed: "seed", now: date(2026, 10, 6)
        )

        let block = SkillMenuEngine.generate(input)

        let sharpDay = block.days.first { $0.title == "Sharpening only — low volume, full intent" }
        XCTAssertEqual(sharpDay?.items, [])
    }

    // MARK: - Window capping

    func testAGameMoreThanMaxWindowDaysOutIsCappedToAFocusedRunIn() {
        let gameDay = date(2026, 11, 15)
        let today = date(2026, 10, 1) // 45 days out
        let input = baseInput(gameDate: gameDay, today: today, catalogue: workedExampleCatalogue())

        let block = SkillMenuEngine.generate(input)

        XCTAssertEqual(block.days.count, SkillMenuEngine.maxWindowDays + 1)
        XCTAssertEqual(block.days.last?.date, calendar.startOfDay(for: gameDay))
        XCTAssertTrue(block.realisticExpectation.contains("45 days out"))
    }

    func testAGameTodayProducesASingleWarmupOnlyDay() {
        let gameDay = date(2026, 10, 8)
        let input = baseInput(gameDate: gameDay, today: gameDay, catalogue: workedExampleCatalogue())

        let block = SkillMenuEngine.generate(input)

        XCTAssertEqual(block.days.count, 1)
        XCTAssertEqual(block.days.first?.items, [])
    }

    // MARK: - Determinism, equipment, honesty about the reason

    func testTheSameSeedProducesByteIdenticalOutput() {
        let gameDay = date(2026, 10, 8)
        let input = baseInput(gameDate: gameDay, today: date(2026, 10, 1), catalogue: workedExampleCatalogue())

        XCTAssertEqual(SkillMenuEngine.generate(input), SkillMenuEngine.generate(input))
    }

    func testAnItemRequiringUnavailableEquipmentIsNeverSelected() {
        let gated = catalogue([
            makeItem(slug: "gated-lift", qualities: ["deceleration": 1.0], equipment: ["trap-bar"], defaultDose: Dose(kind: "reps", sets: 3, reps: 8)),
        ])
        let gameDay = date(2026, 10, 8)
        let input = baseInput(gameDate: gameDay, today: date(2026, 10, 1), catalogue: gated, equipmentAvailable: [])

        let block = SkillMenuEngine.generate(input)

        XCTAssertFalse(block.days.flatMap(\.items).contains { $0.itemSlug == "gated-lift" })
    }

    func testEveryNonEmptyDaysItemsCarryAPlainLanguageReasonMentioningTheSkill() {
        let gameDay = date(2026, 10, 8)
        let input = baseInput(gameDate: gameDay, today: date(2026, 10, 1), catalogue: workedExampleCatalogue())

        let block = SkillMenuEngine.generate(input)

        for item in block.days.flatMap(\.items) {
            XCTAssertTrue(item.rationale.lowercased().contains("shooting power"), item.rationale)
        }
    }

    func testShortWindowExpectationIsHonestNotOverpromising() {
        let gameDay = date(2026, 10, 8)
        let input = baseInput(gameDate: gameDay, today: date(2026, 10, 1), catalogue: workedExampleCatalogue())

        let block = SkillMenuEngine.generate(input)

        XCTAssertTrue(block.realisticExpectation.contains("sharper and better coordinated"))
        XCTAssertTrue(block.realisticExpectation.contains("not fundamentally stronger"))
    }
}
