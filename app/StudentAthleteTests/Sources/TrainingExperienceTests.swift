import XCTest

/// Training experience changes the plan: fewer sets, moderate reps, fewer
/// jumps and no explosive variants for new lifters; an extra set for
/// experienced ones, never outside the youth envelope.
final class TrainingExperienceTests: XCTestCase {
    private func item(_ slug: String, _ quality: String, dose: Dose, variant: ItemVariant? = nil, supervision: String = "SELF") -> CatalogueItem {
        CatalogueItem(
            slug: slug, name: slug, kind: "exercise", qualities: [quality: 1.0], muscles: [:],
            equipment: [], surface: "anywhere", minAge: 13, supervisionLevel: supervision,
            setup: [], execution: [], cues: [], mistakes: [], progressions: [], regressions: [], substitutes: [],
            defaultDose: dose, restSeconds: 60, startPose: "hinge", endPose: "hinge",
            unilateralEligible: nil, tempoEligible: nil, prop: nil, variant: variant, baseSlug: nil,
            constraintAxes: nil, equipmentChain: nil, unilateralPosePattern: nil, unilateralStabilityQuality: nil,
            itemSportSlug: nil
        )
    }

    func testDosesFollowExperience() {
        let dose = Dose(kind: "reps", sets: 3, reps: 15)
        let beginner = TrainingExperience.beginner.adjusted(dose, isYouthEnvelope: true)
        XCTAssertEqual(beginner.sets, 2)
        XCTAssertEqual(beginner.reps, 12)
        XCTAssertEqual(TrainingExperience.intermediate.adjusted(dose, isYouthEnvelope: true), dose)
        XCTAssertEqual(TrainingExperience.experienced.adjusted(Dose(kind: "reps", sets: 2, reps: 8), isYouthEnvelope: true).sets, 3)
        XCTAssertEqual(TrainingExperience.experienced.adjusted(dose, isYouthEnvelope: true).sets, 3, "never past the youth envelope")
        XCTAssertEqual(TrainingExperience.experienced.adjusted(dose, isYouthEnvelope: false).sets, 4)
        let jumps = TrainingExperience.beginner.adjusted(Dose(kind: plyometricDoseKind, sets: 3, contacts: 12), isYouthEnvelope: true)
        XCTAssertEqual(jumps.contacts, 8)
    }

    func testNewLiftersSkipExplosiveOneLegAndCoachedVersions() {
        let base = item("squat-jump", "vertical-power", dose: Dose(kind: "reps", sets: 3, reps: 5))
        let explosive = item("squat-jump-explosive", "vertical-power", dose: base.defaultDose, variant: ItemVariant(axis: "tempo", tier: nil, tempo: "explosive", values: nil))
        let slow = item("squat-jump-eccentric", "vertical-power", dose: base.defaultDose, variant: ItemVariant(axis: "tempo", tier: nil, tempo: "eccentric", values: nil))
        let oneLeg = item("squat-jump-unilateral", "vertical-power", dose: base.defaultDose, variant: ItemVariant(axis: "unilateral", tier: nil, tempo: nil, values: nil))
        let coached = item("power-clean", "vertical-power", dose: base.defaultDose, supervision: "COACHED")
        XCTAssertTrue(TrainingExperience.beginner.allows(base))
        XCTAssertTrue(TrainingExperience.beginner.allows(slow))
        XCTAssertFalse(TrainingExperience.beginner.allows(explosive))
        XCTAssertFalse(TrainingExperience.beginner.allows(oneLeg))
        XCTAssertFalse(TrainingExperience.beginner.allows(coached))
        XCTAssertTrue([explosive, oneLeg, coached].allSatisfy(TrainingExperience.experienced.allows))
    }

    func testTheWeeklyPlanUsesExperience() {
        let items = [
            item("split-squat", "lower-body-strength", dose: Dose(kind: "reps", sets: 3, reps: 6)),
            item("split-squat-unilateral", "lower-body-strength", dose: Dose(kind: "reps", sets: 3, reps: 6),
                 variant: ItemVariant(axis: "unilateral", tier: nil, tempo: nil, values: nil)),
        ]
        let catalogue = Catalogue(itemsBySlug: Dictionary(uniqueKeysWithValues: items.map { ($0.slug, $0) }))
        let calendar = Calendar(identifier: .gregorian)
        let day = { (d: Int) in calendar.date(from: DateComponents(year: 2026, month: 6, day: d))! }
        func week(_ experience: TrainingExperience, seed: String) -> GeneratedWeek {
            PlanGenerator.generate(PlanGeneratorInput(
                sportProfile: ["lower-body-strength": 1], seasonStart: calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!,
                seasonEnd: calendar.date(from: DateComponents(year: 2026, month: 11, day: 30))!, weekStart: day(1),
                birthDate: calendar.date(from: DateComponents(year: 2010, month: 1, day: 1))!,
                catalogue: catalogue, seed: seed, now: day(1), experience: experience
            ))
        }
        for seed in ["a", "b", "c", "d"] {
            let beginner = week(.beginner, seed: seed).sessions.flatMap(\.items)
            XCTAssertFalse(beginner.isEmpty)
            XCTAssertTrue(beginner.allSatisfy { $0.itemSlug == "split-squat" && $0.dose.sets == 2 && $0.dose.reps == 8 })
        }
    }
}
