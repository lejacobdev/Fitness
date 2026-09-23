import XCTest

final class MuscleWorkoutGeneratorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let adult = Date(timeIntervalSince1970: 0)

    private func item(
        _ slug: String, muscles: [String: Double], qualities: [String: Double] = ["lower-body-strength": 1.0],
        equipment: [String] = [], supervision: String = "SELF", minAge: Int = 13,
        dose: Dose = Dose(kind: "reps", sets: 3, reps: 8)
    ) -> CatalogueItem {
        CatalogueItem(
            slug: slug, name: slug, kind: "exercise", qualities: qualities, muscles: muscles,
            equipment: equipment, surface: "anywhere", minAge: minAge, supervisionLevel: supervision,
            setup: [], execution: [], cues: [], mistakes: [], progressions: [], regressions: [], substitutes: [],
            defaultDose: dose, restSeconds: 60, startPose: "hinge", endPose: "hinge",
            unilateralEligible: nil, tempoEligible: nil, prop: nil, variant: nil, baseSlug: nil,
            constraintAxes: nil, equipmentChain: nil, unilateralPosePattern: nil, unilateralStabilityQuality: nil,
            itemSportSlug: nil
        )
    }

    private func catalogue(_ items: [CatalogueItem]) -> Catalogue {
        Catalogue(itemsBySlug: Dictionary(uniqueKeysWithValues: items.map { ($0.slug, $0) }))
    }

    private var library: Catalogue {
        catalogue([
            item("squat", muscles: ["rectus-femoris": 1.0]),
            item("lunge", muscles: ["rectus-femoris": 0.8]),
            item("step-up", muscles: ["rectus-femoris": 0.7]),
            item("curl", muscles: ["biceps-brachii": 1.0], qualities: ["upper-body-pull": 1.0]),
            item("chin-up", muscles: ["biceps-brachii": 0.6], qualities: ["upper-body-pull": 1.0]),
            item("hip-opener", muscles: ["rectus-femoris": 0.2], qualities: ["hip-mobility": 1.0]),
            item("barbell-squat", muscles: ["rectus-femoris": 1.0], equipment: ["barbell"]),
            item("power-clean", muscles: ["rectus-femoris": 1.0], supervision: "COACHED"),
        ])
    }

    private func generate(_ regions: Set<MuscleRegion>, minutes: Int = 60, equipment: Set<String> = [], coached: Bool = false, seed: String = "s") -> GeneratedSession {
        MuscleWorkoutGenerator.generate(MuscleWorkoutInput(
            regions: regions, minutes: minutes, birthDate: adult, trainsUnderCoach: coached,
            equipmentAvailable: equipment, catalogue: library, seed: seed, now: now
        ))
    }

    func testEveryChosenRegionGetsWork() {
        let session = generate([.quadriceps, .arm])
        let slugs = Set(session.items.map(\.itemSlug))
        XCTAssertFalse(slugs.isDisjoint(with: ["squat", "lunge", "step-up"]), "quads")
        XCTAssertFalse(slugs.isDisjoint(with: ["curl", "chin-up"]), "arms")
    }

    func testOnlyTheChosenRegionsAreTrainedApartFromTheWarmUp() {
        let session = generate([.arm])
        let main = session.items.filter { !$0.rationale.hasPrefix("Warm-up") }.map(\.itemSlug)
        XCTAssertFalse(main.isEmpty)
        XCTAssertTrue(Set(main).isSubset(of: ["curl", "chin-up"]))
    }

    func testAWarmUpOpensTheSessionWhenTheLibraryHasOne() {
        XCTAssertEqual(generate([.quadriceps]).items.first?.itemSlug, "hip-opener")
    }

    func testEquipmentAndCoachingGatesAreRespected() {
        let slugs = generate([.quadriceps]).items.map(\.itemSlug)
        XCTAssertFalse(slugs.contains("barbell-squat"))
        XCTAssertFalse(slugs.contains("power-clean"))

        let withGymAndCoach = generate([.quadriceps], equipment: ["barbell"], coached: true).items.map(\.itemSlug)
        XCTAssertTrue(withGymAndCoach.contains("barbell-squat") || withGymAndCoach.contains("power-clean"))
    }

    func testTheSessionFitsTheTimeBudget() {
        for minutes in [10, 20, 45] {
            XCTAssertLessThanOrEqual(generate([.quadriceps, .arm], minutes: minutes).estimatedMinutes, minutes)
        }
    }

    func testNoExerciseAppearsTwice() {
        let slugs = generate([.quadriceps, .arm, .hip]).items.map(\.itemSlug)
        XCTAssertEqual(slugs.count, Set(slugs).count)
    }

    func testSameSeedSameWorkout() {
        XCTAssertEqual(generate([.quadriceps], seed: "a"), generate([.quadriceps], seed: "a"))
    }

    func testOrderIsContiguousAndTitleNamesTheRegions() {
        let session = generate([.quadriceps, .arm])
        XCTAssertEqual(session.items.map(\.order), Array(0..<session.items.count))
        XCTAssertEqual(session.title, "Arms + Quads workout")
    }
}
