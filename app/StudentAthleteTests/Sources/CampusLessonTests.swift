import XCTest

/// Every Campus lesson reads the same way: a hook, the explanation, an
/// athlete's example, then what it means for you, then the quiz.
final class CampusLessonTests: XCTestCase {
    func testEveryLessonHasHookExplanationExampleAndMeaning() {
        let lessons = campusTopics.flatMap(\.lessons)
        XCTAssertEqual(lessons.count, 30)
        for lesson in lessons {
            let teach = lesson.steps.compactMap { step -> CampusSection? in
                if case .teach(let section) = step { return section } else { return nil }
            }
            XCTAssertGreaterThanOrEqual(teach.count, 4, lesson.id)
            XCTAssertEqual(teach.first?.heading, campusHooks[lesson.id]?.0, "\(lesson.id) opens with its hook")
            XCTAssertEqual(teach.dropLast().last?.heading, CampusLesson.exampleHeading, "\(lesson.id) has an example before the meaning")
            XCTAssertEqual(teach.last?.heading, CampusLesson.meansForYouHeading, lesson.id)
        }
    }
}

/// The lesson that fits the day.
final class LessonPickerTests: XCTestCase {
    func testTheDayPicksTheLesson() {
        XCTAssertEqual(LessonPicker.forToday(.init(sleepHours: 5.5))?.id, "sleep-power")
        XCTAssertEqual(LessonPicker.forToday(.init(daysToGame: 1))?.id, "pressure")
        XCTAssertEqual(LessonPicker.forToday(.init(sleepHours: 5.5, pain: true))?.id, "pain", "pain comes first")
        XCTAssertEqual(LessonPicker.forToday(.init(examWeek: true))?.id, "balance")
        XCTAssertNil(LessonPicker.forToday(.init(sleepHours: 8, soreness: 2, energy: 4, daysToGame: 5)), "an ordinary day follows the path")
        for id in ["pain", "sleep-power", "pressure", "rest-days", "overtraining", "balance"] {
            XCTAssertNotNil(LessonPicker.lesson(id), "\(id) exists")
        }
    }
}
