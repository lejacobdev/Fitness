import XCTest

/// Home as a board of widgets the athlete arranges.
final class HomeWidgetsTests: XCTestCase {
    func testSmallWidgetsPairUpAndEverythingElseIsFullWidth() {
        let rows = HomeLayout.rows([.quote, .body, .sport, .today, .knowledge, .checkIn])
        XCTAssertEqual(rows, [[.quote], [.body, .sport], [.today], [.knowledge], [.checkIn]])
    }

    func testMovingAWidgetPutsItWhereItWasDropped() {
        var layout = HomeLayout(order: [.quote, .checkIn, .today], hidden: [])
        layout.move(.quote, to: .today)
        XCTAssertEqual(layout.order, [.checkIn, .today, .quote])
        layout.move(.quote, to: .checkIn)
        XCTAssertEqual(layout.order, [.quote, .checkIn, .today])
    }

    func testTheArrowsSwapNeighbours() {
        var layout = HomeLayout(order: [.quote, .checkIn, .today], hidden: [])
        layout.swap(.today, with: .checkIn)
        XCTAssertEqual(layout.order, [.quote, .today, .checkIn])
    }

    func testAnOldLayoutGetsNewWidgetsAndHiddenOnesStayHidden() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "HomeWidgetsTests"))
        defaults.removePersistentDomain(forName: "HomeWidgetsTests")
        HomeLayout(order: [.today, .quote], hidden: [.quote]).save(defaults)
        let loaded = HomeLayout.load(defaults)
        XCTAssertEqual(Set(loaded.order), Set(HomeWidget.allCases), "every widget is somewhere")
        XCTAssertFalse(loaded.visible.contains(.quote))
        defaults.removePersistentDomain(forName: "HomeWidgetsTests")
    }
}
