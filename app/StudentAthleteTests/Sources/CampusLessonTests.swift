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
