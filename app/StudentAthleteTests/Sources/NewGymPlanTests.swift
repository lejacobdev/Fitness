import XCTest

/// Building a new gym plan: it really is new, and ♻︎ swaps one exercise for
/// another that fits the same spot, the athlete's equipment and level.
final class NewGymPlanTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private func day(_ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 6, day: d))! }

    private func item(_ slug: String, _ quality: String, equipment: [String] = [], dose: Dose = Dose(kind: "reps", sets: 3, reps: 8)) -> CatalogueItem {
        CatalogueItem(
            slug: slug, name: slug, kind: "exercise", qualities: [quality: 1.0], muscles: [:],
            equipment: equipment, surface: "anywhere", minAge: 13, supervisionLevel: "SELF",
            setup: [], execution: [], cues: [], mistakes: [], progressions: [], regressions: [], substitutes: [],
            defaultDose: dose, restSeconds: 60, startPose: "hinge", endPose: "hinge",
            unilateralEligible: nil, tempoEligible: nil, prop: nil, variant: nil, baseSlug: nil,
            constraintAxes: nil, equipmentChain: nil, unilateralPosePattern: nil, unilateralStabilityQuality: nil,
            itemSportSlug: nil
        )
    }

    private var catalogue: Catalogue {
        let items = [
            item("split-squat", "lower-body-strength"), item("step-up", "lower-body-strength"),
            item("goblet-squat", "lower-body-strength"), item("back-squat", "lower-body-strength", equipment: ["barbell"]),
            item("push-up", "upper-body-push"),
        ]
        return Catalogue(itemsBySlug: Dictionary(uniqueKeysWithValues: items.map { ($0.slug, $0) }))
    }

    private func input(avoid: Set<String> = [], seed: String = "a") -> PlanGeneratorInput {
        PlanGeneratorInput(
            sportProfile: ["lower-body-strength": 1], seasonStart: day(1).addingTimeInterval(120 * 86_400),
            seasonEnd: day(1).addingTimeInterval(200 * 86_400), weekStart: day(1), birthDate: day(1).addingTimeInterval(-16 * 365 * 86_400),
            catalogue: catalogue, seed: seed, now: day(1), avoid: avoid
        )
    }

    func testANewPlanLeavesOutTheLastPlansExercisesWhenItCan() {
        let first = Set(PlanGenerator.generate(input()).sessions.flatMap { $0.items.map(\.itemSlug) })
        let next = Set(PlanGenerator.generate(input(avoid: first, seed: "b")).sessions.flatMap { $0.items.map(\.itemSlug) })
        XCTAssertFalse(next.isEmpty)
        XCTAssertTrue(next.isDisjoint(with: first) || first.count >= 3, "new exercises when there are any")
        XCTAssertFalse(next.contains("back-squat"), "no barbell, no back squat")
    }

    func testRecycleKeepsTheSpotAndNeverUsesMissingEquipment() throws {
        let plan = input()
        let session = try XCTUnwrap(PlanGenerator.generate(plan).sessions.first)
        let original = try XCTUnwrap(session.items.first)
        var seen: Set<String> = []
        for turn in 1...6 {
            let swapped = try XCTUnwrap(PlanGenerator.replacement(for: original, in: session, input: plan, turn: turn))
            XCTAssertEqual(swapped.quality, original.quality, "same purpose in the workout")
            XCTAssertEqual(swapped.order, original.order, "same spot")
            XCTAssertNotEqual(swapped.itemSlug, original.itemSlug)
            XCTAssertNotEqual(swapped.itemSlug, "back-squat", "only the athlete's equipment")
            XCTAssertLessThanOrEqual(swapped.dose.sets, 3, "youth envelope")
            seen.insert(swapped.itemSlug)
        }
        XCTAssertGreaterThan(seen.count, 1, "tapping again gives another choice")
    }

    func testTheBestFitForTheSportComesFirst() {
        var sprintSquat = item("jump-squat-drill", "lower-body-strength")
        sprintSquat = CatalogueItem(
            slug: "sprint-lunge", name: "sprint-lunge", kind: "exercise", qualities: ["lower-body-strength": 1.0, "acceleration": 0.9], muscles: [:],
            equipment: [], surface: "anywhere", minAge: 13, supervisionLevel: "SELF",
            setup: [], execution: [], cues: [], mistakes: [], progressions: [], regressions: [], substitutes: [],
            defaultDose: sprintSquat.defaultDose, restSeconds: 60, startPose: "hinge", endPose: "hinge",
            unilateralEligible: nil, tempoEligible: nil, prop: nil, variant: nil, baseSlug: nil,
            constraintAxes: nil, equipmentChain: nil, unilateralPosePattern: nil, unilateralStabilityQuality: nil,
            itemSportSlug: nil
        )
        let plain = item("a-plain-squat", "lower-body-strength")
        let catalogue = Catalogue(itemsBySlug: [plain.slug: plain, sprintSquat.slug: sprintSquat])
        let plan = PlanGeneratorInput(
            sportProfile: ["lower-body-strength": 1, "acceleration": 1], seasonStart: day(1), seasonEnd: day(1),
            weekStart: day(1), birthDate: day(1).addingTimeInterval(-16 * 365 * 86_400), catalogue: catalogue, seed: "x", now: day(1)
        )
        let ranked = PlanGenerator.rankedForSport([plain, sprintSquat], input: plan)
        XCTAssertEqual(ranked.first?.slug, "sprint-lunge", "it also trains the acceleration the sport needs")
    }
}
