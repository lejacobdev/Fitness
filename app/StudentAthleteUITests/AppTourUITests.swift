import XCTest

/// Walks the real app: every button on every tab, and every button on the
/// screen it opens, with a screenshot of each. Slow, so it only runs from the
/// tour workflow (`TEST_RUNNER_AOS_TOUR=1`); the normal check skips it.
/// The report attachment lists every button, what it did, and any that are
/// unlabeled or do nothing.
final class AppTourUITests: XCTestCase {
    private var report: [String] = []
    private var shots = 0

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["AOS_TOUR"] != nil, "tour only runs from the tour workflow")
        continueAfterFailure = true
    }

    func testTourToday() { tour("today") }
    func testTourCampus() { tour("campus") }
    func testTourWorkout() { tour("workout") }
    func testTourProgress() { tour("progress") }
    func testTourMe() { tour("me") }

    // MARK: Tour

    private let skip = try! NSRegularExpression(
        pattern: "delete|sign out|log out|logout|erase|reset|remove|clear|disconnect|unlink|leave|purchase|subscribe|buy|restore|redeem|report|block",
        options: .caseInsensitive
    )
    private let chrome: Set<String> = ["Back", "Close", "Done", "Cancel", "Dismiss", "Hide keyboard", "Return", "Keyboard"]

    private func tour(_ tab: String) {
        let started = Date()
        let root = launch(tab)
        shot(root, "\(tab)/00-root")
        let tabBar = Set(root.tabBars.buttons.allElementsBoundByIndex.map { $0.label })
        let rootLabels = collectLabels(root, exclude: tabBar)
        report.append("== \(tab): \(rootLabels.count) buttons on the tab")
        for l in rootLabels { report.append("   • \(l)") }

        var leaves = 0
        for (index, label) in rootLabels.enumerated() {
            if Date().timeIntervalSince(started) > 3000 { report.append("!! time budget reached after \(index) buttons"); break }
            guard allowed(label) else { report.append("-- skipped (destructive/purchase): \(label)"); continue }
            let app = launch(tab)
            let before = signature(app)
            guard let button = reveal(label, in: app) else { report.append("?? could not reach: \(label)"); continue }
            button.tap()
            pause(1.5)
            let after = signature(app)
            let name = "\(tab)/\(String(format: "%02d", index + 1))-\(safe(label))"
            shot(app, name)
            if before == after { report.append("NO CHANGE after tapping \"\(label)\" (\(tab))"); continue }

            let children = collectLabels(app, exclude: tabBar.union(rootLabels).union(chrome)).prefix(12)
            report.append("→ \"\(label)\": \(children.count) buttons on the next screen")
            for child in children { report.append("      ◦ \(child)") }
            for (ci, child) in children.enumerated() where allowed(child) {
                if leaves >= 160 { break }
                leaves += 1
                let a2 = launch(tab)
                guard let b1 = reveal(label, in: a2) else { continue }
                b1.tap()
                pause(1.5)
                let mid = signature(a2)
                guard let b2 = reveal(child, in: a2) else { report.append("?? could not reach: \(label) › \(child)"); continue }
                b2.tap()
                pause(1.5)
                shot(a2, "\(name)/\(String(format: "%02d", ci + 1))-\(safe(child))")
                if signature(a2) == mid { report.append("NO CHANGE after tapping \"\(label)\" › \"\(child)\" (\(tab))") }
            }
        }
        let text = XCTAttachment(string: report.joined(separator: "\n"))
        text.name = "report-\(tab)"
        text.lifetime = .keepAlways
        add(text)
    }

    // MARK: Helpers

    private func launch(_ tab: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-tab", tab]
        app.launch()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 25)
        pause(2.0)
        return app
    }

    private func pause(_ seconds: TimeInterval) {
        let e = expectation(description: "pause")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { e.fulfill() }
        wait(for: [e], timeout: seconds + 5)
    }

    private func allowed(_ label: String) -> Bool {
        let range = NSRange(label.startIndex..., in: label)
        return skip.firstMatch(in: label, options: [], range: range) == nil
    }

    private func safe(_ label: String) -> String {
        String(label.map { $0.isLetter || $0.isNumber ? $0 : "-" }.prefix(40))
    }

    private func signature(_ app: XCUIApplication) -> Int {
        app.debugDescription.hashValue
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        shots += 1
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func visibleButtonLabels(_ app: XCUIApplication) -> [String] {
        var out: [String] = []
        for b in app.buttons.allElementsBoundByIndex {
            guard b.exists, b.isHittable else { continue }
            let l = b.label
            if l.isEmpty {
                report.append("UNLABELED button at \(b.frame.integral)")
                continue
            }
            if l.contains(".") && !l.contains(" ") && l.lowercased() == l {
                report.append("RAW SYMBOL label \"\(l)\"")
            }
            out.append(l)
        }
        return out
    }

    private func collectLabels(_ app: XCUIApplication, exclude: Set<String>) -> [String] {
        var all: [String] = []
        var stagnant = 0
        for _ in 0..<12 {
            let before = all.count
            for l in visibleButtonLabels(app) where !all.contains(l) && !exclude.contains(l) { all.append(l) }
            stagnant = all.count == before ? stagnant + 1 : 0
            if stagnant >= 2 { break }
            app.swipeUp()
            pause(0.4)
        }
        return all
    }

    private func reveal(_ label: String, in app: XCUIApplication) -> XCUIElement? {
        let el = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        for _ in 0..<14 {
            if el.exists && el.isHittable { return el }
            app.swipeUp()
            pause(0.3)
        }
        return el.exists && el.isHittable ? el : nil
    }
}
