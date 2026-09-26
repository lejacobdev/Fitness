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

    func testDraggingThroughTheBoardShowsTheOrderLive() {
        // Holding the quote and passing over the next widgets moves it one
        // step at a time — each step is what the board shows while holding.
        var layout = HomeLayout(order: [.quote, .checkIn, .today, .body], hidden: [])
        layout.move(.quote, to: .checkIn)
        XCTAssertEqual(layout.order, [.checkIn, .quote, .today, .body])
        layout.move(.quote, to: .today)
        XCTAssertEqual(layout.order, [.checkIn, .today, .quote, .body])
        layout.move(.quote, to: .checkIn)
        XCTAssertEqual(layout.order, [.quote, .checkIn, .today, .body], "dragging back undoes it")
    }

    func testRowPositionsMatchTheRows() {
        XCTAssertEqual(HomeLayout.rowIndices(small: [false, true, true, false, true, false]), [[0], [1, 2], [3], [4], [5]])
        XCTAssertEqual(HomeLayout.rowIndices(small: [true, true, true]), [[0, 1], [2]])
        XCTAssertEqual(HomeLayout.rowIndices(small: []), [])
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
