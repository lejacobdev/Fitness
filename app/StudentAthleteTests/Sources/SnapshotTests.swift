import SwiftUI
import UIKit
import XCTest

/// Key cards rendered in CI at phone width, in light and dark and at a large
/// text size. Each picture is attached to the test result (download it
/// from the run), and a card that collapses or overflows fails here.
@MainActor
final class SnapshotTests: XCTestCase {
    private let width: CGFloat = 393

    private func render<V: View>(_ name: String, _ view: V, height: CGFloat? = nil,
                                 scheme: ColorScheme = .light, size: DynamicTypeSize = .large) -> UIImage? {
        let content = view
            .frame(width: width)
            .frame(height: height)
            .padding(.vertical, 1)
            .background(AppTheme.background)
            .environment(\.colorScheme, scheme)
            .environment(\.dynamicTypeSize, size)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.uiImage else { return nil }
        let attachment = XCTAttachment(image: image)
        attachment.name = "\(name)-\(scheme == .dark ? "dark" : "light")-\(size == .large ? "L" : "XXL")"
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    private var review: WeeklyReview {
        WeeklyReview(workouts: 3, minutes: 125, checkIns: 6, lessons: 2,
                     highlight: "A new personal best: Vertical jump 48 cm.", focus: "A game next week: sleep well and arrive fresh.")
    }

    func testWeeklyReviewCardFitsAtEveryTextSize() throws {
        for scheme in [ColorScheme.light, .dark] {
            for size in [DynamicTypeSize.large, .accessibility2] {
                let image = try XCTUnwrap(render("weekly-review", WeeklyReviewCard(review: review).padding(20), scheme: scheme, size: size))
                XCTAssertEqual(image.size.width, width, accuracy: 1, "no horizontal overflow")
                XCTAssertGreaterThan(image.size.height, 150, "the card didn't collapse")
            }
        }
    }

    func testSeasonCardAndReportPageRender() throws {
        let report = AthleteReport(name: "Sam", sport: "Soccer", position: "Midfielder", age: 16, from: .now.addingTimeInterval(-90 * 86_400),
                                   to: .now, workouts: 34, minutes: 1_210, practices: 40, checkIns: 80, averageSleep: 8.1, lessons: 12,
                                   longestStreak: 19, tests: [.init(name: "Vertical jump", best: "48 cm", change: "4 cm higher")],
                                   topExercise: "Split squat")
        let card = try XCTUnwrap(render("season-card", SeasonCard(report: report), height: 640))
        XCTAssertEqual(card.size.height, 642, accuracy: 2)
        let page = try XCTUnwrap(render("report-page", ReportPage(report: report).frame(height: 842), height: 842))
        XCTAssertGreaterThan(page.size.height, 800)
    }
}
