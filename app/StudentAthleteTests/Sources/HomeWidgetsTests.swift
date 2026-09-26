import XCTest

/// Edit Home: extra widgets under the day — none by default, added,
/// removed and reordered by the athlete, and kept.
final class HomeWidgetsTests: XCTestCase {
    private let suite = "HomeWidgetsTests"

    private func defaults() throws -> UserDefaults {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testNoWidgetsUntilTheAthleteAddsThem() throws {
        let defaults = try defaults()
        // A layout saved by the widget board before V3 doesn't bring them back.
        defaults.set(Data("{\"order\":[\"body\"],\"hidden\":[]}".utf8), forKey: "home.layout")
        let layout = HomeLayout.load(defaults)
        XCTAssertTrue(layout.widgets.isEmpty)
        XCTAssertEqual(layout.available, HomeWidget.allCases)
    }

    func testAddRemoveAndKeep() throws {
        let defaults = try defaults()
        var layout = HomeLayout.load(defaults)
        layout.add(.streak)
        layout.add(.nextGame)
        layout.add(.streak)
        XCTAssertEqual(layout.widgets, [.streak, .nextGame], "each widget once, in the order added")
        XCTAssertFalse(layout.available.contains(.streak))
        layout.save(defaults)
        XCTAssertEqual(HomeLayout.load(defaults).widgets, [.streak, .nextGame])
        layout.remove(.streak)
        XCTAssertEqual(layout.widgets, [.nextGame])
        XCTAssertTrue(layout.available.contains(.streak))
    }

    func testMovingAWidget() {
        var layout = HomeLayout(widgets: [.body, .sport, .knowledge, .mindset])
        layout.move(.body, to: .knowledge)
        XCTAssertEqual(layout.widgets, [.sport, .knowledge, .body, .mindset])
        layout.move(.mindset, to: .sport)
        XCTAssertEqual(layout.widgets, [.mindset, .sport, .knowledge, .body])
        layout.move(.food, to: .sport)
        XCTAssertEqual(layout.widgets, [.mindset, .sport, .knowledge, .body], "a widget that isn't there doesn't move")
    }

    func testRepeatedEntriesAreDroppedWhenLoading() throws {
        let defaults = try defaults()
        HomeLayout(widgets: [.tests, .tests, .food]).save(defaults)
        XCTAssertEqual(HomeLayout.load(defaults).widgets, [.tests, .food])
    }
}
