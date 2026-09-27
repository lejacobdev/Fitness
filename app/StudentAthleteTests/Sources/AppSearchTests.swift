import XCTest

/// Home's search: it finds the app's functions by the words athletes use,
/// and never shows another sport's drills to a free athlete.
final class AppSearchTests: XCTestCase {
    private func item(_ slug: String, sport: String?, positions: [String]? = nil) -> CatalogueItem {
        var item = CatalogueItem(
            slug: slug, name: slug, kind: "exercise", qualities: ["lower-body-strength": 1], muscles: [:],
            equipment: [], surface: "anywhere", minAge: 13, supervisionLevel: "SELF",
            setup: [], execution: [], cues: [], mistakes: [], progressions: [], regressions: [], substitutes: [],
            defaultDose: Dose(kind: "reps", sets: 3, reps: 8), restSeconds: 60, startPose: "hinge", endPose: "hinge",
            unilateralEligible: nil, tempoEligible: nil, prop: nil, variant: nil, baseSlug: nil,
            constraintAxes: nil, equipmentChain: nil, unilateralPosePattern: nil, unilateralStabilityQuality: nil,
            itemSportSlug: sport
        )
        item.positions = positions
        return item
    }

    private let soccer = SportVisibility.Sport(slug: "soccer", position: "midfielder", format: nil)
    private let tennis = SportVisibility.Sport(slug: "tennis", position: nil, format: nil)

    func testFreeSeesOnlyTheActiveSportsDrills() {
        let sports = SportVisibility.sports(active: soccer, all: [soccer, tennis], isPro: false)
        XCTAssertEqual(sports, [soccer])
        XCTAssertTrue(SportVisibility.isVisible(item("squat", sport: nil), sports: sports), "general exercises always")
        XCTAssertTrue(SportVisibility.isVisible(item("rondo", sport: "soccer"), sports: sports))
        XCTAssertFalse(SportVisibility.isVisible(item("serve", sport: "tennis"), sports: sports), "not until they switch to tennis")
        XCTAssertFalse(SportVisibility.isVisible(item("keeper-dive", sport: "soccer", positions: ["goalkeeper"]), sports: sports),
                       "another position's drill")
    }

    func testProSeesEverySportTheyPlayButNoOthers() {
        let sports = SportVisibility.sports(active: soccer, all: [soccer, tennis], isPro: true)
        XCTAssertTrue(SportVisibility.isVisible(item("serve", sport: "tennis"), sports: sports))
        XCTAssertFalse(SportVisibility.isVisible(item("puck-handling", sport: "ice-hockey"), sports: sports))
    }

    func testFunctionsAreFoundByTheirEverydayWords() {
        func first(_ query: String) -> AppSearchTarget? { AppSearch.rank(AppSearch.functions, query: query).first?.target }
        XCTAssertEqual(first("check in"), .checkIn)
        XCTAssertEqual(first("water"), .fuel)
        XCTAssertEqual(first("concussion"), .safety)
        XCTAssertEqual(first("equipment"), .equipment)
        XCTAssertEqual(first("remindrs"), .reminders, "a typo still finds it")
        XCTAssertEqual(first("skill plan"), .skillPlans)
        XCTAssertEqual(first("muscle workout"), .muscleWorkouts)
        XCTAssertEqual(first("teamsnap"), .calendars)
        XCTAssertEqual(first("widgets"), .editHome)
        XCTAssertTrue(AppSearch.rank(AppSearch.functions, query: "zzqx").isEmpty)
    }

    func testEveryFunctionHasAUniqueName() {
        let ids = AppSearch.functions.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
