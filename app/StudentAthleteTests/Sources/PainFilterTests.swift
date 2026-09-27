import XCTest

/// Pain in an area takes everything that loads it out of today's workout.
final class PainFilterTests: XCTestCase {
    private func item(_ slug: String, muscles: [String: Double], quality: String = "lower-body-strength",
                      dose: Dose = Dose(kind: "reps", sets: 3, reps: 8)) -> CatalogueItem {
        CatalogueItem(
            slug: slug, name: slug, kind: "exercise", qualities: [quality: 1.0], muscles: muscles,
            equipment: [], surface: "anywhere", minAge: 13, supervisionLevel: "SELF",
            setup: [], execution: [], cues: [], mistakes: [], progressions: [], regressions: [], substitutes: [],
            defaultDose: dose, restSeconds: 60, startPose: "hinge", endPose: "hinge",
            unilateralEligible: nil, tempoEligible: nil, prop: nil, variant: nil, baseSlug: nil,
            constraintAxes: nil, equipmentChain: nil, unilateralPosePattern: nil, unilateralStabilityQuality: nil,
            itemSportSlug: nil
        )
    }

    private func planned(_ slug: String, _ order: Int, quality: String = "lower-body-strength") -> GeneratedPlannedItem {
        GeneratedPlannedItem(itemSlug: slug, order: order, dose: Dose(kind: "reps", sets: 3, reps: 8), restSec: 60, rationale: "", quality: quality)
    }

    func testLegPainTakesOutLegWorkAndJumpsButKeepsTheRest() {
        let squat = item("squat", muscles: ["vastus-lateralis": 0.8, "gluteus-maximus": 0.6])
        let hop = item("pogo", muscles: [:], quality: "reactive-strength", dose: Dose(kind: plyometricDoseKind, sets: 2, contacts: 10))
        let press = item("push-up", muscles: ["pectoralis-major": 0.8, "triceps-brachii": 0.5], quality: "upper-body-push")
        let plank = item("side-plank", muscles: ["obliques-external": 0.8], quality: "trunk-anti-rotation")
        XCTAssertTrue(PainFilter.loads(squat, areas: [.leg]))
        XCTAssertTrue(PainFilter.loads(hop, areas: [.knee]), "no jumping on a sore knee")
        XCTAssertFalse(PainFilter.loads(press, areas: [.leg]))
        XCTAssertTrue(PainFilter.loads(press, areas: [.shoulder]))
        XCTAssertFalse(PainFilter.loads(squat, areas: []))

        let catalogue = Catalogue(itemsBySlug: Dictionary(uniqueKeysWithValues: [squat, hop, press, plank].map { ($0.slug, $0) }))
        let session = GeneratedSession(date: .now, title: "Strength", focusQualities: [], estimatedMinutes: 30,
                                       items: [planned("pogo", 0, quality: "reactive-strength"), planned("squat", 1),
                                               planned("push-up", 2, quality: "upper-body-push"), planned("side-plank", 3, quality: "trunk-anti-rotation")],
                                       slot: 0)
        let safe = PainFilter.apply(to: session, areas: [.leg], catalogue: catalogue) { _, _ in nil }
        XCTAssertEqual(safe.items.map(\.itemSlug), ["push-up", "side-plank"])
        XCTAssertEqual(safe.items.map(\.order), [0, 1])
        XCTAssertEqual(safe.slot, 0)
    }

    func testASwapOnlyCountsWhenItLeavesTheAreaAlone() {
        let squat = item("squat", muscles: ["vastus-lateralis": 0.8])
        let lunge = item("lunge", muscles: ["vastus-medialis": 0.7])
        let bridge = item("hip-thrust", muscles: ["gluteus-maximus": 0.9])
        let catalogue = Catalogue(itemsBySlug: Dictionary(uniqueKeysWithValues: [squat, lunge, bridge].map { ($0.slug, $0) }))
        let session = GeneratedSession(date: .now, title: "S", focusQualities: [], estimatedMinutes: 10, items: [planned("squat", 0)])
        let badSwap = PainFilter.apply(to: session, areas: [.knee], catalogue: catalogue) { item, _ in
            GeneratedPlannedItem(itemSlug: "lunge", order: item.order, dose: item.dose, restSec: 60, rationale: "", quality: item.quality)
        }
        XCTAssertTrue(badSwap.items.isEmpty, "a lunge loads the knee too")
        let goodSwap = PainFilter.apply(to: session, areas: [.knee], catalogue: catalogue) { item, _ in
            GeneratedPlannedItem(itemSlug: "hip-thrust", order: item.order, dose: item.dose, restSec: 60, rationale: "", quality: item.quality)
        }
        XCTAssertEqual(goodSwap.items.map(\.itemSlug), ["hip-thrust"])
    }

    func testThePlanGeneratorLeavesSoreAreasOutToo() {
        let squat = item("squat", muscles: ["vastus-lateralis": 0.8])
        let bridge = item("hip-thrust", muscles: ["gluteus-maximus": 0.9])
        let catalogue = Catalogue(itemsBySlug: [squat.slug: squat, bridge.slug: bridge])
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        let input = PlanGeneratorInput(sportProfile: ["lower-body-strength": 1], seasonStart: day.addingTimeInterval(200 * 86_400),
                                       seasonEnd: day.addingTimeInterval(300 * 86_400), weekStart: day,
                                       birthDate: day.addingTimeInterval(-16 * 365 * 86_400), catalogue: catalogue, seed: "p", now: day,
                                       painAreas: [.knee])
        let slugs = Set(PlanGenerator.generate(input).sessions.flatMap { $0.items.map(\.itemSlug) })
        XCTAssertEqual(slugs, ["hip-thrust"])
    }
}
