import XCTest

@MainActor
final class PushRouteTests: XCTestCase {
    override func tearDown() {
        PushRoute.shared.tab = nil
        PushRoute.shared.meSheet = nil
        super.tearDown()
    }

    func testReturnToPlayOpensTeamSheet() {
        PushRoute.shared.open(kind: "rtp")
        XCTAssertEqual(PushRoute.shared.tab, AppTab.me)
        XCTAssertEqual(PushRoute.shared.meSheet, "team")
    }

    func testHealthNoteOpensCoachSheet() {
        PushRoute.shared.open(kind: "health")
        XCTAssertEqual(PushRoute.shared.tab, AppTab.me)
        XCTAssertEqual(PushRoute.shared.meSheet, "coach")
    }

    func testAssignmentOpensToday() {
        PushRoute.shared.open(kind: "assignment")
        XCTAssertEqual(PushRoute.shared.tab, AppTab.today)
        XCTAssertNil(PushRoute.shared.meSheet)
    }

    func testUnknownKindDoesNothing() {
        PushRoute.shared.open(kind: "nonsense")
        XCTAssertNil(PushRoute.shared.tab)
    }

    func testPokeMovesTick() {
        let before = LiveUpdates.shared.tick
        LiveUpdates.shared.poke()
        XCTAssertNotEqual(LiveUpdates.shared.tick, before)
    }
}
