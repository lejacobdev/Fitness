import XCTest

/// On a phone (build 78) tapping a lesson opened the Me tab instead of the
/// lesson. This taps the real buttons in the real app and checks the lesson
/// player comes up.
final class LessonOpeningUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(tab: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-tab", tab]
        app.launch()
        return app
    }

    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTheRecommendedLessonOpensTheLessonPlayer() {
        let app = launch(tab: "campus")
        let start = app.buttons.matching(NSPredicate(format: "label IN %@", ["Start", "Continue"])).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 20), "Campus shows a lesson to start")
        screenshot(app, "campus")
        start.tap()
        let quit = app.buttons["Quit lesson"]
        let opened = quit.waitForExistence(timeout: 10)
        screenshot(app, "after-tap")
        XCTAssertTrue(opened, "the lesson player opened")
        XCTAssertFalse(app.staticTexts["Training Setup"].exists, "not the Me tab")
    }

    func testALessonFromALearningAreaOpensTheLessonPlayer() {
        let app = launch(tab: "campus")
        let area = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Training & exercise science")).firstMatch
        XCTAssertTrue(area.waitForExistence(timeout: 20))
        area.tap()
        let lesson = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "How training makes you better")).firstMatch
        XCTAssertTrue(lesson.waitForExistence(timeout: 10), "the area lists its lessons")
        lesson.tap()
        let opened = app.buttons["Quit lesson"].waitForExistence(timeout: 10)
        screenshot(app, "area-lesson")
        XCTAssertTrue(opened, "the lesson player opened")
    }
}
