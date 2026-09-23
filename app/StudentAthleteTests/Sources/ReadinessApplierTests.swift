import XCTest

final class ReadinessApplierTests: XCTestCase {
    private func item(
        slug: String, quality: String, order: Int = 0, sets: Int = 5, contacts: Int? = nil, restSec: Int = 60
    ) -> GeneratedPlannedItem {
        let dose = contacts != nil
            ? Dose(kind: plyometricDoseKind, sets: sets, contacts: contacts)
            : Dose(kind: "reps", sets: sets, reps: 8)
        return GeneratedPlannedItem(itemSlug: slug, order: order, dose: dose, restSec: restSec, rationale: "r", quality: quality)
    }

    private func session(items: [GeneratedPlannedItem]) -> GeneratedSession {
        GeneratedSession(
            date: .now, title: "Original title", focusQualities: items.map(\.quality),
            estimatedMinutes: items.reduce(0) { $0 + PlanGenerator.estimatedMinutes(dose: $1.dose, restSec: $1.restSec) },
            items: items
        )
    }

    func testGreenLeavesTheSessionCompletelyUnchanged() {
        let original = session(items: [item(slug: "a", quality: "acceleration")])
        let result = ReadinessApplier.apply(to: original, band: .green)
        XCTAssertEqual(result.session, original)
        XCTAssertNil(result.reason, "green is 'the plan as generated' — nothing to explain")
    }

    func testAmberTrimsSetsByRoughlyTwentyPercentAndHoldsReps() {
        let original = session(items: [item(slug: "a", quality: "lower-body-strength", sets: 5)])
        let result = ReadinessApplier.apply(to: original, band: .amber)
        let trimmed = result.session.items.first
        XCTAssertEqual(trimmed?.dose.sets, 4, "5 sets trimmed ~20% rounds to 4")
        XCTAssertEqual(trimmed?.dose.reps, 8, "intensity (reps) is held per §11")
        XCTAssertNotNil(result.reason)
    }

    func testAmberCutsPlyometricContactsInsteadOfSets() {
        let original = session(items: [item(slug: "bounds", quality: "vertical-power", sets: 3, contacts: 10)])
        let result = ReadinessApplier.apply(to: original, band: .amber)
        let trimmed = result.session.items.first
        XCTAssertEqual(trimmed?.dose.contacts, 8, "10 contacts trimmed ~20% rounds to 8")
        XCTAssertEqual(trimmed?.dose.sets, 3, "sets untouched for a plyometric dose — contacts is the volume knob")
    }

    func testRedPrefersControlGroupMobilityItemsAndExplainsWhy() {
        let original = session(items: [
            item(slug: "strength-item", quality: "lower-body-strength", order: 0, sets: 4),
            item(slug: "mobility-item", quality: "hip-mobility", order: 1, sets: 4),
        ])
        let result = ReadinessApplier.apply(to: original, band: .red)
        XCTAssertEqual(result.session.items.map(\.itemSlug), ["mobility-item"])
        XCTAssertEqual(result.session.items.first?.dose.sets, 2, "halved on top of being preferred")
        XCTAssertEqual(result.session.title, "Movement and mobility — an easy day")
        XCTAssertNotNil(result.reason)
        // §11's lint rule: no injury/risk/damage/safe/unsafe language anywhere.
        let banned = ["injury", "risk", "damage", "unsafe"]
        for word in banned {
            XCTAssertFalse(result.reason?.lowercased().contains(word) ?? true, "reason must not contain '\(word)'")
        }
    }

    func testRedFallsBackToTheOriginalItemsWhenNoControlGroupItemExists() {
        let original = session(items: [item(slug: "strength-only", quality: "lower-body-strength", sets: 4)])
        let result = ReadinessApplier.apply(to: original, band: .red)
        XCTAssertEqual(result.session.items.map(\.itemSlug), ["strength-only"], "never an empty session")
        XCTAssertEqual(result.session.items.first?.dose.sets, 2)
    }
}
