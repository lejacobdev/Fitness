import XCTest

/// Home's search: open it from the top bar, find a function by an everyday
/// word, and land on it.
final class HomeSearchUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSearchFindsAndOpensAFunction() {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-tab", "today"]
        app.launch()

        let search = app.buttons["Search"]
        XCTAssertTrue(search.waitForExistence(timeout: 20), "the search button is in Home's top bar")
        search.tap()

        let field = app.textFields["Search AthleteOS"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("concussion")

        let result = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Safety Center")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10), "a synonym finds the Safety Center")
        let found = XCTAttachment(screenshot: app.screenshot())
        found.name = "search-results"
        found.lifetime = .keepAlways
        add(found)
        result.tap()

        let opened = app.staticTexts["When something doesn't feel right."].waitForExistence(timeout: 10)
        let landed = XCTAttachment(screenshot: app.screenshot())
        landed.name = "after-tap"
        landed.lifetime = .keepAlways
        add(landed)
        XCTAssertTrue(opened, "the Safety Center opened")
    }
}
